// chat-lambda-handlers/src/main/java/pl/projektchmury/chatapp/lambda/MarkMessageAsReadLambda.java
package pl.projektchmury.chatapp.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import pl.projektchmury.chatapp.dao.MessageDao;
import pl.projektchmury.chatapp.model.Message;

import java.sql.SQLException;
import java.util.Map;

public class MarkMessageAsReadLambda implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private final ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());
    private final MessageDao messageDao = new MessageDao();

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent requestEvent, Context context) {
        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent();
        Map<String, String> headers = Map.of(
                "Content-Type", "application/json",
                "Access-Control-Allow-Origin", "*",
                "Access-Control-Allow-Methods", "POST,OPTIONS", // Zmieniono na POST
                "Access-Control-Allow-Headers", "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
        );
        response.setHeaders(headers);

        try {
            Map<String, String> pathParameters = requestEvent.getPathParameters();
            if (pathParameters == null || !pathParameters.containsKey("messageId")) {
                response.setStatusCode(400);
                response.setBody("{\"error\":\"Missing 'messageId' path parameter\"}");
                return response;
            }
            Long messageId;
            try {
                messageId = Long.parseLong(pathParameters.get("messageId"));
            } catch (NumberFormatException e) {
                response.setStatusCode(400);
                response.setBody("{\"error\":\"Invalid 'messageId' format\"}");
                return response;
            }

            // Pobierz zalogowanego użytkownika z kontekstu autoryzatora Cognito
            // To jest kluczowe dla bezpieczeństwa tej operacji
            String authenticatedUser = getAuthenticatedUsername(requestEvent, context);
            if (authenticatedUser == null) {
                response.setStatusCode(401); // Unauthorized
                response.setBody("{\"error\":\"User not authenticated\"}");
                return response;
            }

            boolean success = messageDao.markMessageAsRead(messageId, authenticatedUser);

            if (success) {
                // Opcjonalnie: pobierz zaktualizowaną wiadomość i zwróć ją
                Message updatedMessage = messageDao.findById(messageId);
                if (updatedMessage != null) {
                    response.setStatusCode(200);
                    response.setBody(objectMapper.writeValueAsString(updatedMessage));
                } else {
                    // To nie powinno się zdarzyć, jeśli update się powiódł
                    response.setStatusCode(200); // Lub 204 No Content
                    response.setBody("{\"message\":\"Message marked as read, but could not retrieve updated record.\"}");
                }
            } else {
                // Sprawdź, czy wiadomość istnieje, aby dać lepszy feedback
                Message existingMessage = messageDao.findById(messageId);
                if (existingMessage == null) {
                    response.setStatusCode(404); // Not Found
                    response.setBody("{\"error\":\"Message not found\"}");
                } else if (!authenticatedUser.equals(existingMessage.getRecipientUsername())) {
                    response.setStatusCode(403); // Forbidden
                    response.setBody("{\"error\":\"Forbidden: You can only mark your own messages as read.\"}");
                } else if (existingMessage.isRead()) {
                    response.setStatusCode(200); // OK, już była przeczytana
                    response.setBody(objectMapper.writeValueAsString(existingMessage));
                }
                else {
                    // Inny błąd, np. problem z bazą, który nie rzucił SQLException
                    response.setStatusCode(500);
                    response.setBody("{\"error\":\"Failed to mark message as read\"}");
                }
            }

        } catch (SQLException e) {
            context.getLogger().log("Database error: " + e.getMessage());
            response.setStatusCode(500);
            response.setBody("{\"error\":\"Database error: " + e.getMessage().replace("\"", "'") + "\"}");
        } catch (Exception e) {
            context.getLogger().log("Unexpected error: " + e.getMessage());
            response.setStatusCode(500);
            response.setBody("{\"error\":\"Unexpected error: " + e.getMessage().replace("\"", "'") + "\"}");
        }

        return response;
    }

    private String getAuthenticatedUsername(APIGatewayProxyRequestEvent requestEvent, Context context) {
        // API Gateway z autoryzatorem Cognito przekazuje informacje o użytkowniku
        // w requestEvent.getRequestContext().getAuthorizer().getClaims()
        // Klucz dla nazwy użytkownika to często "cognito:username" lub "username"
        try {
            if (requestEvent.getRequestContext() != null &&
                    requestEvent.getRequestContext().getAuthorizer() != null) {

                @SuppressWarnings("unchecked") // Tłumienie ostrzeżenia o rzutowaniu
                Map<String, Object> claims = (Map<String, Object>) requestEvent.getRequestContext().getAuthorizer().get("claims");

                if (claims != null) {
                    if (claims.containsKey("username")) {
                        return (String) claims.get("username");
                    } else if (claims.containsKey("cognito:username")) {
                        return (String) claims.get("cognito:username");
                    }
                }
                // Jeśli nie ma claimów, można spróbować principalId, ale to zwykle 'sub'
                // String principalId = (String) requestEvent.getRequestContext().getAuthorizer().getPrincipalId();
                // if (principalId != null) return principalId; // To będzie 'sub', niekoniecznie username
            }
        } catch (Exception e) {
            context.getLogger().log("Error extracting username from token claims: " + e.getMessage());
        }
        context.getLogger().log("Could not extract username from JWT claims. Authorizer context: " +
                (requestEvent.getRequestContext() != null ? requestEvent.getRequestContext().getAuthorizer() : "null"));
        return null;
    }
}