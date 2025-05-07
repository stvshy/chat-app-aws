package pl.projektchmury.fileservice.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import pl.projektchmury.fileservice.model.FileMetadata;
import pl.projektchmury.fileservice.repository.FileMetadataRepository;
import java.io.IOException;
import java.util.UUID;

@Service
public class FileStorageService {

    private final S3Service s3Service;
    private final FileMetadataRepository metadataRepository; // Wstrzyknij repozytorium

    @Autowired
    public FileStorageService(S3Service s3Service, FileMetadataRepository metadataRepository) {
        this.s3Service = s3Service;
        this.metadataRepository = metadataRepository;
    }

    public FileMetadata storeFile(MultipartFile file, String uploaderUsername) throws IOException {
        String originalFilename = file.getOriginalFilename();
        String contentType = file.getContentType();
        long size = file.getSize();

        // 1. Upload pliku do S3 i pobierz klucz S3
        String s3Key = s3Service.uploadFile(file); // Ta metoda już generuje unikalny klucz

        // 2. Wygeneruj unikalne fileId
        String fileId = UUID.randomUUID().toString();

        // 3. Stwórz obiekt metadanych
        FileMetadata metadata = new FileMetadata();
        metadata.setFileId(fileId);
        metadata.setOriginalFilename(originalFilename);
        metadata.setContentType(contentType);
        metadata.setSize(size);
        metadata.setS3Key(s3Key);
        metadata.setUploaderUsername(uploaderUsername);
        metadata.setUploadTimestamp(System.currentTimeMillis());

        // 4. Zapisz metadane do bazy danych (DynamoDB)
        metadataRepository.save(metadata); // Implementacja repozytorium będzie to obsługiwać

        return metadata; // Zwróć pełne metadane, w tym fileId
    }

    public FileMetadata getMetadata(String fileId) {
        return metadataRepository.findById(fileId)
                .orElse(null); // Lub rzuć wyjątek, jeśli nie znaleziono
    }
}
