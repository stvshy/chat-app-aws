package pl.projektchmury.chatservice.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import pl.projektchmury.chatservice.model.Message;
import pl.projektchmury.chatservice.repository.MessageRepository;

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
        String fileId = body.get("fileId");

        logger.debug("Próba zapisu wiadomości. Nadawca: {}, treść: {}, odbiorca: {}, fileId: {}",
                authorUsername, content, recipientUsername, fileId);

        Message msg = new Message(authorUsername, content);
        msg.setRecipientUsername(recipientUsername);
        if (fileId != null && !fileId.isEmpty()) {
            msg.setFileId(fileId);
        }
        return messageRepository.save(msg);
    }
}
