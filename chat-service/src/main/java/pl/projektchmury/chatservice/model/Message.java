package pl.projektchmury.chatservice.model;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;

@Entity
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String authorUsername;
    private String recipientUsername;

    private String content;
    private String fileId; // Identyfikator pliku zarządzanego przez FileService

    public Message() {}

    public Message(String authorUsername, String content) {
        this.authorUsername = authorUsername;
        this.content = content;
    }

    public Long getId() {
        return id;
    }
    public void setId(Long id) { this.id = id; }

    public String getAuthorUsername() {
        return authorUsername;
    }
    public void setAuthorUsername(String authorUsername) {
        this.authorUsername = authorUsername;
    }

    public String getRecipientUsername() {
        return recipientUsername;
    }
    public void setRecipientUsername(String recipientUsername) {
        this.recipientUsername = recipientUsername;
    }

    public String getContent() {
        return content;
    }
    public void setContent(String content) {
        this.content = content;
    }

    public String getFileId() {
        return fileId;
    }
    public void setFileId(String fileId) {
        this.fileId = fileId;
    }
}
