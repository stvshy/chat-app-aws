package pl.projektchmury.fileservice.repository;

import pl.projektchmury.fileservice.model.FileMetadata;
import java.util.Optional;

// To jest definicja INTERFEJSU
public interface FileMetadataRepository {

    FileMetadata save(FileMetadata metadata);

    Optional<FileMetadata> findById(String fileId);

    // Możesz tu dodać inne potrzebne metody w przyszłości
}
