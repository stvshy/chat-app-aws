package pl.projektchmury.fileservice.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import pl.projektchmury.fileservice.model.FileMetadata;
import pl.projektchmury.fileservice.service.FileStorageService;
import pl.projektchmury.fileservice.service.S3Service;

import java.io.IOException;
import java.net.URI;

@RestController
@RequestMapping("/api/files")
public class FileController {

    private final FileStorageService fileStorageService;
    private final S3Service s3Service; // Potrzebne do generowania pre-signed URL

    @Autowired
    public FileController(FileStorageService fileStorageService, S3Service s3Service) {
        this.fileStorageService = fileStorageService;
        this.s3Service = s3Service;
    }

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<FileMetadata> uploadFile(
            @RequestParam("file") MultipartFile file,
            @AuthenticationPrincipal Jwt jwt // Pobierz zalogowanego użytkownika z tokenu JWT
    ) {
        if (jwt == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        String username = jwt.getSubject(); // Lub inny claim identyfikujący użytkownika, np. 'username'

        try {
            FileMetadata metadata = fileStorageService.storeFile(file, username);
            // Zwracamy całe metadane, w tym fileId, s3Key itp.
            // Klient użyje fileId do odwołań.
            return ResponseEntity.status(HttpStatus.CREATED).body(metadata);
        } catch (IOException e) {
            // Loguj błąd
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(null);
        }
    }

    @GetMapping("/download/{fileId}")
    public ResponseEntity<?> downloadFile(@PathVariable String fileId) {
        FileMetadata metadata = fileStorageService.getMetadata(fileId);

        if (metadata == null || metadata.getS3Key() == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body("File not found or S3 key missing.");
        }

        String presignedUrl = s3Service.generatePresignedUrl(metadata.getS3Key());

        return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create(presignedUrl))
                .build();
    }

    @GetMapping("/metadata/{fileId}")
    public ResponseEntity<FileMetadata> getFileMetadata(@PathVariable String fileId) {
        FileMetadata metadata = fileStorageService.getMetadata(fileId);
        if (metadata == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
        return ResponseEntity.ok(metadata);
    }
}
