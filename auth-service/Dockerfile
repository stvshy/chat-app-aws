# Użyj oficjalnego obrazu Java Runtime Environment (JRE) jako bazy.
# Wersja 17, Alpine Linux dla mniejszego rozmiaru obrazu.
FROM eclipse-temurin:17-jre-alpine

# Ustaw katalog roboczy wewnątrz kontenera.
# Wszystkie kolejne komendy będą wykonywane względem tego katalogu.
WORKDIR /app

# Skopiuj zbudowany plik .jar z katalogu target hosta
# do katalogu roboczego /app w kontenerze, zmieniając jego nazwę na app.jar.
# Użycie wzorca *.jar jest elastyczniejsze niż podawanie pełnej nazwy z wersją.
COPY target/*.jar app.jar

# Poinformuj Docker, że kontener będzie nasłuchiwał na tym porcie w czasie działania.
# Ten port powinien odpowiadać wartości server.port z application.properties.
# Ustawiliśmy go na 8081 dla auth-service.
EXPOSE 8081

# Zdefiniuj domyślne polecenie, które zostanie wykonane podczas uruchamiania kontenera.
# Uruchamia aplikację Spring Boot spakowaną w app.jar.
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
