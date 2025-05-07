package pl.projektchmury.fileservice.repository;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;
import pl.projektchmury.fileservice.model.FileMetadata;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.services.dynamodb.model.DynamoDbException;

import java.util.Optional;

@Repository // Oznaczamy jako bean Springa
public class DynamoDbFileMetadataRepository implements FileMetadataRepository {

    private static final Logger logger = LoggerFactory.getLogger(DynamoDbFileMetadataRepository.class);
    private final DynamoDbTable<FileMetadata> metadataTable;

    @Autowired
    public DynamoDbFileMetadataRepository(DynamoDbEnhancedClient enhancedClient,
                                          @Value("${aws.dynamodb.table-name.file-metadata}") String tableName) {
        // Tworzymy obiekt tabeli na podstawie klasy modelu i nazwy tabeli
        this.metadataTable = enhancedClient.table(tableName, TableSchema.fromBean(FileMetadata.class));
    }

    @Override
    public FileMetadata save(FileMetadata metadata) {
        try {
            metadataTable.putItem(metadata);
            logger.info("Successfully saved metadata for fileId: {}", metadata.getFileId());
            return metadata;
        } catch (DynamoDbException e) {
            logger.error("Error saving metadata for fileId {}: {}", metadata.getFileId(), e.getMessage(), e);
            // Można rzucić własny wyjątek
            throw new RuntimeException("Error saving metadata to DynamoDB", e);
        }
    }

    @Override
    public Optional<FileMetadata> findById(String fileId) {
        try {
            FileMetadata metadata = metadataTable.getItem(Key.builder().partitionValue(fileId).build());
            logger.info("Found metadata for fileId: {}", fileId);
            return Optional.ofNullable(metadata);
        } catch (DynamoDbException e) {
            logger.error("Error finding metadata for fileId {}: {}", fileId, e.getMessage(), e);
            // Można rzucić własny wyjątek
            return Optional.empty();
        }
    }
}
