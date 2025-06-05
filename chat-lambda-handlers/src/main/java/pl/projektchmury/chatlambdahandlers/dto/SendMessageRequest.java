// chat-lambda-handlers/src/main/java/pl/projektchmury/chatapp/dto/SendMessageRequest.java
package pl.projektchmury.chatapp.dto;

public class SendMessageRequest {
    private String author; // Zgodnie z tym, co wysyła frontend
    private String content;
    private String recipient;
    private String fileId;

    // Gettery i Settery
    public String getAuthor() { return author; }
    public void setAuthor(String author) { this.author = author; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public String getRecipient() { return recipient; }
    public void setRecipient(String recipient) { this.recipient = recipient; }
    public String getFileId() { return fileId; }
    public void setFileId(String fileId) { this.fileId = fileId; }
}