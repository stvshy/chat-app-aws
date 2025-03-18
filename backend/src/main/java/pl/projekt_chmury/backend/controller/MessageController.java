package pl.projekt_chmury.backend.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import pl.projekt_chmury.backend.model.Message;
import pl.projekt_chmury.backend.repository.MessageRepository;

import java.util.List;

@RestController
@RequestMapping("/api/messages")
public class MessageController {

    @Autowired
    private MessageRepository messageRepository;

    // GET: Pobierz wszystkie wiadomości
    @GetMapping
    public List<Message> getAllMessages() {
        return messageRepository.findAll();
    }

    // GET: Pobierz pojedynczą wiadomość po id
    @GetMapping("/{id}")
    public Message getMessageById(@PathVariable Long id) {
        return messageRepository.findById(id).orElse(null);
    }

    // POST: Utwórz nową wiadomość
    @PostMapping
    public Message createMessage(@RequestBody Message message) {
        return messageRepository.save(message);
    }

    // POST: Endpoint do "uploadu" plików (przykładowo, dummy)
    @PostMapping("/upload")
    public String uploadFile(@RequestParam("file") String fileData) {
        // W wersji docelowej ten endpoint będzie obsługiwał upload do S3
        return "File uploaded: " + fileData;
    }
}
