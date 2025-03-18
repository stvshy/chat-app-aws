package pl.projekt_chmury.backend.model;

import jakarta.persistence.*;

@Entity
public class Message {

    @Id
    @GeneratedValue
    private Long id;

    @ManyToOne
    @JoinColumn(name = "user_id")
    private User author;   // Pole typu User, a nie String

    private String content;

    // Konstruktor bezargumentowy dla JPA
    public Message() {}

    // Konstruktor przyjmujący obiekt User i content
    public Message(User author, String content) {
        this.author = author;
        this.content = content;
    }

    // gettery/settery

    public Long getId() {
        return id;
    }
    public void setId(Long id) {
        this.id = id;
    }

    public User getAuthor() {
        return author;
    }
    public void setAuthor(User author) {
        this.author = author;
    }

    public String getContent() {
        return content;
    }
    public void setContent(String content) {
        this.content = content;
    }
}
