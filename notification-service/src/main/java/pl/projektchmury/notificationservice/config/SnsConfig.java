package pl.projektchmury.notificationservice.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sns.SnsClient;

import java.net.URI;

@Configuration
public class SnsConfig {

    @Value("${aws.region}")
    private String region;

    // Opcjonalny endpoint dla lokalnego testowania (np. z LocalStack)
    @Value("${aws.sns.endpoint:#{null}}")
    private String snsEndpoint;

    @Bean
    public SnsClient snsClient() {
        SnsClient snsClient;
        if (snsEndpoint != null && !snsEndpoint.isEmpty()) {
            // Konfiguracja dla lokalnego endpointu (np. LocalStack)
            snsClient = SnsClient.builder()
                    .region(Region.of(region))
                    .endpointOverride(URI.create(snsEndpoint))
                    // Dla LocalStack często potrzebne są dummy credentials
                    .credentialsProvider(DefaultCredentialsProvider.create())
                    .build();
        } else {
            // Standardowa konfiguracja dla AWS
            snsClient = SnsClient.builder()
                    .region(Region.of(region))
                    .credentialsProvider(DefaultCredentialsProvider.create())
                    .build();
        }
        return snsClient;
    }
}
