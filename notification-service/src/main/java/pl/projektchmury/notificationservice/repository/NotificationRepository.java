package pl.projektchmury.notificationservice.repository;

import pl.projektchmury.notificationservice.model.NotificationRecord; // Importujemy nasz model danych
import java.util.List; // Do pracy z listami
import java.util.Optional; // Do reprezentowania wartości, która może być nullem (bezpieczniejsze niż bezpośrednie nulle)

// To jest interfejs repozytorium. Definiuje "kontrakt" - jakie operacje na danych
// (w tym przypadku na NotificationRecord) chcemy wykonywać.
// Konkretna implementacja (np. DynamoDbNotificationRepository) dostarczy logikę tych operacji.
// Użycie interfejsu ułatwia testowanie i zmianę implementacji w przyszłości (np. na inną bazę danych).
public interface NotificationRepository {

    // Metoda do zapisywania (lub aktualizowania) rekordu powiadomienia w bazie.
    // Przyjmuje obiekt NotificationRecord i zwraca zapisany obiekt (może mieć np. wygenerowane ID).
    NotificationRecord save(NotificationRecord record);

    // Metoda do znajdowania rekordu powiadomienia po jego unikalnym ID.
    // Zwraca Optional<NotificationRecord>, co oznacza, że rekord może istnieć (wtedy będzie w Optional)
    // lub nie (wtedy Optional będzie pusty). To pomaga unikać NullPointerException.
    Optional<NotificationRecord> findById(String notificationId);

    // Metoda do znajdowania wszystkich rekordów powiadomień dla danego użytkownika (userId),
    // posortowanych malejąco według czasu utworzenia (timestamp).
    // Zwraca listę znalezionych rekordów.
    List<NotificationRecord> findByUserIdOrderByTimestampDesc(String userId);
}
