package pl.projektchmury.notificationservice.repository;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;
import pl.projektchmury.notificationservice.model.NotificationRecord;
import software.amazon.awssdk.core.pagination.sync.SdkIterable;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.Page;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.DynamoDbException;

import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Repository
public class DynamoDbNotificationRepository implements NotificationRepository {

    private static final Logger logger = LoggerFactory.getLogger(DynamoDbNotificationRepository.class);
    private final DynamoDbTable<NotificationRecord> notificationTable;
    private final DynamoDbEnhancedClient enhancedClient; // Potrzebny do zapytań na indeksach

    // Nazwa indeksu GSI (jeśli go używasz)
    private static final String USER_ID_TIMESTAMP_INDEX = "userId-timestamp-index";

    @Autowired
    public DynamoDbNotificationRepository(DynamoDbEnhancedClient enhancedClient,
                                          @Value("${aws.dynamodb.table-name.notification-history}") String tableName) {
        this.enhancedClient = enhancedClient;
        this.notificationTable = enhancedClient.table(tableName, TableSchema.fromBean(NotificationRecord.class));
    }

    @Override
    public NotificationRecord save(NotificationRecord record) {
        try {
            notificationTable.putItem(record);
            logger.info("Successfully saved notification record: {}", record.getNotificationId());
            return record;
        } catch (DynamoDbException e) {
            logger.error("Error saving notification record {}: {}", record.getNotificationId(), e.getMessage(), e);
            throw new RuntimeException("Error saving notification record to DynamoDB", e);
        }
    }

    @Override
    public Optional<NotificationRecord> findById(String notificationId) {
        try {
            NotificationRecord record = notificationTable.getItem(Key.builder().partitionValue(notificationId).build());
            logger.info("Found notification record for id: {}", notificationId);
            return Optional.ofNullable(record);
        } catch (DynamoDbException e) {
            logger.error("Error finding notification record for id {}: {}", notificationId, e.getMessage(), e);
            return Optional.empty();
        }
    }

    @Override
    public List<NotificationRecord> findByUserIdOrderByTimestampDesc(String userId) {
        try {
            QueryConditional queryConditional = QueryConditional
                    .keyEqualTo(Key.builder().partitionValue(userId).build());

            QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                    .queryConditional(queryConditional)
                    .scanIndexForward(false) // Sortuj malejąco po kluczu sortowania (timestamp)
                    .build();

            // Wykonaj zapytanie na indeksie GSI
            SdkIterable<Page<NotificationRecord>> queryResult = enhancedClient
                    .table(notificationTable.tableName(), TableSchema.fromBean(NotificationRecord.class))
                    .index(USER_ID_TIMESTAMP_INDEX)
                    .query(request);

            // Zbierz wyniki ze wszystkich stron
            List<NotificationRecord> results = queryResult.stream() // Strumień stron (Page<NotificationRecord>)
                    .flatMap(page -> page.items().stream()) // Dla każdej strony, weź strumień jej elementów (NotificationRecord)
                    .collect(Collectors.toList()); // Zbierz wszystkie elementy do listy

            logger.info("Found {} notification records for userId: {}", results.size(), userId);
            return results;

        } catch (DynamoDbException e) {
            logger.error("Error finding notifications for userId {}: {}", userId, e.getMessage(), e);
            return Collections.emptyList();
        } catch (NullPointerException e) {
            logger.error("Error querying index '{}'. Does it exist?", USER_ID_TIMESTAMP_INDEX, e);
            return Collections.emptyList();
        }
    }
}
