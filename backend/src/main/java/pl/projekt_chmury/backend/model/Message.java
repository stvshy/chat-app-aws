package pl.projekt_chmury.backend.model;

import jakarta.persistence.*;

@Entity
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Zamiast relacji do User przechowujemy tylko nazwę użytkownika
    private String authorUsername;

    private String recipientUsername; // może być null dla broadcastu

    private String content;
    private String file;

    public Message() {}

    public Message(String authorUsername, String content) {
        this.authorUsername = authorUsername;
        this.content = content;
    }

    // Gettery i settery
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

    public String getFile() {
        return file;
    }
    public void setFile(String file) {
        this.file = file;
    }
}
