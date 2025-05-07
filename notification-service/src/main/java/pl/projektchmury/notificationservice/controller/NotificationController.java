package pl.projektchmury.notificationservice.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import pl.projektchmury.notificationservice.model.NotificationRecord;
import pl.projektchmury.notificationservice.service.NotificationStorageService;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private final NotificationStorageService notificationService;

    @Autowired
    public NotificationController(NotificationStorageService notificationService) {
        this.notificationService = notificationService;
    }

    // Endpoint do pobierania historii powiadomień dla zalogowanego użytkownika
    @GetMapping("/history")
    public ResponseEntity<List<NotificationRecord>> getHistory(@AuthenticationPrincipal Jwt jwt) {
        if (jwt == null) {
            return ResponseEntity.status(401).build();
        }
        String userId = jwt.getSubject(); // Używamy subject jako userId
        List<NotificationRecord> history = notificationService.getNotificationHistory(userId);
        return ResponseEntity.ok(history);
    }

    // Testowy endpoint do wysyłania powiadomienia
    // W realnej aplikacji ten endpoint mógłby nie istnieć,
    // a powiadomienia byłyby wyzwalane przez inne serwisy (np. przez SQS).
    @PostMapping("/send")
    public ResponseEntity<NotificationRecord> sendTestNotification(
            @RequestBody Map<String, String> payload,
            @AuthenticationPrincipal Jwt jwt) {
        if (jwt == null) {
            return ResponseEntity.status(401).build();
        }
        String userId = jwt.getSubject();
        String type = payload.getOrDefault("type", "TEST");
        String subject = payload.getOrDefault("subject", "Test Notification");
        String message = payload.getOrDefault("message", "This is a test notification.");

        NotificationRecord record = notificationService.sendAndStoreNotification(userId, type, subject, message);
        return ResponseEntity.ok(record);
    }
}
