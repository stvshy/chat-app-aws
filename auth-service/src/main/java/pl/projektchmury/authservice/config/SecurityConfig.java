// Przykład dla auth-service/src/main/java/pl/projektchmury/authservice/config/SecurityConfig.java

package pl.projektchmury.authservice.config;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

@EnableWebSecurity
@Configuration
public class SecurityConfig {

    @Value("${spring.security.oauth2.resourceserver.jwt.issuer-uri}")
    private String issuerUri;

    @Value("${aws.cognito.clientId}")
    private String clientId;

    // Wstrzyknij URL frontendu ze zmiennej środowiskowej
    @Value("${app.cors.allowed-origin.frontend}") // Nazwa właściwości odpowiadająca zmiennej środowiskowej
    private String frontendAppUrlFromEnv;

    @Value("${app.cors.allowed-origin.local:http://localhost:5173}") // Domyślna wartość dla lokalnego
    private String localFrontendAppUrl;

    @Bean
    public JwtDecoder jwtDecoder() {
        NimbusJwtDecoder jwtDecoder = (NimbusJwtDecoder) JwtDecoders.fromOidcIssuerLocation(issuerUri);
        OAuth2TokenValidator<Jwt> audienceValidator = new AudienceValidator(clientId);
        OAuth2TokenValidator<Jwt> withIssuer = JwtValidators.createDefaultWithIssuer(issuerUri);
        OAuth2TokenValidator<Jwt> validator = new DelegatingOAuth2TokenValidator<>(withIssuer, audienceValidator);
        jwtDecoder.setJwtValidator(validator);
        return jwtDecoder;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/actuator/**").permitAll()
                        .requestMatchers("/api/auth/**").permitAll()
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .anyRequest().authenticated()
                )
                .oauth2ResourceServer(oauth2 -> oauth2
                        .jwt(jwt -> jwt.decoder(jwtDecoder()))
                );
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();

        // Dynamiczne pobieranie origin z zmiennych środowiskowych
        String frontendUrl = System.getenv("APP_CORS_ALLOWED_ORIGIN_FRONTEND");
        if (frontendUrl != null && !frontendUrl.isEmpty()) {
            configuration.setAllowedOrigins(List.of(frontendUrl));
            if (frontendUrl.startsWith("http://")) {
                configuration.addAllowedOrigin("www." + frontendUrl.substring(7));
            }
        }
        configuration.addAllowedOrigin(localFrontendAppUrl); // Domyślny lokalny

        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD"));
        configuration.setAllowedHeaders(Arrays.asList("*"));
        configuration.setExposedHeaders(Arrays.asList("Authorization"));
        configuration.setAllowCredentials(true);
        configuration.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);

        // Logowanie skonfigurowanych originów
        System.out.println("Configured CORS with allowed origins: " + configuration.getAllowedOrigins());
        System.out.println("Frontend URL from env: " + frontendUrl);

        return source;
    }

}
