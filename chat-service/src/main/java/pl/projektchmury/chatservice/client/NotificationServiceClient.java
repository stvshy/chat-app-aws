package pl.projektchmury.chatservice.client;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.HashMap;
import java.util.Map;

@Component
public class NotificationServiceClient {

    private static final Logger logger = LoggerFactory.getLogger(NotificationServiceClient.class);
    private final WebClient webClient;

    @Value("${app.services.notification.url}")
    private String notificationServiceUrl; // Ta właściwość zostanie wstrzyknięta

    public NotificationServiceClient(WebClient.Builder webClientBuilder) {
        // Nie budujemy tutaj z base URL, bo pełny URL będzie w notificationServiceUrl
        this.webClient = webClientBuilder.build();
    }

    public void sendNewMessageNotification(
            String recipientUsername, // Nick odbiorcy, który będzie targetUserId w notification-service
            String senderUsername,    // Nick nadawcy, do użycia w treści powiadomienia
            String messageContentPreview, // Podgląd treści wiadomości
            String originalMessageId, // ID oryginalnej wiadomości z chat-service
            boolean hasFile,          // Czy wiadomość ma załącznik
            String authToken          // Token JWT oryginalnego nadawcy
    ) {
        String notificationType = hasFile ? "NEW_MESSAGE_WITH_FILE" : "NEW_MESSAGE";
        String subject = "Nowa wiadomość od " + senderUsername;
        String notificationMessageBody = senderUsername + " wysłał Ci wiadomość" +
                (hasFile ? " z plikiem: \"" : ": \"") +
                (messageContentPreview.length() > 30 ? messageContentPreview.substring(0, 27) + "..." : messageContentPreview) +
                "\"";

        Map<String, String> payload = new HashMap<>();
        payload.put("targetUserId", recipientUsername); // To jest kluczowe dla notification-service
        payload.put("type", notificationType);
        payload.put("subject", subject);
        payload.put("message", notificationMessageBody);
        if (originalMessageId != null) {
            payload.put("relatedEntityId", originalMessageId);
        }

        logger.info("Przygotowano payload do wysłania powiadomienia: {}", payload);
        logger.info("URL docelowy dla powiadomienia: {}/send", notificationServiceUrl);
        logger.info("Token autoryzacyjny dla powiadomienia: {}", (authToken != null && !authToken.isEmpty()) ? "OBECNY" : "BRAK");


        webClient.post()
                .uri(notificationServiceUrl + "/send") // Endpoint w notification-service
                .header(HttpHeaders.AUTHORIZATION, authToken) // Przekazanie tokenu
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(payload)
                .retrieve() // Rozpocznij pobieranie odpowiedzi
                .toBodilessEntity() // Interesuje nas tylko status, nie ciało odpowiedzi
                .doOnSuccess(response ->
                        logger.info("Powiadomienie wysłane pomyślnie do {}, status: {}",
                                recipientUsername, response.getStatusCode())
                )
                .doOnError(error ->
                        logger.error("Błąd podczas wysyłania powiadomienia do {}: {}",
                                recipientUsername, error.getMessage(), error)
                )
                .subscribe(); // Wykonaj asynchronicznie (fire-and-forget)
    }
}
