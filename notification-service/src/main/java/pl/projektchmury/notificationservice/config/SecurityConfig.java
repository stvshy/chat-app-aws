package pl.projektchmury.notificationservice.config;

import org.springframework.beans.factory.annotation.Value; // Do wstrzykiwania wartości z konfiguracji
import org.springframework.context.annotation.Bean; // Do tworzenia beanów Springa
import org.springframework.context.annotation.Configuration; // Oznacza klasę konfiguracyjną
import org.springframework.http.HttpMethod; // Do określania metod HTTP (GET, POST, itp.)
import org.springframework.security.config.annotation.web.builders.HttpSecurity; // Do konfiguracji bezpieczeństwa HTTP
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity; // Włącza wsparcie Spring Security dla aplikacji webowych
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator; // Łączy wiele walidatorów tokenów w jeden
import org.springframework.security.oauth2.core.OAuth2TokenValidator; // Interfejs walidatora tokenów
import org.springframework.security.oauth2.jwt.*; // Klasy związane z obsługą tokenów JWT
import org.springframework.security.web.SecurityFilterChain; // Definiuje łańcuch filtrów bezpieczeństwa Springa
import org.springframework.web.cors.CorsConfiguration; // Do konfiguracji CORS
import org.springframework.web.cors.CorsConfigurationSource; // Źródło konfiguracji CORS
import org.springframework.web.cors.UrlBasedCorsConfigurationSource; // Implementacja CorsConfigurationSource oparta na URL

import java.util.ArrayList; // Do tworzenia list
import java.util.Arrays; // Do pracy z tablicami
import java.util.List; // Interfejs listy

@Configuration // Mówi Springowi: "Ta klasa zawiera konfigurację bezpieczeństwa."
@EnableWebSecurity // Włącza mechanizmy bezpieczeństwa webowego Spring Security. To WAŻNE!
public class SecurityConfig {

    // Wstrzyknij adres URL wystawcy tokenów JWT (np. adres Twojej puli użytkowników Cognito).
    // To jest miejsce, skąd Spring Security będzie pobierał klucze publiczne do weryfikacji podpisów tokenów.
    @Value("${spring.security.oauth2.resourceserver.jwt.issuer-uri}")
    private String issuerUri;

    // Wstrzyknij Client ID Twojej aplikacji z Cognito.
    // Będzie używany przez AudienceValidator do sprawdzenia, czy token jest dla tej aplikacji.
    @Value("${aws.cognito.clientId}")
    private String clientId;

    // Wstrzyknij adres URL frontendu zdefiniowany w zmiennej środowiskowej (np. ustawionej przez Terraform).
    // Używane do konfiguracji CORS.
    @Value("${app.cors.allowed-origin.frontend}")
    private String frontendAppUrlFromEnv;

    // Wstrzyknij lokalny adres URL frontendu (np. http://localhost:5173 dla dewelopmentu).
    // Jeśli app.cors.allowed-origin.local nie jest zdefiniowane, użyje http://localhost:5173.
    @Value("${app.cors.allowed-origin.local:http://localhost:5173}")
    private String localFrontendAppUrl;

    @Bean // Mówi Springowi: "Stwórz i zarządzaj obiektem JwtDecoder."
    // JwtDecoder jest odpowiedzialny za dekodowanie i walidację przychodzących tokenów JWT.
    public JwtDecoder jwtDecoder() {
        // Stwórz dekoder JWT, który pobiera konfigurację (np. klucze publiczne) z adresu wystawcy (issuerUri).
        NimbusJwtDecoder jwtDecoder = (NimbusJwtDecoder) JwtDecoders.fromOidcIssuerLocation(issuerUri);

        // Stwórz nasz niestandardowy walidator "audience" (sprawdza, czy token jest dla nas).
        OAuth2TokenValidator<Jwt> audienceValidator = new AudienceValidator(clientId);
        // Stwórz standardowy walidator, który sprawdza, czy pole "iss" (issuer) w tokenie zgadza się z issuerUri.
        OAuth2TokenValidator<Jwt> withIssuer = JwtValidators.createDefaultWithIssuer(issuerUri);

        // Połącz oba walidatory (issuer i audience) w jeden "delegujący" walidator.
        // Token musi przejść oba te sprawdzenia, żeby być uznany za ważny.
        OAuth2TokenValidator<Jwt> validator = new DelegatingOAuth2TokenValidator<>(withIssuer, audienceValidator);

        // Ustaw ten połączony walidator w dekoderze JWT.
        jwtDecoder.setJwtValidator(validator);
        return jwtDecoder; // Zwróć skonfigurowany dekoder.
    }

    @Bean // Mówi Springowi: "Stwórz i zarządzaj obiektem SecurityFilterChain."
    // SecurityFilterChain definiuje, jak Spring Security ma obsługiwać żądania HTTP
    // (np. które ścieżki wymagają autentykacji, jakiej metody autentykacji użyć).
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                // Konfiguracja CORS (Cross-Origin Resource Sharing) - kto może wysyłać żądania z innej domeny.
                .cors(cors -> cors.configurationSource(corsConfigurationSource())) // Użyj konfiguracji CORS zdefiniowanej w metodzie corsConfigurationSource().
                // Wyłącz ochronę CSRF (Cross-Site Request Forgery).
                // Dla API bezstanowych (stateless), które używają tokenów (jak JWT), CSRF jest mniej istotne
                // i często wyłączane, aby uprościć konfigurację.
                .csrf(csrf -> csrf.disable())
                // Autoryzacja żądań HTTP - które ścieżki są dostępne dla kogo.
                .authorizeHttpRequests(auth -> auth
                        // Zezwól na wszystkie żądania do endpointów Actuatora (np. /actuator/health).
                        .requestMatchers("/actuator/**").permitAll()
                        // Wszystkie żądania do /api/notifications/** muszą być uwierzytelnione (muszą mieć ważny token JWT).
                        .requestMatchers("/api/notifications/**").authenticated()
                        // Zezwól na wszystkie żądania typu OPTIONS do dowolnej ścieżki.
                        // Przeglądarki wysyłają żądania OPTIONS (tzw. "preflight requests") przed niektórymi żądaniami CORS,
                        // aby sprawdzić, czy serwer zezwala na takie żądanie.
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        // Wszystkie inne żądania (które nie pasowały do powyższych reguł) mają być odrzucone.
                        .anyRequest().denyAll()
                )
                // Skonfiguruj serwer zasobów OAuth 2.0 do obsługi tokenów JWT.
                .oauth2ResourceServer(oauth2 -> oauth2
                        // Określ, że używamy tokenów JWT...
                        .jwt(jwt -> jwt.decoder(jwtDecoder())) // ...i podaj dekoder JWT, który ma być użyty (ten z metody jwtDecoder()).
                );
        return http.build(); // Zbuduj i zwróć skonfigurowany łańcuch filtrów bezpieczeństwa.
    }

    @Bean // Mówi Springowi: "Stwórz i zarządzaj obiektem CorsConfigurationSource."
    // To źródło dostarcza konfigurację CORS dla Spring Security.
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration(); // Stwórz nowy obiekt konfiguracji CORS.

        List<String> allowedOrigins = new ArrayList<>(); // Lista dozwolonych "originów" (adresów frontendu).
        allowedOrigins.add(localFrontendAppUrl); // Zawsze zezwalaj na lokalny adres frontendu.
        // Jeśli adres frontendu z AWS jest zdefiniowany (nie jest pusty)...
        if (frontendAppUrlFromEnv != null && !frontendAppUrlFromEnv.isEmpty()) {
            allowedOrigins.add(frontendAppUrlFromEnv); // ...dodaj go do listy dozwolonych.
        }
        // Zapisz w logach, jakie adresy są dozwolone (pomocne przy debugowaniu CORS).
        System.out.println("NotificationService CORS Allowed Origins: " + allowedOrigins);

        // Ustaw listę dozwolonych originów w konfiguracji.
        configuration.setAllowedOrigins(allowedOrigins);
        // Ustaw dozwolone metody HTTP (GET, POST, itp.). "*" oznacza wszystkie.
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD"));
        // Ustaw dozwolone nagłówki HTTP. "*" oznacza wszystkie.
        configuration.setAllowedHeaders(Arrays.asList("*"));
        // Ustaw nagłówki, które frontend będzie mógł odczytać w odpowiedzi od serwera (np. Authorization).
        configuration.setExposedHeaders(Arrays.asList("Authorization"));
        // Czy zezwalać na wysyłanie poświadczeń (np. ciasteczek, nagłówków Authorization) z żądaniami CORS?
        configuration.setAllowCredentials(true); // Tak.

        // Stwórz źródło konfiguracji CORS oparte na URL.
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        // Zarejestruj naszą konfigurację CORS dla wszystkich ścieżek ("/**").
        source.registerCorsConfiguration("/**", configuration);
        return source; // Zwróć skonfigurowane źródło.
    }
}
