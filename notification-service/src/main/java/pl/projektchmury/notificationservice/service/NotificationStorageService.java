package pl.projektchmury.notificationservice.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import pl.projektchmury.notificationservice.model.NotificationRecord;
import pl.projektchmury.notificationservice.repository.NotificationRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

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
        String snsMessageId = snsService.sendSnsNotification(subject, message); // Zmieniono nazwę zmiennej
        String status = (snsMessageId != null) ? "SENT" : "FAILED";

        NotificationRecord record = new NotificationRecord();
        record.setNotificationId(UUID.randomUUID().toString());
        record.setUserId(userId); // To powinien być NICK odbiorcy
        record.setType(type);
        record.setMessage(message);
        record.setTimestamp(Instant.now().toEpochMilli());
        record.setStatus(status);
        record.setReadNotification(false); // Jawne ustawienie
        if (relatedEntityId != null) {
            record.setRelatedEntityId(relatedEntityId); // Zapisz relatedEntityId
        }
        // Można dodać pole snsMessageId: record.setSnsMessageId(snsMessageId);
        return notificationRepository.save(record);
    }

    public List<NotificationRecord> getNotificationHistory(String userId) {
        return notificationRepository.findByUserIdOrderByTimestampDesc(userId);
    }
    public boolean markNotificationAsRead(String notificationId, String requestingUserId) {
        Optional<NotificationRecord> recordOptional = notificationRepository.findById(notificationId);
        if (recordOptional.isPresent()) {
            NotificationRecord record = recordOptional.get();
            // Upewnij się, że użytkownik próbujący oznaczyć powiadomienie jest jego właścicielem
            if (record.getUserId().equals(requestingUserId)) { // Porównaj z userId zapisanym w rekordzie
                if (!record.isReadNotification()) {
                    record.setReadNotification(true);
                    notificationRepository.save(record);
                }
                return true;
            } else {
                // Logika błędu - próba oznaczenia cudzego powiadomienia
                logger.warn("Użytkownik {} próbował oznaczyć jako przeczytane powiadomienie {} należące do {}",
                        requestingUserId, notificationId, record.getUserId());
                return false;
            }
        }
        return false; // Powiadomienie nie znalezione
    }
}
