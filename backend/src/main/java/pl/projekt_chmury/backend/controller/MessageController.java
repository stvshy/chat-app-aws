package pl.projekt_chmury.backend.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import pl.projekt_chmury.backend.model.Message;
import pl.projekt_chmury.backend.model.User;
import pl.projekt_chmury.backend.repository.MessageRepository;
import pl.projekt_chmury.backend.repository.UserRepository;

import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/messages")
public class MessageController {
    private static final Logger logger = LoggerFactory.getLogger(MessageController.class);
    @Autowired
    private MessageRepository messageRepository;

    @Autowired
    private UserRepository userRepository;

    // Endpoint: wiadomości wysłane przez danego użytkownika
    @GetMapping("/sent")
    public List<Message> getSentMessages(@RequestParam String username) {
        logger.debug("getSentMessages called with username: {}", username);
        return messageRepository.findByAuthorUsername(username);
    }

    // Endpoint: wiadomości odebrane przez danego użytkownika
    @GetMapping("/received")
    public List<Message> getReceivedMessages(@RequestParam String username) {
        logger.debug("getReceivedMessages called with username: {}", username);
        return messageRepository.findByRecipientUsername(username);
    }

    // Endpoint tworzenia wiadomości
    // Oczekujemy JSON: {"author": "nadawcaUsername", "content": "treść", "recipient": "odbiorcaUsername"}
    @PostMapping
    public Message addMessage(@RequestBody Map<String, String> body) {
        String authorUsername = body.get("author");
        String content = body.get("content");
        String recipientUsername = body.get("recipient");

        logger.debug("Próba zapisu wiadomości. Nadawca: {}, treść: {}, odbiorca: {}",
                authorUsername, content, recipientUsername);

        User author = userRepository.findByUsername(authorUsername)
                .orElseThrow(() -> new RuntimeException("Sender not found"));

        User recipient = null;
        if (recipientUsername != null && !recipientUsername.isEmpty()) {
            recipient = userRepository.findByUsername(recipientUsername)
                    .orElseThrow(() -> new RuntimeException("Recipient not found"));
        }

        Message msg = new Message(author, content);
        msg.setRecipient(recipient);
        return messageRepository.save(msg);
    }

    // Endpoint do uploadu pliku (pozostaje bez zmian)
    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public String uploadFile(@RequestParam("file") MultipartFile file) throws IOException {
        File uploadsDir = new File("uploads");
        if (!uploadsDir.exists()) {
            uploadsDir.mkdir();
        }
        File destination = new File(uploadsDir, file.getOriginalFilename());
        file.transferTo(destination);
        return "Plik zapisany: " + destination.getAbsolutePath();
    }

    @PostMapping(value = "/with-file", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Message addMessageWithFile(
            @RequestParam("author") String author,
            @RequestParam("content") String content,
            @RequestParam(value = "recipient", required = false) String recipient,
            @RequestParam("file") MultipartFile file) throws IOException {

        // Pobierz nadawcę
        User authorUser = userRepository.findByUsername(author)
                .orElseThrow(() -> new RuntimeException("Sender not found"));

        // Pobierz odbiorcę, jeśli został podany
        User recipientUser = null;
        if (recipient != null && !recipient.isEmpty()) {
            recipientUser = userRepository.findByUsername(recipient)
                    .orElseThrow(() -> new RuntimeException("Recipient not found"));
        }

        // Używamy absolutnej ścieżki do katalogu uploads (np. "/uploads")
        String uploadDir = "/uploads";
        File uploadsDir = new File(uploadDir);
        if (!uploadsDir.exists()) {
            // Używamy mkdirs() – tworzy wszystkie brakujące katalogi
            uploadsDir.mkdirs();
        }

        // Używamy oryginalnej nazwy pliku – w produkcji warto generować unikalną nazwę
        String originalFilename = file.getOriginalFilename();
        File destination = new File(uploadsDir, originalFilename);
        file.transferTo(destination);

        // Tworzymy nową wiadomość i ustawiamy ścieżkę do pliku
        Message msg = new Message(authorUser, content);
        msg.setRecipient(recipientUser);
        msg.setFile(destination.getAbsolutePath());

        return messageRepository.save(msg);
    }


}
