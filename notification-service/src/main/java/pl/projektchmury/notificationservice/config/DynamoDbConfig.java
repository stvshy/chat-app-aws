package pl.projektchmury.notificationservice.config;

import org.springframework.beans.factory.annotation.Value; // Do wstrzykiwania wartości z plików konfiguracyjnych
import org.springframework.context.annotation.Bean; // Oznacza, że metoda tworzy "bean" zarządzany przez Springa
import org.springframework.context.annotation.Configuration; // Oznacza, że ta klasa zawiera konfigurację beanów Springa
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials; // Do tworzenia prostych, statycznych poświadczeń (login/hasło)
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider; // Sposób na automatyczne pobranie poświadczeń AWS
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider; // Provider dla statycznych poświadczeń
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient; // "Ulepszony" klient DynamoDB, ułatwiający pracę z obiektami Java
import software.amazon.awssdk.regions.Region; // Do określenia regionu AWS
import software.amazon.awssdk.services.dynamodb.DynamoDbClient; // Podstawowy klient do interakcji z usługą AWS DynamoDB

import java.net.URI; // Do reprezentowania adresów URL, np. dla lokalnego endpointu DynamoDB

@Configuration // Mówi Springowi: "Ta klasa definiuje konfigurację dla połączenia z DynamoDB."
public class DynamoDbConfig {

    // Wstrzyknij wartość właściwości "aws.region" (np. "us-east-1").
    @Value("${aws.region}")
    private String region;

    // Wstrzyknij adres lokalnego endpointu DynamoDB. Jeśli nie ma, będzie null.
    // Używane do testów z lokalnym DynamoDB (np. z Docker Compose).
    @Value("${aws.dynamodb.endpoint:#{null}}")
    private String dynamoDbEndpoint;

    // Wstrzyknij klucz dostępu AWS. Jeśli nie ma, będzie null.
    // Używane głównie dla lokalnego DynamoDB, jeśli wymaga poświadczeń.
    // W AWS Fargate poświadczenia będą pobierane z roli IAM.
    @Value("${aws.accessKeyId:#{null}}")
    private String accessKeyId;

    // Wstrzyknij sekretny klucz dostępu AWS. Jeśli nie ma, będzie null.
    @Value("${aws.secretKey:#{null}}")
    private String secretKey;

    @Bean // Mówi Springowi: "Stwórz i zarządzaj obiektem DynamoDbClient."
    public DynamoDbClient dynamoDbClient() {
        DynamoDbClient client; // Zmienna na klienta DynamoDB.

        // Sprawdź, czy mamy zdefiniowany lokalny endpoint DynamoDB.
        if (dynamoDbEndpoint != null && !dynamoDbEndpoint.isEmpty()) {
            // Jeśli tak, konfigurujemy klienta do łączenia się z lokalnym DynamoDB.
            logger.info("Configuring DynamoDbClient to use local endpoint: {}", dynamoDbEndpoint); // Dodaj logowanie
            client = DynamoDbClient.builder() // Używamy budowniczego.
                    .region(Region.of(region)) // Ustaw region (ważne nawet dla lokalnego).
                    .endpointOverride(URI.create(dynamoDbEndpoint)) // Ustaw adres lokalnego DynamoDB.
                    // Dla lokalnego DynamoDB często używamy "dummy" (fałszywych) poświadczeń,
                    // bo lokalna instancja może ich nie wymagać lub akceptować dowolne.
                    .credentialsProvider(StaticCredentialsProvider.create(
                            AwsBasicCredentials.create(accessKeyId, secretKey))) // Użyj statycznych poświadczeń.
                    .build(); // Zbuduj klienta.
        } else {
            // Jeśli nie ma lokalnego endpointu, konfigurujemy klienta dla prawdziwego AWS DynamoDB.
            logger.info("Configuring DynamoDbClient for AWS region: {}", region); // Dodaj logowanie
            client = DynamoDbClient.builder()
                    .region(Region.of(region)) // Ustaw region AWS.
                    // DefaultCredentialsProvider automatycznie znajdzie poświadczenia AWS
                    // (np. z roli IAM zadania Fargate).
                    .credentialsProvider(DefaultCredentialsProvider.create())
                    .build(); // Zbuduj klienta.
        }
        return client; // Zwróć skonfigurowanego klienta.
    }

    @Bean // Mówi Springowi: "Stwórz i zarządzaj obiektem DynamoDbEnhancedClient."
    // Ten klient jest "nakładką" na standardowego klienta i ułatwia mapowanie
    // obiektów Java na elementy DynamoDB i odwrotnie.
    public DynamoDbEnhancedClient dynamoDbEnhancedClient(DynamoDbClient dynamoDbClient) {
        // Tworzymy "ulepszonego" klienta, przekazując mu standardowego klienta DynamoDB,
        // którego stworzyliśmy w metodzie dynamoDbClient() powyżej.
        // Spring automatycznie wstrzyknie tutaj ten standardowy klient.
        return DynamoDbEnhancedClient.builder()
                .dynamoDbClient(dynamoDbClient) // Podaj standardowego klienta.
                .build(); // Zbuduj ulepszonego klienta.
    }

    // Dodaj logger, jeśli go używasz w tej klasie
    private static final org.slf4j.Logger logger = org.slf4j.LoggerFactory.getLogger(DynamoDbConfig.class);
}
