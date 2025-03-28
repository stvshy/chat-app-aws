package pl.projekt_chmury.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import pl.projekt_chmury.backend.model.User;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
    boolean existsByUsername(String username);
}
