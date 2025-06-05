// notification-service/src/main/java/pl/projektchmury/notificationservice/listener/SqsNotificationListener.java
package pl.projektchmury.notificationservice.listener;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.awspring.cloud.sqs.annotation.SqsListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Component;
import pl.projektchmury.notificationservice.service.NotificationStorageService;

import java.util.Map;

@Component
public class SqsNotificationListener {

    private static final Logger logger = LoggerFactory.getLogger(SqsNotificationListener.class);
    private final NotificationStorageService notificationStorageService;
    private final ObjectMapper objectMapper;

    @Autowired
    public SqsNotificationListener(NotificationStorageService notificationStorageService, ObjectMapper objectMapper) {
        this.notificationStorageService = notificationStorageService;
        this.objectMapper = objectMapper;
    }

    // Nazwa kolejki SQS będzie pobierana ze zmiennej środowiskowej APP_SQS_QUEUE_NAME
    // W Terraformie przekazujemy URL kolejki jako APP_SQS_QUEUE_URL.
    // Spring Cloud AWS potrafi obsłużyć URL kolejki, jeśli podamy go jako ${app.sqs.queue-url}
    // lub możemy użyć samej nazwy kolejki, jeśli jest unikalna w regionie.
    // Dla pewności użyjemy URL.
    @SqsListener("${app.sqs.queue-url}") // Odwołanie do właściwości z application.properties
    public void receiveMessage(@Payload String messagePayload) {
        logger.info("Received SQS message: {}", messagePayload);
        try {
            Map<String, String> payloadMap = objectMapper.readValue(messagePayload, new TypeReference<Map<String, String>>() {});

            String targetUserId = payloadMap.get("targetUserId");
            String type = payloadMap.getOrDefault("type", "UNDEFINED_FROM_SQS");
            String subject = payloadMap.get("subject"); // Powinno być wysłane przez SendMessageLambda
            String messageBody = payloadMap.get("message"); // Powinno być wysłane przez SendMessageLambda
            String relatedEntityId = payloadMap.get("relatedEntityId");
            // String senderUsername = payloadMap.get("senderUsername"); // Można użyć, jeśli potrzebne

            if (targetUserId == null || targetUserId.isEmpty() || messageBody == null || messageBody.isEmpty()) {
                logger.warn("Missing required fields in SQS message payload: targetUserId or message. Payload: {}", messagePayload);
                // Można rozważyć wysłanie do Dead Letter Queue (DLQ)
                return;
            }

            logger.info("Processing SQS notification for targetUserId: {}, type: {}, subject: {}, message: {}, relatedEntityId: {}",
                    targetUserId, type, subject, messageBody, relatedEntityId);

            // Wywołaj istniejącą logikę serwisu do wysłania i zapisania powiadomienia
            notificationStorageService.sendAndStoreNotification(
                    targetUserId,
                    type,
                    subject, // Przekazujemy subject z wiadomości SQS
                    messageBody, // Przekazujemy message z wiadomości SQS
                    relatedEntityId
            );
            logger.info("Successfully processed SQS message for targetUserId: {}", targetUserId);

        } catch (JsonProcessingException e) {
            logger.error("Error deserializing SQS message payload: {}. Error: {}", messagePayload, e.getMessage(), e);
            // Rozważ DLQ
        } catch (Exception e) {
            logger.error("Error processing SQS message: {}. Error: {}", messagePayload, e.getMessage(), e);
            // Rozważ DLQ
        }
    }
}