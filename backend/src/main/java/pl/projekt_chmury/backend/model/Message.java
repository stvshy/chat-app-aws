package pl.projekt_chmury.backend.model;

import jakarta.persistence.*;

@Entity
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Nadawca wiadomości
    @ManyToOne
    @JoinColumn(name = "author_id", nullable = false)
    private User author;

    // Odbiorca wiadomości – może być null (broadcast)
    @ManyToOne
    @JoinColumn(name = "recipient_id")
    private User recipient;

    private String content;

    public Message() {}

    private String file;

    public Message(User author, String content) {
        this.author = author;
        this.content = content;
    }

    // Gettery i settery

    public Long getId() {
        return id;
    }
    public void setId(Long id) { this.id = id; }

    public User getAuthor() {
        return author;
    }
    public void setAuthor(User author) {
        this.author = author;
    }

    public User getRecipient() {
        return recipient;
    }
    public void setRecipient(User recipient) {
        this.recipient = recipient;
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
