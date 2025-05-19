package pl.projektchmury.notificationservice.config;

import org.springframework.security.oauth2.core.OAuth2Error; // Do reprezentowania błędu walidacji tokenu
import org.springframework.security.oauth2.core.OAuth2TokenValidator; // Interfejs dla walidatorów tokenów
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult; // Wynik walidacji tokenu (sukces/porażka)
import org.springframework.security.oauth2.jwt.Jwt; // Reprezentuje zdekodowany token JWT

import java.util.List; // Do pracy z listami, np. listą "audiences" w tokenie

// Ten walidator sprawdza, czy token JWT jest przeznaczony dla tej konkretnej aplikacji (serwisu).
// "Audience" (odbiorca) w tokenie JWT określa, dla kogo token został wystawiony.
public class AudienceValidator implements OAuth2TokenValidator<Jwt> {

    // Przechowuje oczekiwaną wartość "audience" (np. Client ID z Cognito), którą ten serwis akceptuje.
    private final String audience;

    // Konstruktor, który przyjmuje oczekiwaną wartość "audience".
    // Ta wartość będzie wstrzyknięta z konfiguracji (np. z aws.cognito.clientId).
    public AudienceValidator(String audience) {
        this.audience = audience;
    }

    @Override // Nadpisujemy metodę z interfejsu OAuth2TokenValidator.
    // Ta metoda jest wywoływana przez Spring Security, aby sprawdzić token.
    public OAuth2TokenValidatorResult validate(Jwt jwt) {
        // Pobierz listę "audiences" (odbiorców) z tokenu JWT.
        List<String> audiences = jwt.getAudience();

        // SCENARIUSZ 1: Tokeny od Cognito czasami nie mają standardowego claimu "aud" (audience),
        // ale zamiast tego mają claim "client_id", który pełni podobną rolę.
        // Jeśli lista "audiences" jest pusta lub null...
        if (audiences == null || audiences.isEmpty()) {
            // ...spróbuj pobrać wartość claimu "client_id" z tokenu.
            String clientIdClaim = jwt.getClaimAsString("client_id");
            // Jeśli "client_id" istnieje i jest równy oczekiwanej przez nas wartości "audience"...
            if (clientIdClaim != null && clientIdClaim.equals(audience)) {
                return OAuth2TokenValidatorResult.success(); // ...token jest ważny dla tego odbiorcy. Sukces!
            }
        } else if (audiences.contains(audience)) {
            // SCENARIUSZ 2: Token ma standardowy claim "aud" (audience) i zawiera oczekiwaną przez nas wartość.
            return OAuth2TokenValidatorResult.success(); // Sukces!
        }

        // Jeśli żaden z powyższych warunków nie został spełniony, token nie jest dla nas.
        // Stwórz obiekt błędu.
        OAuth2Error error = new OAuth2Error("invalid_token", "The required audience is missing", null);
        // Zwróć wynik walidacji jako porażkę z tym błędem.
        return OAuth2TokenValidatorResult.failure(error);
    }
}
