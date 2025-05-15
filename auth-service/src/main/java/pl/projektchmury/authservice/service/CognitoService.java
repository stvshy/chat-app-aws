// W pliku: auth-service/src/main/java/pl/projektchmury/authservice/service/CognitoService.java
package pl.projektchmury.authservice.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.cognitoidentityprovider.CognitoIdentityProviderClient;
import software.amazon.awssdk.services.cognitoidentityprovider.model.*;

import java.util.HashMap;
import java.util.Map;

@Service
public class CognitoService {

    @Value("${aws.cognito.region}")
    private String region;

    @Value("${aws.cognito.userPoolId}")
    private String userPoolId;

    @Value("${aws.cognito.clientId}")
    private String clientId;

    // Rejestracja (Sign Up)
    public SignUpResponse signUp(String username, String password) {
        try (CognitoIdentityProviderClient client = CognitoIdentityProviderClient.builder()
                .region(Region.of(region))
                .build()) {

            SignUpRequest signUpRequest = SignUpRequest.builder()
                    .clientId(clientId)
                    .username(username)
                    .password(password)
                    .build();

            return client.signUp(signUpRequest);
        }
    }

    // Logowanie przy użyciu flow USER_PASSWORD_AUTH
    public InitiateAuthResponse userLogin(String username, String password) {
        try (CognitoIdentityProviderClient client = CognitoIdentityProviderClient.builder()
                .region(Region.of(region))
                .build()) {

            Map<String, String> authParams = new HashMap<>();
            authParams.put("USERNAME", username);
            authParams.put("PASSWORD", password);

            InitiateAuthRequest authRequest = InitiateAuthRequest.builder()
                    .clientId(clientId)
                    .authFlow(AuthFlowType.USER_PASSWORD_AUTH)
                    .authParameters(authParams)
                    .build();

            InitiateAuthResponse response = client.initiateAuth(authRequest); // Tylko jedno wywołanie
            System.out.println(">>> Cognito response: " + response);

            // Dodaj sprawdzenie nulla dla bezpieczeństwa przed próbą dostępu do authenticationResult
            if (response.authenticationResult() != null) {
                System.out.println(">>> Access token: " + response.authenticationResult().accessToken());
                System.out.println(">>> ID token: " + response.authenticationResult().idToken());
            } else {
                System.out.println(">>> Cognito response did not contain authenticationResult.");
            }

            return response; // Zwróć już istniejącą odpowiedź
        }
    }
}
