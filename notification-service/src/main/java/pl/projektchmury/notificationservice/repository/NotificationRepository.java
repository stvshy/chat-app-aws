package pl.projektchmury.notificationservice.repository;

import pl.projektchmury.notificationservice.model.NotificationRecord;
import java.util.List;
import java.util.Optional;

public interface NotificationRepository {
    NotificationRecord save(NotificationRecord record);
    Optional<NotificationRecord> findById(String notificationId);
    List<NotificationRecord> findByUserIdOrderByTimestampDesc(String userId); // Do pobierania historii
}
