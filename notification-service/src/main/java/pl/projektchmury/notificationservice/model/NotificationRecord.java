package pl.projektchmury.notificationservice.model;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean; // Oznacza, że ta klasa Java mapuje się na tabelę/elementy DynamoDB
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey; // Oznacza pole jako klucz partycji tabeli DynamoDB
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey; // Oznacza pole jako klucz partycji dla Globalnego Indeksu Wtórnego (GSI)
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;     // Oznacza pole jako klucz sortowania dla GSI

// Ta klasa to nasz "model" danych dla pojedynczego rekordu powiadomienia.
// Adnotacja @DynamoDbBean mówi klientowi DynamoDB Enhanced, jak mapować
// pola tej klasy na atrybuty w tabeli DynamoDB.
@DynamoDbBean
public class NotificationRecord {

    // Pola klasy odpowiadają atrybutom w tabeli DynamoDB.
    private String notificationId; // Unikalny identyfikator powiadomienia.
    private String userId;         // Identyfikator użytkownika (np. nick), do którego jest to powiadomienie.
    private String type;           // Typ powiadomienia (np. "NEW_MESSAGE", "SYSTEM_ALERT").
    private String message;        // Treść powiadomienia.
    private long timestamp;        // Czas utworzenia powiadomienia (jako liczba milisekund od epochy).
    private String status;         // Status wysyłki (np. "SENT", "FAILED").
    private boolean readNotification = false; // Czy użytkownik przeczytał to powiadomienie? Domyślnie false.
    private String relatedEntityId; // Opcjonalny identyfikator powiązanego obiektu (np. ID wiadomości czatu, która wywołała to powiadomienie).

    // Getter dla notificationId.
    // @DynamoDbPartitionKey oznacza, że pole "notificationId" jest kluczem partycji (głównym kluczem)
    // w tabeli DynamoDB. Każdy element w tabeli musi mieć unikalny klucz partycji.
    @DynamoDbPartitionKey
    public String getNotificationId() {
        return notificationId;
    }
    // Setter dla notificationId.
    public void setNotificationId(String notificationId) {
        this.notificationId = notificationId;
    }

    // Getter dla userId.
    // @DynamoDbSecondaryPartitionKey(indexNames = "userId-timestamp-index") oznacza, że pole "userId"
    // jest kluczem partycji dla Globalnego Indeksu Wtórnego (GSI) o nazwie "userId-timestamp-index".
    // GSI pozwala na efektywne wyszukiwanie elementów po innych atrybutach niż główny klucz partycji.
    // W tym przypadku, możemy szybko znaleźć wszystkie powiadomienia dla danego użytkownika.
    @DynamoDbSecondaryPartitionKey(indexNames = "userId-timestamp-index")
    public String getUserId() {
        return userId;
    }
    // Setter dla userId.
    public void setUserId(String userId) {
        this.userId = userId;
    }

    // Standardowe gettery i settery dla pozostałych pól.
    public String getType() {
        return type;
    }
    public void setType(String type) {
        this.type = type;
    }

    public String getMessage() {
        return message;
    }
    public void setMessage(String message) {
        this.message = message;
    }

    // Getter dla timestamp.
    // @DynamoDbSecondarySortKey(indexNames = "userId-timestamp-index") oznacza, że pole "timestamp"
    // jest kluczem sortowania dla GSI "userId-timestamp-index".
    // W połączeniu z kluczem partycji GSI ("userId"), pozwala to na sortowanie powiadomień
    // danego użytkownika po czasie ich utworzenia.
    @DynamoDbSecondarySortKey(indexNames = "userId-timestamp-index")
    public long getTimestamp() {
        return timestamp;
    }
    // Setter dla timestamp.
    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }

    public String getStatus() {
        return status;
    }
    public void setStatus(String status) {
        this.status = status;
    }

    public boolean isReadNotification() {
        return readNotification;
    }
    public void setReadNotification(boolean readNotification) {
        this.readNotification = readNotification;
    }

    public String getRelatedEntityId() {
        return relatedEntityId;
    }
    public void setRelatedEntityId(String relatedEntityId) {
        this.relatedEntityId = relatedEntityId;
    }
}
