package pl.projektchmury.fileservice.model;

// Adnotacje DynamoDB, jeśli będziesz używał Spring Data DynamoDB
// import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
// import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;

@DynamoDbBean
public class FileMetadata {

    private String fileId; // UUID
    private String originalFilename;
    private String contentType;
    private long size;
    private String s3Key; // Klucz obiektu w S3
    private String uploaderUsername; // Nazwa użytkownika, który wgrał plik
    private long uploadTimestamp; // Timestamp wgrania

    // Konstruktory, gettery, settery (możesz użyć Lombok)

    @DynamoDbPartitionKey // Oznacz fileId jako klucz partycji
    public String getFileId() {
        return fileId;
    }

    public void setFileId(String fileId) {
        this.fileId = fileId;
    }

    public String getOriginalFilename() {
        return originalFilename;
    }

    public void setOriginalFilename(String originalFilename) {
        this.originalFilename = originalFilename;
    }

    public String getContentType() {
        return contentType;
    }

    public void setContentType(String contentType) {
        this.contentType = contentType;
    }

    public long getSize() {
        return size;
    }

    public void setSize(long size) {
        this.size = size;
    }

    public String getS3Key() {
        return s3Key;
    }

    public void setS3Key(String s3Key) {
        this.s3Key = s3Key;
    }

    public String getUploaderUsername() {
        return uploaderUsername;
    }

    public void setUploaderUsername(String uploaderUsername) {
        this.uploaderUsername = uploaderUsername;
    }

    public long getUploadTimestamp() {
        return uploadTimestamp;
    }

    public void setUploadTimestamp(long uploadTimestamp) {
        this.uploadTimestamp = uploadTimestamp;
    }
}
