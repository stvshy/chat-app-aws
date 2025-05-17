// notification-service/src/main/java/pl/projektchmury/notificationservice/repository/NotificationRepository.java
package pl.projektchmury.notificationservice.repository;

import pl.projektchmury.notificationservice.model.NotificationRecord;
import java.util.List;
import java.util.Optional;

public interface NotificationRepository {
    NotificationRecord save(NotificationRecord record);
    Optional<NotificationRecord> findById(String notificationId); // Ta metoda już istnieje i jest wystarczająca
    List<NotificationRecord> findByUserIdOrderByTimestampDesc(String userId);
}
