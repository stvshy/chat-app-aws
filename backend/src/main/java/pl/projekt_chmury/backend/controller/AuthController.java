package pl.projekt_chmury.backend.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pl.projekt_chmury.backend.model.User;
import pl.projekt_chmury.backend.service.CognitoService;
import software.amazon.awssdk.services.cognitoidentityprovider.model.InitiateAuthResponse;
import software.amazon.awssdk.services.cognitoidentityprovider.model.SignUpResponse;

import java.util.HashMap;
import java.util.Map;
import java.util.Arrays;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final CognitoService cognitoService;

    public AuthController(CognitoService cognitoService) {
        this.cognitoService = cognitoService;
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody User user) {
        try {
            // Rejestrujemy użytkownika w Cognito
            SignUpResponse response = cognitoService.signUp(user.getUsername(), user.getPassword());
            return ResponseEntity.ok("Rejestracja pomyślna. UserSub: " + response.userSub());
        } catch (Exception e) {
            // Wyświetlamy pełen stack trace w logach
            e.printStackTrace();

            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body("Błąd rejestracji: " + e.getMessage() + "\nStackTrace: " + Arrays.toString(e.getStackTrace()));
        }
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody User loginData) {
        try {
            InitiateAuthResponse response = cognitoService.userLogin(loginData.getUsername(), loginData.getPassword());
            Map<String, String> tokens = new HashMap<>();
            tokens.put("idToken", response.authenticationResult().idToken());
            tokens.put("accessToken", response.authenticationResult().accessToken());
            tokens.put("refreshToken", response.authenticationResult().refreshToken());
            tokens.put("tokenType", response.authenticationResult().tokenType());
            return ResponseEntity.ok(tokens);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body("Błąd logowania: " + e.getMessage());
        }
    }
}
