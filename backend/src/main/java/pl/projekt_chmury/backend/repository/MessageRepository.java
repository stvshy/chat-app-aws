package pl.projekt_chmury.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import pl.projekt_chmury.backend.model.Message;
import java.util.List;

public interface MessageRepository extends JpaRepository<Message, Long> {
    List<Message> findByAuthorUsername(String username);
    List<Message> findByRecipientUsername(String username);
}
