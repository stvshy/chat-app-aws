// chat-lambda-handlers/src/main/java/pl/projektchmury/chatapp/model/Message.java
package pl.projektchmury.chatapp.model;

public class Message {
    private Long id;
    private String authorUsername;
    private String recipientUsername;
    private String content;
    private String fileId;
    private boolean read = false;
    private java.time.LocalDateTime createdAt; // Dodajmy pole na czas utworzenia

    public Message() {}

    public Message(String authorUsername, String content) {
        this.authorUsername = authorUsername;
        this.content = content;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getAuthorUsername() { return authorUsername; }
    public void setAuthorUsername(String authorUsername) { this.authorUsername = authorUsername; }
    public String getRecipientUsername() { return recipientUsername; }
    public void setRecipientUsername(String recipientUsername) { this.recipientUsername = recipientUsername; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public String getFileId() { return fileId; }
    public void setFileId(String fileId) { this.fileId = fileId; }
    public boolean isRead() { return read; }
    public void setRead(boolean read) { this.read = read; }
    public java.time.LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(java.time.LocalDateTime createdAt) { this.createdAt = createdAt; }
}