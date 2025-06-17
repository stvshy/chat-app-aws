// chat-lambda-handlers/src/main/java/pl/projektchmury/chatapp/lambda/SendMessageLambda.java
package pl.projektchmury.chatapp.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import pl.projektchmury.chatapp.dao.MessageDao;
import pl.projektchmury.chatapp.dto.SendMessageRequest;
import pl.projektchmury.chatapp.model.Message;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SqsException;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

public class SendMessageLambda implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private final ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());
    private final MessageDao messageDao = new MessageDao();
    private final SqsClient sqsClient;
    private final String queueUrl;

    public SendMessageLambda() {
        // Inicjalizacja klienta SQS. Region i URL kolejki powinny być odczytywane ze zmiennych środowiskowych.
        String awsRegion = System.getenv("AWS_REGION_ENV"); // Ustawimy to w Terraformie
        if (awsRegion == null || awsRegion.trim().isEmpty()) {
            // Fallback lub rzucenie wyjątku, jeśli zmienna nie jest ustawiona
            awsRegion = "us-east-1";
            System.err.println("Warning: AWS_REGION_ENV not set, using default: " + awsRegion);
        }
        this.sqsClient = SqsClient.builder()
                .region(Region.of(awsRegion))
                .build();
        this.queueUrl = System.getenv("SQS_QUEUE_URL"); // Ustawimy to w Terraformie
        if (this.queueUrl == null || this.queueUrl.trim().isEmpty()) {
            System.err.println("FATAL: SQS_QUEUE_URL environment variable is not set.");
        }
    }

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent requestEvent, Context context) {
        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent();
        response.setHeaders(Map.of("Content-Type", "application/json", "Access-Control-Allow-Origin", "*"));

        try {
            String requestBody = requestEvent.getBody();
            SendMessageRequest sendMessageDto = objectMapper.readValue(requestBody, SendMessageRequest.class);

            Message message = new Message();
            message.setAuthorUsername(sendMessageDto.getAuthor());
            message.setContent(sendMessageDto.getContent());
            message.setRecipientUsername(sendMessageDto.getRecipient());
            message.setFileId(sendMessageDto.getFileId());
            message.setRead(false);

            Message savedMessage = messageDao.saveMessage(message);

            // Po pomyślnym zapisaniu wiadomości, wyślij powiadomienie do SQS
            if (savedMessage.getRecipientUsername() != null &&
                    !savedMessage.getRecipientUsername().isEmpty() &&
                    !savedMessage.getRecipientUsername().equals(savedMessage.getAuthorUsername())) {

                if (this.queueUrl == null) {
                    System.err.println("SQS Queue URL is not configured. Cannot send notification.");
                } else {
                    sendSqsNotification(savedMessage);
                }
            }

            response.setStatusCode(201); // Created
            response.setBody(objectMapper.writeValueAsString(savedMessage));

        } catch (JsonProcessingException e) {
            context.getLogger().log("Error deserializing request: " + e.getMessage());
            response.setStatusCode(400);
            response.setBody("{\"error\":\"Invalid request body: " + e.getMessage().replace("\"", "'") + "\"}");
        } catch (SQLException e) {
            context.getLogger().log("Database error: " + e.getMessage());
            response.setStatusCode(500);
            response.setBody("{\"error\":\"Database error: " + e.getMessage().replace("\"", "'") + "\"}");
        } catch (SqsException e) {
            context.getLogger().log("SQS error: " + e.getMessage());
            // Wiadomość została zapisana, ale powiadomienie SQS nie wyszło.
            // Można to zalogować, ale niekoniecznie zwracać błąd klientowi, bo główna operacja się udała.
            response.setStatusCode(201); // Nadal zwracamy sukces, bo wiadomość jest w bazie
            try {
                // Zwracamy zapisaną wiadomość, mimo błędu SQS
                response.setBody(objectMapper.writeValueAsString(objectMapper.readValue(response.getBody(), Message.class)));
            } catch (Exception ex) {
                response.setBody("{\"message\":\"Message saved, but notification could not be sent to SQS.\"}");
            }
            System.err.println("Failed to send SQS notification for message ID " + (response.getBody() != null ? response.getBody() : "N/A") + ": " + e.getMessage());
        } catch (Exception e) {
            context.getLogger().log("Unexpected error: " + e.getMessage());
            response.setStatusCode(500);
            response.setBody("{\"error\":\"Unexpected error: " + e.getMessage().replace("\"", "'") + "\"}");
        }
        return response;
    }

    private void sendSqsNotification(Message savedMessage) throws JsonProcessingException {
        Map<String, String> notificationPayload = new HashMap<>();
        notificationPayload.put("targetUserId", savedMessage.getRecipientUsername());
        notificationPayload.put("type", (savedMessage.getFileId() != null && !savedMessage.getFileId().isEmpty()) ? "NEW_MESSAGE_WITH_FILE" : "NEW_MESSAGE");

        String subject = "Nowa wiadomość od " + savedMessage.getAuthorUsername();
        String messageContentPreview = savedMessage.getContent();
        String notificationMessageBody = savedMessage.getAuthorUsername() + " wysłał Ci wiadomość" +
                ((savedMessage.getFileId() != null && !savedMessage.getFileId().isEmpty()) ? " z plikiem: \"" : ": \"") +
                (messageContentPreview.length() > 30 ? messageContentPreview.substring(0, 27) + "..." : messageContentPreview) +
                "\"";

        notificationPayload.put("subject", subject);
        notificationPayload.put("message", notificationMessageBody);
        if (savedMessage.getId() != null) {
            notificationPayload.put("relatedEntityId", savedMessage.getId().toString());
        }
        notificationPayload.put("senderUsername", savedMessage.getAuthorUsername());


        String messageBodyJson = objectMapper.writeValueAsString(notificationPayload);

        software.amazon.awssdk.services.sqs.model.SendMessageRequest sqsRequest = software.amazon.awssdk.services.sqs.model.SendMessageRequest.builder()
                .queueUrl(this.queueUrl)
                .messageBody(messageBodyJson)
                .build();

        System.out.println("Sending message to SQS. Queue: " + this.queueUrl + ", Body: " + messageBodyJson);
        sqsClient.sendMessage(sqsRequest);
        System.out.println("Message sent to SQS successfully for recipient: " + savedMessage.getRecipientUsername());
    }
}