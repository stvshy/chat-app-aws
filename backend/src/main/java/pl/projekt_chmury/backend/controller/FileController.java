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
import pl.projekt_chmury.backend.service.S3Service;

@RestController
@RequestMapping("/api/files")
public class FileController {

    private final MessageRepository messageRepository;
    private final S3Service s3Service;

    public FileController(MessageRepository messageRepository, S3Service s3Service) {
        this.messageRepository = messageRepository;
        this.s3Service = s3Service;
    }

    // Endpoint do pobierania pliku na podstawie ID wiadomości
    @GetMapping("/download/{id}")
    public ResponseEntity<?> downloadFile(@PathVariable Long id) {
        Message msg = messageRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Message not found"));

        if (msg.getFile() == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body("Brak pliku w wiadomości.");
        }

        // msg.getFile() zawiera teraz klucz pliku, np. "1672531234567-nazwa_pliku.jpg"
        String presignedUrl = s3Service.generatePresignedUrl(msg.getFile());

        return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create(presignedUrl))
                .build();
    }
}
