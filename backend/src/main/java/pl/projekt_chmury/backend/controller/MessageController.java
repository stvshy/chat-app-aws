package pl.projekt_chmury.backend.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import pl.projekt_chmury.backend.model.Message;
import pl.projekt_chmury.backend.repository.MessageRepository;

import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/messages")
public class MessageController {

    @Autowired
    private MessageRepository messageRepository;

    // 1. GET - wszystkie wiadomości
    @GetMapping
    public List<Message> getAllMessages() {
        return messageRepository.findAll();
    }

    // 2. GET - pojedyncza wiadomość
    @GetMapping("/{id}")
    public Optional<Message> getMessageById(@PathVariable Long id) {
        return messageRepository.findById(id);
    }

    // 3. POST - dodawanie wiadomości
    @PostMapping
    public Message addMessage(@RequestBody Message newMsg) {
        return messageRepository.save(newMsg);
    }

    // 4. POST - upload pliku (zapis lokalny w folderze "uploads/")
    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public String uploadFile(@RequestParam("file") MultipartFile file) throws IOException {
        // Na potrzeby lokalnych testów zapisz plik do folderu "uploads"
        File uploadsDir = new File("uploads");
        if (!uploadsDir.exists()) {
            uploadsDir.mkdir();
        }
        File destination = new File(uploadsDir, file.getOriginalFilename());
        file.transferTo(destination);

        return "Plik zapisany: " + destination.getAbsolutePath();
    }
}
