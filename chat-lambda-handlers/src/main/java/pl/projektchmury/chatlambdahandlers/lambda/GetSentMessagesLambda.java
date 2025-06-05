// chat-lambda-handlers/src/main/java/pl/projektchmury/chatapp/lambda/GetSentMessagesLambda.java
package pl.projektchmury.chatapp.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyRequestEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayProxyResponseEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule; // Dla serializacji LocalDateTime
import pl.projektchmury.chatapp.dao.MessageDao;
import pl.projektchmury.chatapp.model.Message;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;

public class GetSentMessagesLambda implements RequestHandler<APIGatewayProxyRequestEvent, APIGatewayProxyResponseEvent> {

    private final ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule()); // Dodaj JavaTimeModule
    private final MessageDao messageDao = new MessageDao();

    @Override
    public APIGatewayProxyResponseEvent handleRequest(APIGatewayProxyRequestEvent requestEvent, Context context) {
        APIGatewayProxyResponseEvent response = new APIGatewayProxyResponseEvent();
        // Ustawienie nagłówków CORS - ważne dla API Gateway
        Map<String, String> headers = Map.of(
                "Content-Type", "application/json",
                "Access-Control-Allow-Origin", "*", // W produkcji zawęź do domeny frontendu
                "Access-Control-Allow-Methods", "GET,OPTIONS",
                "Access-Control-Allow-Headers", "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token"
        );
        response.setHeaders(headers);


        try {
            // API Gateway przekazuje parametry zapytania w mapie
            Map<String, String> queryStringParameters = requestEvent.getQueryStringParameters();
            if (queryStringParameters == null || !queryStringParameters.containsKey("username")) {
                response.setStatusCode(400);
                response.setBody("{\"error\":\"Missing 'username' query parameter\"}");
                return response;
            }
            String username = queryStringParameters.get("username");

            // Walidacja autoryzacji - kto może pobrać czyje wiadomości?
            // API Gateway z autoryzatorem Cognito przekaże informacje o zalogowanym użytkowniku.
            // Możemy je odczytać z requestEvent.getRequestContext().getAuthorizer()
            // Na razie zakładamy, że frontend wysyła poprawny username zalogowanego użytkownika.
            // W bardziej zaawansowanym scenariuszu, powinniśmy pobrać 'username' z tokenu JWT.
            // String authenticatedUser = getAuthenticatedUser(requestEvent);
            // if (!username.equals(authenticatedUser)) {
            //     response.setStatusCode(403);
            //     response.setBody("{\"error\":\"Forbidden: You can only fetch your own sent messages.\"}");
            //     return response;
            // }


            List<Message> sentMessages = messageDao.findByAuthorUsername(username);

            response.setStatusCode(200);
            response.setBody(objectMapper.writeValueAsString(sentMessages));

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

    // Przykładowa metoda do pobierania użytkownika z kontekstu autoryzatora Cognito
    // (jeśli skonfigurowany w API Gateway)
    private String getAuthenticatedUser(APIGatewayProxyRequestEvent requestEvent) {
        if (requestEvent.getRequestContext() != null &&
                requestEvent.getRequestContext().getAuthorizer() != null &&
                // TUTAJ JEST KLUCZOWA ZMIANA: używamy .get("principalId") na mapie
                requestEvent.getRequestContext().getAuthorizer().get("principalId") != null) {

            // PrincipalId często jest to sub (subject) z tokenu Cognito.
            // Możesz też mieć inne claims, np. 'cognito:username'
            // @SuppressWarnings("unchecked")
            // Map<String, Object> claims = (Map<String, Object>) requestEvent.getRequestContext().getAuthorizer().get("claims");
            // if (claims != null && claims.containsKey("cognito:username")) {
            //    return (String) claims.get("cognito:username");
            // }

            // Pobieramy wartość klucza "principalId" z mapy authorizer
            return (String) requestEvent.getRequestContext().getAuthorizer().get("principalId");
        }
        return null; // Lub rzuć wyjątek, jeśli autoryzacja jest wymagana
    }
}