package pl.projektchmury.notificationservice;

import org.springframework.boot.SpringApplication; // Główna klasa do uruchamiania aplikacji Spring Boot
import org.springframework.boot.autoconfigure.SpringBootApplication; // Kluczowa adnotacja, która włącza auto-konfigurację, skanowanie komponentów itp.
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.context.annotation.Bean;

@SpringBootApplication // Ta adnotacja to skrót dla kilku innych, w tym:
// @Configuration: Oznacza klasę jako źródło definicji beanów.
// @EnableAutoConfiguration: Mówi Spring Boot, aby spróbował automatycznie skonfigurować aplikację na podstawie zależności w classpath.
// @ComponentScan: Mówi Springowi, aby skanował pakiety (domyślnie ten, w którym jest ta klasa, i jego pod-pakiety)
//                w poszukiwaniu komponentów (@Service, @Repository, @Controller, @Configuration itp.).
public class NotificationServiceApplication {

    // Główna metoda main, punkt startowy aplikacji Java.
    public static void main(String[] args) {
        // Uruchom aplikację Spring Boot.
        // SpringApplication.run(...) tworzy kontekst aplikacji Springa, zarządza cyklem życia beanów
        // i uruchamia wbudowany serwer (np. Tomcat), jeśli to aplikacja webowa.
        SpringApplication.run(NotificationServiceApplication.class, args);
    }

    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper objectMapper = new ObjectMapper();
        objectMapper.registerModule(new JavaTimeModule()); // Dla obsługi Java Time API
        return objectMapper;
    }
}
