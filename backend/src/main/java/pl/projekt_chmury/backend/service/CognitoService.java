package pl.projekt_chmury.backend.service;

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
        // Tworzymy klienta v2
        try (CognitoIdentityProviderClient client = CognitoIdentityProviderClient.builder()
                .region(Region.of(region))
                .build()) {

            SignUpRequest signUpRequest = SignUpRequest.builder()
                    .clientId(clientId)
                    .username(username)
                    .password(password)
                    .build();

            // Jeśli chcesz przesyłać dodatkowe atrybuty, np. email, zrób:
            // signUpRequest = signUpRequest.toBuilder()
            //     .userAttributes(
            //         AttributeType.builder().name("email").value("example@example.com").build()
            //     )
            //     .build();

            return client.signUp(signUpRequest);
        }
    }

    // Logowanie (Admin Initiate Auth)
    // Wymaga włączenia ADMIN_NO_SRP_AUTH lub ADMIN_USER_PASSWORD_AUTH w App Client
    public AdminInitiateAuthResponse adminLogin(String username, String password) {
        try (CognitoIdentityProviderClient client = CognitoIdentityProviderClient.builder()
                .region(Region.of(region))
                .build()) {

            // Tworzymy mapę parametrów logowania
            Map<String, String> authParams = new HashMap<>();
            authParams.put("USERNAME", username);
            authParams.put("PASSWORD", password);

            AdminInitiateAuthRequest authRequest = AdminInitiateAuthRequest.builder()
                    .userPoolId(userPoolId)
                    .clientId(clientId)
                    .authFlow(AuthFlowType.ADMIN_NO_SRP_AUTH) // lub ADMIN_USER_PASSWORD_AUTH
                    .authParameters(authParams)
                    .build();

            return client.adminInitiateAuth(authRequest);
        }
    }
}
