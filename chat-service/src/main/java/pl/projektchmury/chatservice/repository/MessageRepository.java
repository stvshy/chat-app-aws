package pl.projektchmury.chatservice.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import pl.projektchmury.chatservice.model.Message;

import java.util.List;

public interface MessageRepository extends JpaRepository<Message, Long> {
    List<Message> findByAuthorUsername(String username);
    List<Message> findByRecipientUsername(String username);
}
