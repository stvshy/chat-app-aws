package pl.projektchmury.notificationservice.repository;

import org.slf4j.Logger; // Do logowania
import org.slf4j.LoggerFactory; // Do tworzenia loggera
import org.springframework.beans.factory.annotation.Autowired; // Do wstrzykiwania zależności przez Springa
import org.springframework.beans.factory.annotation.Value; // Do wstrzykiwania wartości z konfiguracji
import org.springframework.stereotype.Repository; // Oznacza, że ta klasa jest komponentem repozytorium (dostęp do danych)
import pl.projektchmury.notificationservice.model.NotificationRecord; // Nasz model danych
import software.amazon.awssdk.core.pagination.sync.SdkIterable; // Do obsługi paginowanych wyników z DynamoDB
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient; // "Ulepszony" klient DynamoDB
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable; // Reprezentuje tabelę DynamoDB, z którą pracujemy
import software.amazon.awssdk.enhanced.dynamodb.Key; // Do tworzenia kluczy (np. do wyszukiwania po ID)
import software.amazon.awssdk.enhanced.dynamodb.TableSchema; // Definiuje schemat tabeli dla mapowania obiektów Java
import software.amazon.awssdk.enhanced.dynamodb.model.Page; // Strona wyników z zapytania DynamoDB
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional; // Warunek dla zapytania DynamoDB (np. "klucz partycji równy X")
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest; // Obiekt reprezentujący zapytanie do DynamoDB
// import software.amazon.awssdk.services.dynamodb.model.AttributeValue; // Nie jest tu bezpośrednio używany, ale jest częścią SDK
import software.amazon.awssdk.services.dynamodb.model.DynamoDbException; // Wyjątek specyficzny dla operacji DynamoDB

import java.util.Collections; // Do tworzenia pustych list
import java.util.List; // Interfejs listy
import java.util.Optional; // Do obsługi opcjonalnych wartości
import java.util.stream.Collectors; // Do pracy ze strumieniami Java (np. do transformacji list)

@Repository // Mówi Springowi: "To jest komponent repozytorium, zarządzaj nim."
// Odpowiada za bezpośrednią interakcję z bazą danych (w tym przypadku DynamoDB).
public class DynamoDbNotificationRepository implements NotificationRepository { // Implementuje nasz interfejs repozytorium.

    private static final Logger logger = LoggerFactory.getLogger(DynamoDbNotificationRepository.class); // Logger.

    // Obiekt reprezentujący naszą tabelę "notification-history" w DynamoDB.
    // Jest typowany na NotificationRecord, co oznacza, że klient Enhanced wie, jak mapować
    // obiekty NotificationRecord na elementy tej tabeli.
    private final DynamoDbTable<NotificationRecord> notificationTable;

    // "Ulepszony" klient DynamoDB, wstrzyknięty przez Springa (z DynamoDbConfig).
    // Potrzebny do bardziej zaawansowanych operacji, jak zapytania na indeksach.
    private final DynamoDbEnhancedClient enhancedClient;

    // Stała przechowująca nazwę naszego Globalnego Indeksu Wtórnego (GSI).
    // Używamy jej, żeby nie robić literówek w kodzie.
    private static final String USER_ID_TIMESTAMP_INDEX = "userId-timestamp-index";

    @Autowired // Spring wstrzyknie tutaj zależności: enhancedClient i tableName.
    public DynamoDbNotificationRepository(DynamoDbEnhancedClient enhancedClient,
                                          // Wstrzyknij nazwę tabeli DynamoDB z pliku application.properties.
                                          @Value("${aws.dynamodb.table-name.notification-history}") String tableName) {
        this.enhancedClient = enhancedClient; // Przypisz wstrzykniętego klienta.
        // Utwórz obiekt DynamoDbTable, który będzie reprezentował naszą tabelę.
        // enhancedClient.table(...) bierze nazwę tabeli i schemat (jak mapować obiekty Java na tabelę).
        // TableSchema.fromBean(NotificationRecord.class) automatycznie tworzy schemat na podstawie adnotacji
        // w klasie NotificationRecord (np. @DynamoDbPartitionKey).
        this.notificationTable = enhancedClient.table(tableName, TableSchema.fromBean(NotificationRecord.class));
    }

    @Override // Implementacja metody save z interfejsu NotificationRepository.
    public NotificationRecord save(NotificationRecord record) {
        try {
            // Zapisz (lub zaktualizuj, jeśli element o tym samym kluczu głównym istnieje)
            // obiekt 'record' jako element w tabeli DynamoDB.
            notificationTable.putItem(record);
            logger.info("Successfully saved notification record: {}", record.getNotificationId());
            return record; // Zwróć zapisany obiekt.
        } catch (DynamoDbException e) { // Złap błąd, jeśli coś poszło nie tak z DynamoDB.
            logger.error("Error saving notification record {}: {}", record.getNotificationId(), e.getMessage(), e);
            // Rzuć wyjątek RuntimeException, żeby zasygnalizować problem wyżej.
            throw new RuntimeException("Error saving notification record to DynamoDB", e);
        }
    }

    @Override // Implementacja metody findById.
    public Optional<NotificationRecord> findById(String notificationId) {
        try {
            // Pobierz element z tabeli DynamoDB na podstawie klucza partycji (notificationId).
            // Key.builder().partitionValue(notificationId).build() tworzy obiekt klucza.
            NotificationRecord record = notificationTable.getItem(Key.builder().partitionValue(notificationId).build());
            logger.info("Found notification record for id: {}", notificationId);
            // Zwróć Optional. Jeśli 'record' jest null (nie znaleziono), Optional.ofNullable stworzy pusty Optional.
            return Optional.ofNullable(record);
        } catch (DynamoDbException e) {
            logger.error("Error finding notification record for id {}: {}", notificationId, e.getMessage(), e);
            return Optional.empty(); // W przypadku błędu, zwróć pusty Optional.
        }
    }

    @Override // Implementacja metody findByUserIdOrderByTimestampDesc.
    public List<NotificationRecord> findByUserIdOrderByTimestampDesc(String userId) {
        try {
            // Stwórz warunek zapytania dla naszego GSI: "userId" (klucz partycji GSI) musi być równy podanemu 'userId'.
            QueryConditional queryConditional = QueryConditional
                    .keyEqualTo(Key.builder().partitionValue(userId).build());

            // Stwórz obiekt żądania zapytania (QueryEnhancedRequest).
            QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                    .queryConditional(queryConditional) // Ustaw warunek zapytania.
                    // scanIndexForward(false) oznacza, że wyniki mają być sortowane MALEJĄCO
                    // według klucza sortowania indeksu (w naszym GSI jest to "timestamp").
                    // Czyli najnowsze powiadomienia będą pierwsze.
                    .scanIndexForward(false)
                    .build();

            // Wykonaj zapytanie na naszym Globalnym Indeksie Wtórnym (GSI).
            // Musimy jawnie wskazać nazwę indeksu (USER_ID_TIMESTAMP_INDEX).
            SdkIterable<Page<NotificationRecord>> queryResult = enhancedClient // Używamy enhancedClient
                    .table(notificationTable.tableName(), TableSchema.fromBean(NotificationRecord.class)) // Wskazujemy tabelę i schemat
                    .index(USER_ID_TIMESTAMP_INDEX) // WAŻNE: Mówimy, żeby użyć tego konkretnego indeksu
                    .query(request); // Wykonaj zapytanie.

            // Wyniki z DynamoDB mogą być podzielone na strony (jeśli jest ich dużo).
            // Musimy przejść przez wszystkie strony i zebrać wszystkie elementy.
            List<NotificationRecord> results = queryResult.stream() // Stwórz strumień ze stron wyników.
                    .flatMap(page -> page.items().stream()) // Dla każdej strony, weź jej elementy i "spłaszcz" je w jeden strumień.
                    .collect(Collectors.toList()); // Zbierz wszystkie elementy do listy.

            logger.info("Found {} notification records for userId: {}", results.size(), userId);
            return results; // Zwróć listę znalezionych powiadomień.

        } catch (DynamoDbException e) { // Obsługa błędów DynamoDB.
            logger.error("Error finding notifications for userId {}: {}", userId, e.getMessage(), e);
            return Collections.emptyList(); // Zwróć pustą listę w przypadku błędu.
        } catch (NullPointerException e) { // Dodatkowa obsługa błędu, jeśli np. indeks nie istnieje.
            logger.error("Error querying index '{}'. Does it exist?", USER_ID_TIMESTAMP_INDEX, e);
            return Collections.emptyList();
        }
    }
}
