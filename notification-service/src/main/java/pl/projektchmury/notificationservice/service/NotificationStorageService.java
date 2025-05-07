package pl.projektchmury.notificationservice.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import pl.projektchmury.notificationservice.model.NotificationRecord;
import pl.projektchmury.notificationservice.repository.NotificationRepository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class NotificationStorageService {

    private final NotificationRepository notificationRepository;
    private final SnsService snsService;

    @Autowired
    public NotificationStorageService(NotificationRepository notificationRepository, SnsService snsService) {
        this.notificationRepository = notificationRepository;
        this.snsService = snsService;
    }

    public NotificationRecord sendAndStoreNotification(String userId, String type, String subject, String message) {
        // 1. Wyślij powiadomienie przez SNS
        String messageId = snsService.sendSnsNotification(subject, message);
        String status = (messageId != null) ? "SENT" : "FAILED";

        // 2. Przygotuj rekord do zapisu w historii
        NotificationRecord record = new NotificationRecord();
        record.setNotificationId(UUID.randomUUID().toString()); // Generuj unikalne ID dla rekordu historii
        record.setUserId(userId);
        record.setType(type);
        record.setMessage(message);
        record.setTimestamp(Instant.now().toEpochMilli());
        record.setStatus(status);
        // Można dodać pole snsMessageId: record.setSnsMessageId(messageId);

        // 3. Zapisz rekord w DynamoDB (przez repozytorium)
        return notificationRepository.save(record);
    }

    public List<NotificationRecord> getNotificationHistory(String userId) {
        return notificationRepository.findByUserIdOrderByTimestampDesc(userId);
    }
}
