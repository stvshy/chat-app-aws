package pl.projekt_chmury.backend.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pl.projekt_chmury.backend.model.User;
import pl.projekt_chmury.backend.repository.UserRepository;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api")
public class UserController {

    private final UserRepository userRepository;

    public UserController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @GetMapping("/api/users")
    public List<String> getAllUsernames() {
        // Zwracamy tylko nazwy użytkowników
        return userRepository.findAll().stream()
                .map(User::getUsername)
                .collect(Collectors.toList());
    }
}
