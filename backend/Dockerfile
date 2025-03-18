# Używamy obrazu Maven z JDK 17
FROM maven:3.9.9-eclipse-temurin-17


# Ustawiamy katalog roboczy w kontenerze
WORKDIR /app

# Skopiuj plik pom.xml oraz katalog .mvn (jeśli istnieje) – to pozwoli pobrać zależności
COPY pom.xml ./
COPY .mvn .mvn
COPY mvnw ./
# Pobieramy zależności – dzięki temu przy kolejnych buildach warstwa ta będzie cachowana
RUN mvn dependency:go-offline -B

# Skopiuj cały kod (bind mount w docker-compose nadpisze te pliki, ale przy buildzie potrzebne są przykładowe pliki)
COPY src src

# Uruchamiamy aplikację w trybie developerskim
CMD ["./mvnw", "spring-boot:run"]
