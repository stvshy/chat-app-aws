package pl.projekt_chmury.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import pl.projekt_chmury.backend.model.Message;

public interface MessageRepository extends JpaRepository<Message, Long> {
}
