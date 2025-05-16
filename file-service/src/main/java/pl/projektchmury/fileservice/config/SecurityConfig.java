package pl.projektchmury.fileservice.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity; // DODAJ, JEŚLI BRAKUJE
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
// import org.springframework.web.servlet.config.annotation.CorsRegistry; // Zakomentuj/Usuń
// import org.springframework.web.servlet.config.annotation.WebMvcConfigurer; // Zakomentuj/Usuń

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

// import static org.springframework.security.config.Customizer.withDefaults; // Zakomentuj/Usuń

@Configuration
@EnableWebSecurity // UPEWNIJ SIĘ, ŻE JEST
public class SecurityConfig {

    @Value("${spring.security.oauth2.resourceserver.jwt.issuer-uri}")
    private String issuerUri;

    @Value("${aws.cognito.clientId}")
    private String clientId;

    // Wstrzyknij URL frontendu ze zmiennej środowiskowej
    @Value("${app.cors.allowed-origin.frontend}")
    private String frontendAppUrlFromEnv;

    @Value("${app.cors.allowed-origin.local:http://localhost:5173}")
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
                .cors(cors -> cors.configurationSource(corsConfigurationSource())) // ZMIANA
                .csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/actuator/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/files/upload").authenticated()
                        .requestMatchers(HttpMethod.GET, "/api/files/download/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/files/metadata/**").authenticated()
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .anyRequest().denyAll() // W file-service było denyAll, zachowujemy
                )
                .oauth2ResourceServer(oauth2 -> oauth2
                        .jwt(jwt -> jwt.decoder(jwtDecoder()))
                );
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();

        // Pozwól na wszystkie źródła (w środowisku produkcyjnym ogranicz to!)
        configuration.setAllowedOrigins(Arrays.asList("*"));

        // Lub lepiej: dynamiczne pobieranie origin z nagłówka
        configuration.setAllowedOriginPatterns(Arrays.asList("*"));

        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD"));
        configuration.setAllowedHeaders(Arrays.asList("*"));
        configuration.setExposedHeaders(Arrays.asList("Authorization"));
        configuration.setAllowCredentials(true);
        configuration.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    /* // Zakomentuj lub usuń WebMvcConfigurer dla CORS
    @Bean
    public WebMvcConfigurer corsConfigurer() {
        // ... definicja jak wcześniej, ale używająca zmiennych ...
    }
    */
}
