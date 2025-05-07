FROM eclipse-temurin:17-jre-alpine
# Używamy obrazu bazowego Alpine Linux z Eclipse Temurin JRE 17

COPY target/*.jar /app.jar
# Kopiujemy plik JAR (z katalogu target) do katalogu głównego kontenera jako app.jar

EXPOSE 8080
#  Kontener nasłuchuje na porcie 8080

ENTRYPOINT ["java", "-jar", "/app.jar"]
# Ustawiamy polecenie uruchomienia – start aplikacji poprzez wykonanie polecenia "java -jar /app.jar"
