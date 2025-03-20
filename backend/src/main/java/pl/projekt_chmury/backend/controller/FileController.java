package pl.projekt_chmury.backend.controller;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pl.projekt_chmury.backend.model.Message;
import pl.projekt_chmury.backend.repository.MessageRepository;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Files;

@RestController
@RequestMapping("/api/files")
public class FileController {

    private final MessageRepository messageRepository;

    public FileController(MessageRepository messageRepository) {
        this.messageRepository = messageRepository;
    }

    // Endpoint do pobierania pliku na podstawie ID wiadomości
    @GetMapping("/download/{id}")
    public ResponseEntity<Resource> downloadFile(@PathVariable Long id) throws IOException {
        // Znajdujemy wiadomość po ID
        Message msg = messageRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Message not found"));

        // Pobieramy ścieżkę do pliku zapisanej w wiadomości
        String filePath = msg.getFile();
        if (filePath == null || filePath.isEmpty()) {
            throw new FileNotFoundException("Wiadomość nie ma dołączonego pliku.");
        }

        File file = new File(filePath);
        if (!file.exists()) {
            throw new FileNotFoundException("Plik nie istnieje: " + filePath);
        }

        // Wczytujemy plik jako tablicę bajtów
        ByteArrayResource resource = new ByteArrayResource(Files.readAllBytes(file.toPath()));

        // Ustawiamy nagłówki, aby przeglądarka pobrała plik
        return ResponseEntity.ok()
                .contentLength(file.length())
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + file.getName() + "\"")
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .body(resource);
    }
}
