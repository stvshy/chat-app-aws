package pl.projektchmury.notificationservice.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

import java.net.URI;

@Configuration
public class DynamoDbConfig {

    @Value("${aws.region}")
    private String region;

    // Endpoint dla lokalnego DynamoDB (z docker-compose.yml)
    @Value("${aws.dynamodb.endpoint:#{null}}")
    private String dynamoDbEndpoint;

    // Klucze dla lokalnego DynamoDB (z docker-compose.yml lub .env)
    @Value("${aws.accessKeyId:#{null}}")
    private String accessKeyId;

    @Value("${aws.secretKey:#{null}}")
    private String secretKey;

    @Bean
    public DynamoDbClient dynamoDbClient() {
        DynamoDbClient client;
        if (dynamoDbEndpoint != null && !dynamoDbEndpoint.isEmpty()) {
            // Konfiguracja dla lokalnego endpointu
            client = DynamoDbClient.builder()
                    .region(Region.of(region))
                    .endpointOverride(URI.create(dynamoDbEndpoint))
                    // Użyj statycznych (dummy) credentials dla lokalnego endpointu
                    .credentialsProvider(StaticCredentialsProvider.create(
                            AwsBasicCredentials.create(accessKeyId, secretKey)))
                    .build();
        } else {
            // Standardowa konfiguracja dla AWS (użyje domyślnego providera)
            client = DynamoDbClient.builder()
                    .region(Region.of(region))
                    .credentialsProvider(DefaultCredentialsProvider.create())
                    .build();
        }
        return client;
    }

    @Bean
    public DynamoDbEnhancedClient dynamoDbEnhancedClient(DynamoDbClient dynamoDbClient) {
        // Tworzymy klienta Enhanced na bazie standardowego klienta
        return DynamoDbEnhancedClient.builder()
                .dynamoDbClient(dynamoDbClient)
                .build();
    }
}
