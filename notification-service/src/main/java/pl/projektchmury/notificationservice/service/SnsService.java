// Wysyłacz Wiadomości
package pl.projektchmury.notificationservice.service;

import org.slf4j.Logger; // Do logowania zdarzeń i błędów
import org.slf4j.LoggerFactory; // Do tworzenia instancji Loggera
import org.springframework.beans.factory.annotation.Value; // Do wstrzykiwania wartości z plików konfiguracyjnych
import org.springframework.stereotype.Service; // Oznacza, że ta klasa jest "serwisem" w logice biznesowej Springa
import software.amazon.awssdk.regions.Region; // Nie jest tu bezpośrednio używane, ale SnsClient go potrzebuje
import software.amazon.awssdk.services.sns.SnsClient; // Klient do interakcji z AWS SNS
import software.amazon.awssdk.services.sns.model.PublishRequest; // Obiekt reprezentujący żądanie publikacji wiadomości do SNS
import software.amazon.awssdk.services.sns.model.PublishResponse; // Obiekt reprezentujący odpowiedź od SNS po publikacji
import software.amazon.awssdk.services.sns.model.SnsException; // Wyjątek specyficzny dla operacji SNS

@Service // Mówi Springowi: "To jest komponent serwisowy, zarządzaj nim i wstrzykuj tam, gdzie potrzeba."
public class SnsService {

    // Tworzymy logger, żeby móc zapisywać informacje o działaniu tej klasy.
    private static final Logger logger = LoggerFactory.getLogger(SnsService.class);

    // Prywatne, finalne pole na klienta SNS. `final` oznacza, że musi być zainicjowane w konstruktorze i nie może być później zmienione.
    private final SnsClient snsClient;

    // Wstrzyknij wartość właściwości "aws.sns.topic.arn" z pliku application.properties (lub zmiennej środowiskowej).
    // To jest unikalny adres (ARN) tematu SNS, do którego będziemy wysyłać wiadomości.
    @Value("${aws.sns.topic.arn}")
    private String snsTopicArn;

    // Konstruktor. Spring użyje go do stworzenia instancji SnsService.
    // `@Autowired` nie jest tu potrzebne, jeśli jest tylko jeden konstruktor, Spring sam sobie poradzi.
    // Spring automatycznie wstrzyknie tutaj obiekt SnsClient, który został stworzony przez metodę snsClient() w klasie SnsConfig.
    public SnsService(SnsClient snsClient) {
        this.snsClient = snsClient; // Przypisz wstrzykniętego klienta SNS do pola w tej klasie.
    }

    // Metoda do wysyłania powiadomienia SNS.
    // Przyjmuje temat (subject) i treść (message) wiadomości.
    // Zwraca ID opublikowanej wiadomości SNS lub null w przypadku błędu.
    public String sendSnsNotification(String subject, String message) {
        // Zapisz w logach informację, że próbujemy wysłać powiadomienie.
        // Używamy placeholderów `{}` dla wartości
        logger.info("Sending SNS notification to topic {}: Subject='{}'", snsTopicArn, subject);
        try {
            // Stwórz obiekt żądania publikacji (PublishRequest) za pomocą budowniczego.
            PublishRequest request = PublishRequest.builder()
                    .message(message)       // Ustaw treść wiadomości.
                    .subject(subject)       // Ustaw temat wiadomości (przydatny np. dla subskrypcji e-mail).
                    .topicArn(snsTopicArn)  // Ustaw ARN tematu SNS, do którego publikujemy.
                    .build();               // Zbuduj obiekt żądania.

            // Wyślij żądanie publikacji do AWS SNS używając skonfigurowanego klienta.
            // Ta operacja jest synchroniczna - czekamy na odpowiedź od AWS.
            PublishResponse result = snsClient.publish(request);

            // Jeśli publikacja się udała, zapisz w logach ID wysłanej wiadomości.
            logger.info("SNS Notification sent. Message ID: {}", result.messageId());

            // Zwróć ID opublikowanej wiadomości. Może być przydatne do śledzenia.
            return result.messageId();
        } catch (SnsException e) { // Złap wyjątek, jeśli coś poszło nie tak podczas komunikacji z SNS.
            // Zapisz w logach szczegółowy błąd z AWS.
            // `e.awsErrorDetails().errorMessage()` daje bardziej czytelny komunikat błędu od AWS.
            // `e` jako ostatni argument loggera spowoduje wydrukowanie pełnego stack trace'u wyjątku.
            logger.error("Error sending SNS notification: {}", e.awsErrorDetails().errorMessage(), e);

            // W przypadku błędu, zwróć null
            return null;
        }
    }
}
