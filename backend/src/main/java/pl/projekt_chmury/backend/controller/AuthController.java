package pl.projekt_chmury.backend.controller;

import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.annotation.*;
import pl.projekt_chmury.backend.model.User;
import pl.projekt_chmury.backend.repository.UserRepository;
import pl.projekt_chmury.backend.util.JwtUtil;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserRepository userRepository;
    private final JwtUtil jwtUtil;
    private final AuthenticationManager authenticationManager;
    private final org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    public AuthController(UserRepository userRepository,
                          org.springframework.security.crypto.password.PasswordEncoder passwordEncoder,
                          JwtUtil jwtUtil,
                          AuthenticationManager authenticationManager) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.authenticationManager = authenticationManager;
    }

    @PostMapping("/register")
    public String register(@RequestBody User user) {
        if (userRepository.existsByUsername(user.getUsername())) {
            return "Użytkownik o takiej nazwie już istnieje.";
        }
        String hashedPassword = passwordEncoder.encode(user.getPassword());
        user.setPassword(hashedPassword);
        userRepository.save(user);
        return "Rejestracja pomyślna.";
    }

    @PostMapping("/login")
    public Map<String, String> login(@RequestBody User loginData) {
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(loginData.getUsername(), loginData.getPassword())
            );
        } catch (AuthenticationException e) {
            throw new RuntimeException("Niepoprawne dane logowania.");
        }
        String token = jwtUtil.generateToken(loginData.getUsername());
        Map<String, String> response = new HashMap<>();
        response.put("token", token);
        return response;
    }
}
