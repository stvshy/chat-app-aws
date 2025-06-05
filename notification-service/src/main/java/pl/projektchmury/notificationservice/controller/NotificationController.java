// Zewnętrzne żądanie HTTP POST -> NotificationController.createNotification()
// NotificationController -> NotificationStorageService.sendAndStoreNotification()
// NotificationStorageService -> SnsService.sendSnsNotification()
// SnsService (używając SnsClient skonfigurowanego przez SnsConfig) -> AWS SNS (wysyłka wiadomości)
// SnsService zwraca snsMessageId (lub null) -> NotificationStorageService
// NotificationStorageService tworzy NotificationRecord i wywołuje -> DynamoDbNotificationRepository.save()
// DynamoDbNotificationRepository (używając DynamoDbEnhancedClient skonfigurowanego przez DynamoDbConfig) -> AWS DynamoDB (zapis rekordu)
// Dyn/amoDbNotificationRepository zwraca zapisany rekord -> NotificationStorageService
// NotificationStorageService zwraca zapisany rekord -> NotificationController
// NotificationController zwraca odpowiedź HTTP do klienta.

package pl.projektchmury.notificationservice.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import pl.projektchmury.notificationservice.model.NotificationRecord;
import pl.projektchmury.notificationservice.service.NotificationStorageService;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {
    private static final Logger logger = LoggerFactory.getLogger(NotificationController.class);
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
        String requestingUserNick = jwt.getClaimAsString("username");
        if (requestingUserNick == null) {
            requestingUserNick = jwt.getClaimAsString("cognito:username");
        }
        if (requestingUserNick == null) {
            logger.error("Nie można pobrać nicku użytkownika z tokenu dla /history. Sub: {}", jwt.getSubject());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(null); // Zwracamy null jako ciało dla List<NotificationRecord>
        }
        logger.info("Pobieranie historii powiadomień dla użytkownika (nick): {}", requestingUserNick);
        List<NotificationRecord> history = notificationService.getNotificationHistory(requestingUserNick);
        return ResponseEntity.ok(history);
    }
//
//    @PostMapping("/send")
//    public ResponseEntity<NotificationRecord> createNotification(
//            @RequestBody Map<String, String> payload,
//            @AuthenticationPrincipal Jwt jwt
//    ) {
//        if (jwt == null) {
//            logger.warn("Niezautoryzowane żądanie do /api/notifications/send");
//            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
//        }
//
//        String targetUserIdFromPayload = payload.get("targetUserId");
//        String type = payload.getOrDefault("type", "UNDEFINED");
//        String subject = payload.get("subject");
//        String message = payload.get("message");
//        String relatedEntityId = payload.get("relatedEntityId");
//
//        if (targetUserIdFromPayload == null || targetUserIdFromPayload.isEmpty() ||
//                message == null || message.isEmpty()) {
//            logger.warn("Brakujące dane w payloadzie dla /send: targetUserId={}, message={}", targetUserIdFromPayload, message);
//            return ResponseEntity.badRequest().body(null); // Zwracamy null jako ciało dla NotificationRecord
//        }
//
//        logger.info("Odebrano żądanie utworzenia powiadomienia dla targetUserId: {}, type: {}, subject: {}, message: {}, relatedEntityId: {}. Zainicjowane przez użytkownika z tokenu (sub): {}",
//                targetUserIdFromPayload, type, subject, message, relatedEntityId, jwt.getSubject());
//
//        NotificationRecord record = notificationService.sendAndStoreNotification(
//                targetUserIdFromPayload,
//                type,
//                subject,
//                message,
//                relatedEntityId
//        );
//        return ResponseEntity.ok(record);
//    }

    @PostMapping("/{notificationId}/mark-as-read")
    public ResponseEntity<?> markNotificationAsRead( // Zmieniono na ResponseEntity<?> aby obsłużyć różne typy odpowiedzi
                                                     @PathVariable String notificationId,
                                                     @AuthenticationPrincipal Jwt jwt) {
        if (jwt == null) {
            logger.warn("[N_MarkAsRead] Brak autoryzacji dla notificationId: {}", notificationId);
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build(); // .build() zamiast .body("...")
        }

        String requestingUserNick = jwt.getClaimAsString("username");
        if (requestingUserNick == null) {
            requestingUserNick = jwt.getClaimAsString("cognito:username");
        }

        if (requestingUserNick == null) {
            logger.error("[N_MarkAsRead] Nie można pobrać nicku z tokenu. Sub: {}. NotificationId: {}", jwt.getSubject(), notificationId);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "Brak nicku w tokenie.")); // Zwracamy mapę jako JSON
        }

        logger.info("[N_MarkAsRead] Użytkownik (nick): {} próbuje oznaczyć powiadomienie ID: {} jako przeczytane.", requestingUserNick, notificationId);

        boolean success = notificationService.markNotificationAsRead(notificationId, requestingUserNick);

        if (success) {
            logger.info("[N_MarkAsRead] Powiadomienie {} pomyślnie oznaczone jako przeczytane dla użytkownika {}.", notificationId, requestingUserNick);
            Optional<NotificationRecord> updatedRecord = notificationService.getNotificationById(notificationId);
            return updatedRecord
                    .<ResponseEntity<?>>map(ResponseEntity::ok) // Jawne rzutowanie na ResponseEntity<?>
                    .orElseGet(() -> {
                        logger.error("[N_MarkAsRead] Nie znaleziono powiadomienia {} po aktualizacji, mimo że operacja save zwróciła sukces.", notificationId);
                        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of("error", "Błąd po aktualizacji powiadomienia."));
                    });
        } else {
            logger.warn("[N_MarkAsRead] Nie udało się oznaczyć powiadomienia {} jako przeczytane dla użytkownika {} (nie znaleziono, brak uprawnień, lub już przeczytane).", notificationId, requestingUserNick);
            Optional<NotificationRecord> recordOptional = notificationService.getNotificationById(notificationId);
            if (recordOptional.isEmpty()) {
                logger.warn("[N_MarkAsRead] Powiadomienie {} nie istnieje.", notificationId);
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Powiadomienie nie znalezione."));
            }
            logger.warn("[N_MarkAsRead] Powiadomienie {} istnieje, ale użytkownik {} nie jest właścicielem lub już jest przeczytane. Właściciel: {}, Status przeczytania: {}",
                    notificationId, requestingUserNick, recordOptional.get().getUserId(), recordOptional.get().isReadNotification());
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Brak uprawnień lub powiadomienie już przeczytane/nie znalezione."));
        }
    }
}
