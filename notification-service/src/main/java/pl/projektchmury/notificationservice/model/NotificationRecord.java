package pl.projektchmury.notificationservice.model;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey; // IMPORTUJ
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;     // IMPORTUJ

// import java.time.Instant; // Nie jest już bezpośrednio potrzebny, jeśli timestamp to long

@DynamoDbBean
public class NotificationRecord {

    private String notificationId;
    private String userId; // Nick użytkownika
    private String type;
    private String message;
    private long timestamp;
    private String status;
    private boolean readNotification = false;
    private String relatedEntityId;

    @DynamoDbPartitionKey
    public String getNotificationId() {
        return notificationId;
    }
    public void setNotificationId(String notificationId) {
        this.notificationId = notificationId;
    }

    // Adnotacje dla Global Secondary Index (GSI)
    @DynamoDbSecondaryPartitionKey(indexNames = "userId-timestamp-index")
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

    @DynamoDbSecondarySortKey(indexNames = "userId-timestamp-index")
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

    public boolean isReadNotification() {
        return readNotification;
    }
    public void setReadNotification(boolean readNotification) {
        this.readNotification = readNotification;
    }

    public String getRelatedEntityId() {
        return relatedEntityId;
    }
    public void setRelatedEntityId(String relatedEntityId) {
        this.relatedEntityId = relatedEntityId;
    }
}
