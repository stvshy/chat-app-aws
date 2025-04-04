package pl.projekt_chmury.backend.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import pl.projekt_chmury.backend.model.Message;
import pl.projekt_chmury.backend.repository.MessageRepository;
import pl.projekt_chmury.backend.service.S3Service;
import java.net.URI;
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
    private S3Service s3Service;

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
    @PostMapping
    public Message addMessage(@RequestBody Map<String, String> body) {
        String authorUsername = body.get("author");
        String content = body.get("content");
        String recipientUsername = body.get("recipient");

        logger.debug("Próba zapisu wiadomości. Nadawca: {}, treść: {}, odbiorca: {}",
                authorUsername, content, recipientUsername);

        Message msg = new Message(authorUsername, content);
        msg.setRecipientUsername(recipientUsername);
        return messageRepository.save(msg);
    }

    // Endpoint do uploadu pliku pozostaje bez zmian
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

    // Endpoint tworzenia wiadomości z plikiem
    @PostMapping(value = "/with-file", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Message addMessageWithFile(
            @RequestParam("author") String author,
            @RequestParam("content") String content,
            @RequestParam(value = "recipient", required = false) String recipient,
            @RequestParam("file") MultipartFile file
    ) throws IOException {
        // Wyślij plik do S3 i pobierz URL:
        String s3Url = s3Service.uploadFile(file);
        Message msg = new Message(author, content);
        msg.setRecipientUsername(recipient);
        msg.setFile(s3Url);
        return messageRepository.save(msg);
    }
}
