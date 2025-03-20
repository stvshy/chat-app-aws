package pl.projekt_chmury.backend.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;
import pl.projekt_chmury.backend.util.JwtUtil;
import pl.projekt_chmury.backend.repository.UserRepository;
import pl.projekt_chmury.backend.model.User;

import java.io.IOException;

public class JwtFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;

    public JwtFilter(JwtUtil jwtUtil, UserRepository userRepository) {
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        logger.debug("Authorization header: " + header);
        if (StringUtils.hasText(header) && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            logger.debug("Extracted token: {}" + token);
            if (jwtUtil.validateToken(token)) {
                String username = jwtUtil.extractUsername(token);
                logger.debug("Token is valid. Username extracted: {}" + username);
                // Pobieramy użytkownika z bazy
                User user = userRepository.findByUsername(username).orElse(null);
                if (user != null) {
                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken(username, null, java.util.Collections.emptyList());
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                    logger.debug("User authenticated: {}" + username);
                }
                else {
                    logger.debug("User not found in database: {}" + username);
                }
            } else {
                logger.debug("Token is invalid.");
            }
        } else {
            logger.debug("No Authorization header found.");
        }
        filterChain.doFilter(request, response);
    }
}
