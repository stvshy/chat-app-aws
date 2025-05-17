package pl.projektchmury.notificationservice.controller;

import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import pl.projektchmury.notificationservice.model.NotificationRecord;
import pl.projektchmury.notificationservice.service.NotificationStorageService;
import org.slf4j.Logger; // DODAJ TEN IMPORT
import org.slf4j.LoggerFactory; // DODAJ TEN IMPORT
import java.util.List;
import java.util.Map;


@RestController
@RequestMapping("/api/notifications")
public class NotificationController {
    private static final Logger logger = LoggerFactory.getLogger(NotificationController.class); // DODAJ LOGGER
    private final NotificationStorageService notificationService;

    @Autowired
    public NotificationController(NotificationStorageService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping("/history")
    public ResponseEntity<List<NotificationRecord>> getHistory(@AuthenticationPrincipal Jwt jwt) {
        if (jwt == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        // Zakładamy, że NotificationRecord.userId to nick, więc pobieramy nick z tokenu
        String requestingUserNick = jwt.getClaimAsString("username");
        if (requestingUserNick == null) {
            requestingUserNick = jwt.getClaimAsString("cognito:username");
        }
        if (requestingUserNick == null) {
            logger.error("Nie można pobrać nicku użytkownika z tokenu dla /history. Sub: {}", jwt.getSubject());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(null);
        }
        logger.info("Pobieranie historii powiadomień dla użytkownika (nick): {}", requestingUserNick);
        List<NotificationRecord> history = notificationService.getNotificationHistory(requestingUserNick);
        return ResponseEntity.ok(history);
    }

    // ZMODYFIKOWANY ENDPOINT - używany przez inne serwisy
    @PostMapping("/send")
    public ResponseEntity<NotificationRecord> createNotification(
            @RequestBody Map<String, String> payload,
            @AuthenticationPrincipal Jwt jwt // JWT służy do autoryzacji serwisu wywołującego
    ) {
        if (jwt == null) {
            logger.warn("Niezautoryzowane żądanie do /api/notifications/send");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String targetUserIdFromPayload = payload.get("targetUserId"); // To powinien być NICK odbiorcy
        String type = payload.getOrDefault("type", "UNDEFINED");
        String subject = payload.get("subject"); // Może być null, jeśli nie jest wymagany dla wszystkich typów
        String message = payload.get("message");
        String relatedEntityId = payload.get("relatedEntityId"); // Opcjonalne

        if (targetUserIdFromPayload == null || targetUserIdFromPayload.isEmpty() ||
                message == null || message.isEmpty()) {
            logger.warn("Brakujące dane w payloadzie dla /send: targetUserId={}, message={}", targetUserIdFromPayload, message);
            return ResponseEntity.badRequest().body(null);
        }

        logger.info("Odebrano żądanie utworzenia powiadomienia dla targetUserId: {}, type: {}, subject: {}, message: {}, relatedEntityId: {}. Zainicjowane przez użytkownika z tokenu (sub): {}",
                targetUserIdFromPayload, type, subject, message, relatedEntityId, jwt.getSubject());

        // Przekazujemy targetUserIdFromPayload (nick) do serwisu
        NotificationRecord record = notificationService.sendAndStoreNotification(
                targetUserIdFromPayload, // NICK ODBIORCY
                type,
                subject,
                message,
                relatedEntityId // Przekaż relatedEntityId
        );
        return ResponseEntity.ok(record);
    }

    @PostMapping("/{notificationId}/mark-as-read")
    public ResponseEntity<?> markNotificationAsRead(
            @PathVariable String notificationId,
            @AuthenticationPrincipal Jwt jwt) {
        if (jwt == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        // Do weryfikacji uprawnień używamy nicku użytkownika z tokenu,
        // zakładając, że NotificationRecord.userId to nick.
        String requestingUserNick = jwt.getClaimAsString("username");
        if (requestingUserNick == null) {
            requestingUserNick = jwt.getClaimAsString("cognito:username");
        }
        if (requestingUserNick == null) {
            logger.error("Nie można pobrać nicku użytkownika z tokenu dla /mark-as-read. Sub: {}", jwt.getSubject());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(null);
        }

        logger.info("Użytkownik (nick): {} próbuje oznaczyć powiadomienie {} jako przeczytane.", requestingUserNick, notificationId);
        boolean success = notificationService.markNotificationAsRead(notificationId, requestingUserNick);
        if (success) {
            logger.info("Powiadomienie {} oznaczone jako przeczytane dla użytkownika {}.", notificationId, requestingUserNick);
            return ResponseEntity.ok().build();
        } else {
            logger.warn("Nie udało się oznaczyć powiadomienia {} jako przeczytane dla użytkownika {} (nie znaleziono lub brak uprawnień).", notificationId, requestingUserNick);
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body("Powiadomienie nie znalezione lub brak uprawnień.");
        }
    }
}
