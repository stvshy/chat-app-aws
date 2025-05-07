package pl.projektchmury.notificationservice.model;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
// Importuj adnotacje dla kluczy sortowania i indeksów, jeśli ich używasz
// import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey;
// import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;

import java.time.Instant;

@DynamoDbBean
public class NotificationRecord {

    private String notificationId; // UUID
    private String userId; // Identyfikator użytkownika (np. subject z JWT)
    private String type; // Typ powiadomienia (np. "NEW_MESSAGE", "FILE_UPLOADED")
    private String message; // Treść powiadomienia
    private long timestamp; // Timestamp wysłania (epoch millis)
    private String status; // Status (np. "SENT", "FAILED")

    // Konstruktory, gettery, settery (możesz użyć Lombok)

    @DynamoDbPartitionKey
    public String getNotificationId() {
        return notificationId;
    }

    public void setNotificationId(String notificationId) {
        this.notificationId = notificationId;
    }

    // Można dodać indeks GSI na userId i timestamp dla łatwego pobierania historii
    // @DynamoDbSecondaryPartitionKey(indexNames = "userId-timestamp-index")
    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    // @DynamoDbSecondarySortKey(indexNames = "userId-timestamp-index")
    public long getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}
