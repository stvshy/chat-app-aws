package pl.projekt_chmury.backend.controller;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import pl.projekt_chmury.backend.model.Message;
import pl.projekt_chmury.backend.repository.MessageRepository;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.net.URI;
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
        Message msg = messageRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Message not found"));

        if (msg.getFile() == null) {
            throw new FileNotFoundException("Brak pliku w wiadomości.");
        }

        // Tu pobierasz obiekt z S3:
        // np. s3Client.getObject(GetObjectRequest.builder().bucket(bucketName).key(fileKey).build())
        // i tworzysz ByteArrayResource, podobnie jak w Twoim obecnym kodzie.

        // Dla uproszczenia: jeśli msg.getFile() = "https://bucket.s3.amazonaws.com/fileName"
        // możesz zrobić redirect 302:
        return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create(msg.getFile()))
                .build();
    }

}
