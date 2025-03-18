# Używamy obrazu OpenJDK 17 – idealnego do uruchamiania aplikacji Spring Boot
FROM openjdk:17

# Ustawiamy katalog roboczy wewnątrz kontenera
WORKDIR /app

# Kopiujemy gotowy plik JAR (upewnij się, że plik został zbudowany w folderze target)
COPY target/backend-0.0.1-SNAPSHOT.jar app.jar

# Uruchamiamy aplikację Spring Boot
ENTRYPOINT ["java", "-jar", "app.jar"]
