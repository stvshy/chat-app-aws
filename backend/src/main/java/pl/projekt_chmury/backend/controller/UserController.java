package pl.projekt_chmury.backend.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pl.projekt_chmury.backend.model.User;
import pl.projekt_chmury.backend.repository.UserRepository;

import java.sql.Connection;
import java.sql.DriverManager;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;
import org.springframework.core.env.Environment;
import org.springframework.beans.factory.annotation.Autowired;

@RestController
@RequestMapping("/api")

public class UserController {

    private final UserRepository userRepository;
    private final Environment environment;

    @Autowired
    public UserController(UserRepository userRepository, Environment environment) {
        this.userRepository = userRepository;
        this.environment = environment;
    }

    @GetMapping("/api/users")
    public List<String> getAllUsernames() {
        return userRepository.findAll().stream()
                .map(User::getUsername)
                .collect(Collectors.toList());
    }

    @GetMapping("/test-db")
    public String testDb() {
        try (Connection conn = DriverManager.getConnection(
                Objects.requireNonNull(environment.getProperty("spring.datasource.url")),
                environment.getProperty("spring.datasource.username"),
                environment.getProperty("spring.datasource.password")
        )) {
            return "Connected to DB: " + conn.getMetaData().getURL();
        } catch(Exception e) {
            return "Error: " + e.getMessage();
        }
    }
}
