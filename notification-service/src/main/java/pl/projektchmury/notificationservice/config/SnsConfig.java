// Konfigurator Klienta SNS
package pl.projektchmury.notificationservice.config;

import org.springframework.beans.factory.annotation.Value; // Do wstrzykiwania wartości z plików konfiguracyjnych (np. application.properties)
import org.springframework.context.annotation.Bean; // Oznacza, że metoda tworzy "bean" zarządzany przez Springa (obiekt, którym Spring może zarządzać i wstrzykiwać)
import org.springframework.context.annotation.Configuration; // Oznacza, że ta klasa zawiera konfigurację beanów Springa
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider; // Sposób na automatyczne pobranie poświadczeń AWS (np. z roli IAM na Fargate)
import software.amazon.awssdk.regions.Region; // Do określenia regionu AWS
import software.amazon.awssdk.services.sns.SnsClient; // Główny klient do interakcji z usługą AWS SNS

import java.net.URI; // Do reprezentowania adresów URL, np. dla lokalnego endpointu SNS

@Configuration // Mówi Springowi: "Hej, ta klasa zawiera definicje obiektów (beanów), którymi masz zarządzać"
public class SnsConfig {

    // Wstrzyknij wartość właściwości "aws.region" z pliku application.properties (lub zmiennej środowiskowej)
    // To będzie region AWS, w którym działa temat SNS, "us-east-1".
    @Value("${aws.region}")
    private String region;

    // Wstrzyknij wartość właściwości "aws.sns.endpoint".
    // Jeśli ta właściwość nie istnieje, użyj wartości null (dzięki `#{null}`).
    // To jest przydatne do testowania lokalnego z narzędziami takimi jak LocalStack,
    // które emulują usługi AWS na komputerze i mają własne adresy (endpointy).
    @Value("${aws.sns.endpoint:#{null}}")
    private String snsEndpoint;

    @Bean // Mówi Springowi: "Metoda snsClient() tworzy obiekt SnsClient, którym masz zarządzać."
    // Spring wywoła tę metodę raz, stworzy obiekt i będzie go wstrzykiwać tam, gdzie jest potrzebny (np. do SnsService).
    public SnsClient snsClient() {
        SnsClient snsClient; // Deklaracja zmiennej dla klienta SNS.

        // Sprawdź, czy mamy zdefiniowany lokalny endpoint SNS (np. dla LocalStack).
        if (snsEndpoint != null && !snsEndpoint.isEmpty()) {
            // Jeśli tak, konfigurujemy klienta SNS do łączenia się z tym lokalnym adresem.
            logger.info("Configuring SnsClient to use local endpoint: {}", snsEndpoint);
            snsClient = SnsClient.builder() // Używamy "budowniczego" (builder pattern) do stworzenia klienta.
                    .region(Region.of(region)) // Ustawiamy region AWS (nawet dla LocalStack jest to potrzebne).
                    .endpointOverride(URI.create(snsEndpoint)) // NADPISUJEMY standardowy adres AWS adresem lokalnym.
                    // Dla LocalStack często potrzebne są jakiekolwiek (nawet "dummy") poświadczenia,
                    // DefaultCredentialsProvider spróbuje je znaleźć w standardowych miejscach.
                    .credentialsProvider(DefaultCredentialsProvider.create())
                    .build(); // Zbuduj obiekt klienta SNS.
        } else {
            // Jeśli nie ma lokalnego endpointu, konfigurujemy klienta do łączenia się z prawdziwą usługą AWS SNS.
            logger.info("Configuring SnsClient for AWS region: {}", region);
            snsClient = SnsClient.builder()
                    .region(Region.of(region)) // Ustawiamy region AWS.
                    // DefaultCredentialsProvider automatycznie znajdzie poświadczenia AWS:
                    // - Na Fargate: z roli IAM przypisanej do zadania.
                    // - Lokalnie (jeśli masz skonfigurowane AWS CLI): z Twoich lokalnych poświadczeń.
                    .credentialsProvider(DefaultCredentialsProvider.create())
                    .build(); // Zbuduj obiekt klienta SNS.
        }
        return snsClient; // Zwróć skonfigurowanego klienta SNS, żeby Spring mógł nim zarządzać.
    }

    // Dodaj logger, jeśli go używasz w tej klasie (jak w przykładzie powyżej)
    private static final org.slf4j.Logger logger = org.slf4j.LoggerFactory.getLogger(SnsConfig.class);
}
