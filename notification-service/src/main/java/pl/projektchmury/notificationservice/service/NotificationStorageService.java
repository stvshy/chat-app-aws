// notification-service/src/main/java/pl/projektchmury/notificationservice/service/NotificationStorageService.java
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
    private final SnsService snsService;

    @Autowired
    public NotificationStorageService(NotificationRepository notificationRepository, SnsService snsService) {
        this.notificationRepository = notificationRepository;
        this.snsService = snsService;
    }

    public NotificationRecord sendAndStoreNotification(String userId, String type, String subject, String message, String relatedEntityId) {
        String snsMessageId = snsService.sendSnsNotification(subject, message);
        String status = (snsMessageId != null) ? "SENT" : "FAILED";

        NotificationRecord record = new NotificationRecord();
        record.setNotificationId(UUID.randomUUID().toString());
        record.setUserId(userId);
        record.setType(type);
        record.setMessage(message);
        record.setTimestamp(Instant.now().toEpochMilli());
        record.setStatus(status);
        record.setReadNotification(false);
        if (relatedEntityId != null) {
            record.setRelatedEntityId(relatedEntityId);
        }
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

    // Dodajemy tę metodę, aby kontroler mógł pobrać zaktualizowany rekord
    public Optional<NotificationRecord> getNotificationById(String notificationId) {
        return notificationRepository.findById(notificationId);
    }
}
