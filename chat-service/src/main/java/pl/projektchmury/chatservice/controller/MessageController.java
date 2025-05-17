package pl.projektchmury.chatservice.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders; // WAŻNY IMPORT
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import pl.projektchmury.chatservice.client.NotificationServiceClient; // WAŻNY IMPORT
import pl.projektchmury.chatservice.model.Message;
import pl.projektchmury.chatservice.repository.MessageRepository;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/messages")
public class MessageController {
    private static final Logger logger = LoggerFactory.getLogger(MessageController.class);

    @Autowired
    private MessageRepository messageRepository;

    @Autowired // WSTRZYKNIĘCIE KLIENTA POWIADOMIEŃ
    private NotificationServiceClient notificationServiceClient;

    // Endpoint: wiadomości wysłane przez danego użytkownika
    @GetMapping("/sent")
    public List<Message> getSentMessages(@RequestParam String username) {
        logger.debug("getSentMessages called with username: {}", username);
        return messageRepository.findByAuthorUsername(username);
    }

    // Endpoint: wiadomości odebrane przez danego użytkownika
    @GetMapping("/received")
    public List<Message> getReceivedMessages(@RequestParam String username, @AuthenticationPrincipal Jwt jwt) {
        String requesterNick = null;
        if (jwt != null) {
            requesterNick = jwt.getClaimAsString("username");
            if (requesterNick == null) {
                requesterNick = jwt.getClaimAsString("cognito:username");
            }
        }
        String requesterLog = (requesterNick != null) ? requesterNick : ((jwt != null) ? jwt.getSubject() : "UNKNOWN_REQUESTER");

        logger.info("[getReceivedMessages] Użytkownik {} (żądający: {}) pobiera odebrane wiadomości.", username, requesterLog);
        List<Message> messages = messageRepository.findByRecipientUsername(username);
        if (messages.isEmpty()) {
            logger.info("[getReceivedMessages] Nie znaleziono wiadomości dla odbiorcy: {}", username);
        } else {
            messages.forEach(msg -> logger.info("[getReceivedMessages] Wiadomość ID: {}, Nadawca: {}, Odbiorca: {}, Treść: '{}', Status read: {}",
                    msg.getId(), msg.getAuthorUsername(), msg.getRecipientUsername(), msg.getContent().substring(0, Math.min(msg.getContent().length(), 20)), msg.isRead()));
        }
        return messages;
    }

    // Endpoint tworzenia wiadomości
    @PostMapping
    public Message addMessage(@RequestBody Map<String, String> body,
                              @RequestHeader(HttpHeaders.AUTHORIZATION) String authorizationHeader) { // Pobranie nagłówka Authorization
        String authorUsername = body.get("author");
        String content = body.get("content");
        String recipientUsername = body.get("recipient");
        String fileId = body.get("fileId");

        logger.debug("Próba zapisu wiadomości. Nadawca: {}, treść: {}, odbiorca: {}, fileId: {}",
                authorUsername, content, recipientUsername, fileId);

        Message msg = new Message(authorUsername, content);
        msg.setRecipientUsername(recipientUsername);
        if (fileId != null && !fileId.isEmpty()) {
            msg.setFileId(fileId);
        }
        Message savedMessage = messageRepository.save(msg);
        logger.info("Wiadomość ID: {} zapisana pomyślnie.", savedMessage.getId());

        // Po pomyślnym zapisaniu wiadomości, wyślij powiadomienie, jeśli jest odbiorca i nie jest to wiadomość do samego siebie
        if (savedMessage.getRecipientUsername() != null &&
                !savedMessage.getRecipientUsername().isEmpty() &&
                !savedMessage.getRecipientUsername().equals(savedMessage.getAuthorUsername())) {

            logger.info("Inicjowanie wysyłania powiadomienia dla wiadomości ID: {} do odbiorcy: {}",
                    savedMessage.getId(), savedMessage.getRecipientUsername());
            notificationServiceClient.sendNewMessageNotification(
                    savedMessage.getRecipientUsername(),
                    savedMessage.getAuthorUsername(),
                    savedMessage.getContent(),
                    savedMessage.getId().toString(),
                    savedMessage.getFileId() != null && !savedMessage.getFileId().isEmpty(),
                    authorizationHeader // Przekazanie oryginalnego tokenu nadawcy
            );
        } else {
            logger.info("Pominięto wysyłanie powiadomienia dla wiadomości ID: {} (brak odbiorcy lub wiadomość do samego siebie).", savedMessage.getId());
        }

        return savedMessage;
    }

    // ZMODYFIKOWANY ENDPOINT: Oznaczanie wiadomości jako przeczytanej
    @Transactional
    @PostMapping("/{messageId}/mark-as-read")
    public ResponseEntity<?> markMessageAsRead(
            @PathVariable Long messageId,
            @AuthenticationPrincipal Jwt jwt) {

        if (jwt == null) {
            logger.warn("[markMessageAsRead] Próba bez autoryzacji dla messageId: {}", messageId);
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Brak autoryzacji.");
        }

        String currentUsernameFromToken = jwt.getClaimAsString("username");
        if (currentUsernameFromToken == null) {
            currentUsernameFromToken = jwt.getClaimAsString("cognito:username");
        }

        if (currentUsernameFromToken == null) {
            logger.error("[markMessageAsRead] Nie można uzyskać nazwy użytkownika (nicku) z tokenu JWT. Dostępne claimy: {}.", jwt.getClaims());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body("Błąd konfiguracji autoryzacji: brak nicku w tokenie.");
        }

        logger.info("[markMessageAsRead] Użytkownik z tokenu (nick): {} (sub: {}) próbuje oznaczyć wiadomość ID: {} jako przeczytaną.",
                currentUsernameFromToken, jwt.getSubject(), messageId);

        Optional<Message> optionalMessage = messageRepository.findById(messageId);

        if (optionalMessage.isEmpty()) {
            logger.warn("[markMessageAsRead] Nie znaleziono wiadomości o ID: {} (Użytkownik z tokenu: {}).", messageId, currentUsernameFromToken);
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body("Wiadomość nie znaleziona.");
        }

        Message message = optionalMessage.get();
        logger.info("[markMessageAsRead] Znaleziono wiadomość ID: {}. Aktualny status read: {}. Odbiorca w wiadomości: {}.",
                messageId, message.isRead(), message.getRecipientUsername());

        if (!currentUsernameFromToken.equals(message.getRecipientUsername())) {
            logger.warn("[markMessageAsRead] Użytkownik z tokenu (nick): {} próbował oznaczyć wiadomość (ID: {}) nie dla niego (odbiorca w wiadomości: {}).",
                    currentUsernameFromToken, messageId, message.getRecipientUsername());
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Nie masz uprawnień do tej operacji.");
        }

        if (message.isRead()) {
            logger.info("[markMessageAsRead] Wiadomość (ID: {}) była już oznaczona jako przeczytana. Zwracam OK.", messageId);
            return ResponseEntity.ok(message);
        }

        logger.info("[markMessageAsRead] Oznaczanie wiadomości (ID: {}) jako read=true.", messageId);
        message.setRead(true);
        logger.info("[markMessageAsRead] Stan message (ID: {}) PRZED zapisem: read={}", messageId, message.isRead());

        Message updatedMessage = messageRepository.save(message);

        logger.info("[markMessageAsRead] Stan message (ID: {}) PO zapisie (z updatedMessage): read={}", messageId, updatedMessage.isRead());

        Optional<Message> reFetchedMessageOptional = messageRepository.findById(messageId);
        if (reFetchedMessageOptional.isPresent()) {
            Message reFetchedMessage = reFetchedMessageOptional.get();
            logger.info("[markMessageAsRead] Stan message (ID: {}) PO PONOWNYM ODCZYCIE Z BAZY: read={}", messageId, reFetchedMessage.isRead());
        } else {
            logger.error("[markMessageAsRead] BŁĄD KRYTYCZNY: Wiadomość (ID: {}) zniknęła po zapisie!", messageId);
        }

        logger.info("[markMessageAsRead] Wiadomość (ID: {}) pomyślnie oznaczona jako przeczytana przez użytkownika (nick z tokenu): {}. Zwracam OK.", messageId, currentUsernameFromToken);
        return ResponseEntity.ok(updatedMessage);
    }
}
