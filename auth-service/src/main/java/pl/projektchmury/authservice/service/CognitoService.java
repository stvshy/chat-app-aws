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

            InitiateAuthResponse response = client.initiateAuth(authRequest);
            System.out.println(">>> Cognito response: " + response);
            System.out.println(">>> Access token: " + response.authenticationResult().accessToken());
            System.out.println(">>> ID token: " + response.authenticationResult().idToken());

            return client.initiateAuth(authRequest);
        }
    }
}
