package pl.projektchmury.notificationservice.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;
import software.amazon.awssdk.services.sns.model.PublishResponse;
import software.amazon.awssdk.services.sns.model.SnsException;

@Service
public class SnsService {

    private static final Logger logger = LoggerFactory.getLogger(SnsService.class);
    private final SnsClient snsClient;

    @Value("${aws.sns.topic.arn}")
    private String snsTopicArn;

    // Konstruktor wstrzykujący klienta SNS (utworzonego np. w konfiguracji)
    public SnsService(SnsClient snsClient) {
        this.snsClient = snsClient;
    }

    public String sendSnsNotification(String subject, String message) {
        logger.info("Sending SNS notification to topic {}: Subject='{}'", snsTopicArn, subject);
        try {
            PublishRequest request = PublishRequest.builder()
                    .message(message)
                    .subject(subject)
                    .topicArn(snsTopicArn)
                    .build();

            PublishResponse result = snsClient.publish(request);
            logger.info("SNS Notification sent. Message ID: {}", result.messageId());
            return result.messageId();
        } catch (SnsException e) {
            logger.error("Error sending SNS notification: {}", e.awsErrorDetails().errorMessage(), e);
            // Można rzucić własny wyjątek lub zwrócić null/pusty string
            return null;
        }
    }
}
