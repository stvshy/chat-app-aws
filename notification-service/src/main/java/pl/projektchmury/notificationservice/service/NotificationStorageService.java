// Orkiestrator Powiadomień
package pl.projektchmury.notificationservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import pl.projektchmury.notificationservice.model.NotificationRecord;
import pl.projektchmury.notificationservice.repository.NotificationRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class NotificationStorageService {
    private static final Logger logger = LoggerFactory.getLogger(NotificationStorageService.class);
    private final NotificationRepository notificationRepository;
    private final SnsService snsService; // Pole przechowujące wstrzykniętą instancję SnsService
    @Autowired // Mówi Springowi, żeby automatycznie wstrzyknął zależności (NotificationRepository i SnsService) do tego konstruktora.
    public NotificationStorageService(NotificationRepository notificationRepository, SnsService snsService) {
        this.notificationRepository = notificationRepository;
        this.snsService = snsService; // Przypisanie wstrzykniętego SnsService.
    }

    public NotificationRecord sendAndStoreNotification(String userId, String type, String subject, String message, String relatedEntityId) {
        // KROK 1: Wyślij powiadomienie przez SNS.
        // Wywołujemy metodę z naszego SnsService, przekazując temat i treść wiadomości.
        // Metoda ta zwróci ID wiadomości SNS, jeśli wysyłka się powiodła, lub null w przypadku błędu.
        String snsMessageId = snsService.sendSnsNotification(subject, message);

        // KROK 2: Ustal status wysyłki na podstawie tego, czy dostaliśmy ID wiadomości SNS.
        String status = (snsMessageId != null) ? "SENT" : "FAILED"; // Jeśli snsMessageId nie jest null, to status "SENT", inaczej "FAILED".

        // KROK 3: Przygotuj i zapisz rekord powiadomienia w naszej bazie danych (DynamoDB).
        NotificationRecord record = new NotificationRecord();
        record.setNotificationId(UUID.randomUUID().toString()); // Wygeneruj unikalne ID dla tego rekordu powiadomienia.
        record.setUserId(userId); // Użytkownik, do którego jest to powiadomienie.
        record.setType(type);     // Typ powiadomienia.
        record.setMessage(message); // Treść powiadomienia.
        record.setTimestamp(Instant.now().toEpochMilli()); // Aktualny czas jako liczba milisekund od epochy.
        record.setStatus(status); // Ustaw status wysyłki ("SENT" lub "FAILED").
        record.setReadNotification(false); // Domyślnie powiadomienie jest nieprzeczytane.
        if (relatedEntityId != null) { // Jeśli jest powiązany identyfikator (np. ID wiadomości czatu)
            record.setRelatedEntityId(relatedEntityId); // Zapisz go.
        }
        // Zapisz przygotowany rekord do repozytorium (które w naszym przypadku komunikuje się z DynamoDB).
        return notificationRepository.save(record);
    }

    public List<NotificationRecord> getNotificationHistory(String userId) {
        return notificationRepository.findByUserIdOrderByTimestampDesc(userId);
    }

    public boolean markNotificationAsRead(String notificationId, String requestingUserId) {
        logger.info("[N_StorageSvc_MarkAsRead] Próba oznaczenia powiadomienia ID: {} jako przeczytane przez użytkownika: {}", notificationId, requestingUserId);
        Optional<NotificationRecord> recordOptional = notificationRepository.findById(notificationId); // Użyj istniejącej metody
        if (recordOptional.isPresent()) {
            NotificationRecord record = recordOptional.get();
            logger.info("[N_StorageSvc_MarkAsRead] Znaleziono powiadomienie ID: {}. Właściciel: {}, Aktualny status readNotification: {}",
                    notificationId, record.getUserId(), record.isReadNotification());

            if (record.getUserId().equals(requestingUserId)) {
                if (!record.isReadNotification()) {
                    record.setReadNotification(true);
                    notificationRepository.save(record); // Zapisz zaktualizowany rekord
                    logger.info("[N_StorageSvc_MarkAsRead] Powiadomienie ID: {} oznaczone jako przeczytane.", notificationId);
                } else {
                    logger.info("[N_StorageSvc_MarkAsRead] Powiadomienie ID: {} było już oznaczone jako przeczytane.", notificationId);
                }
                return true; // Sukces, nawet jeśli już było przeczytane
            } else {
                logger.warn("[N_StorageSvc_MarkAsRead] Użytkownik {} próbował oznaczyć powiadomienie {} należące do {}.",
                        requestingUserId, notificationId, record.getUserId());
                return false; // Brak uprawnień
            }
        }
        logger.warn("[N_StorageSvc_MarkAsRead] Powiadomienie ID: {} nie zostało znalezione.", notificationId);
        return false; // Powiadomienie nie znalezione
    }

    // aby kontroler mógł pobrać zaktualizowany rekord
    public Optional<NotificationRecord> getNotificationById(String notificationId) {
        return notificationRepository.findById(notificationId);
    }
}
