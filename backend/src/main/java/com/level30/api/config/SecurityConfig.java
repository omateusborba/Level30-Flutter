package com.level30.api.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.level30.api.security.AuthRateLimitFilter;
import com.level30.api.security.AuthRateLimiter;
import com.level30.api.security.ClientIpResolver;
import com.level30.api.security.JwtAuthFilter;
import com.level30.api.security.RestAuthErrorHandlers;
import java.util.Arrays;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private static final String[] PUBLIC_PATHS = {
            "/",
            "/auth/**",
            "/actuator/health",
            "/actuator/health/**",
            "/v3/api-docs/**",
            "/swagger-ui/**",
            "/swagger-ui.html"
    };

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http,
                                    JwtAuthFilter jwtAuthFilter,
                                    RestAuthErrorHandlers errorHandlers,
                                    CorsConfigurationSource corsConfigurationSource,
                                    AuthRateLimiter authRateLimiter,
                                    ClientIpResolver clientIpResolver,
                                    ObjectMapper objectMapper) throws Exception {
        AuthRateLimitFilter authRateLimitFilter =
                new AuthRateLimitFilter(authRateLimiter, clientIpResolver, objectMapper);
        http
                .csrf(csrf -> csrf.disable())
                .cors(cors -> cors.configurationSource(corsConfigurationSource))
                .headers(h -> h
                        .frameOptions(fo -> fo.deny())
                        .contentTypeOptions(c -> {})
                        .httpStrictTransportSecurity(hsts -> hsts
                                .includeSubDomains(true)
                                .maxAgeInSeconds(31_536_000))
                        .referrerPolicy(rp -> rp.policy(
                                org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter
                                        .ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN))
                        .addHeaderWriter((request, response) -> {
                            response.setHeader("Permissions-Policy",
                                    "geolocation=(), microphone=(), camera=()");
                            // CSP severa para a API JSON; o Swagger UI (mesma origem) precisa afrouxar.
                            String path = request.getRequestURI();
                            boolean swagger = path.startsWith("/swagger-ui")
                                    || path.startsWith("/v3/api-docs");
                            response.setHeader("Content-Security-Policy", swagger
                                    ? "default-src 'self'; script-src 'self' 'unsafe-inline'; "
                                      + "style-src 'self' 'unsafe-inline'; img-src 'self' data:; "
                                      + "frame-ancestors 'none'"
                                    : "default-src 'none'; frame-ancestors 'none'; base-uri 'none'");
                        }))
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(PUBLIC_PATHS).permitAll()
                        .requestMatchers("/admin/**").hasRole("ADMIN")
                        .anyRequest().authenticated())
                .exceptionHandling(e -> e
                        .authenticationEntryPoint(errorHandlers.entryPoint())
                        .accessDeniedHandler(errorHandlers.accessDeniedHandler()))
                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(authRateLimitFilter, JwtAuthFilter.class);

        return http.build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(10);
    }

    @Bean
    CorsConfigurationSource corsConfigurationSource(
            @Value("${app.cors.allowed-origins}") String allowedOrigins) {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(Arrays.stream(allowedOrigins.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList());
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("Content-Type", "Authorization"));
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
