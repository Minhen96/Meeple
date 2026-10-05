package com.meeplehearth.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.meeplehearth.auth.filter.JwtAuthFilter;
import com.meeplehearth.auth.service.UserDetailsServiceImpl;
import com.meeplehearth.auth.util.JwtUtil;
import com.meeplehearth.common.ratelimit.RedisRateLimiter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;
import java.util.Map;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private static final Logger log = LoggerFactory.getLogger(SecurityConfig.class);
    private static final String[] ADMIN_PATHS = {
            "/api/v1/games/import",
            "/api/v1/games/hydrate-images",
            "/api/v1/admin/**"
    };

    private final AppProperties appProperties;
    private final JwtUtil jwtUtil;
    private final UserDetailsServiceImpl userDetailsService;
    private final Environment environment;
    private final RedisRateLimiter rateLimiter;

    @Value("${app.security.open-admin-endpoints:false}")
    private boolean openAdminEndpoints;

    @Value("${springdoc.api-docs.enabled:true}")
    private boolean apiDocsEnabled;

    public SecurityConfig(AppProperties appProperties,
            JwtUtil jwtUtil,
            UserDetailsServiceImpl userDetailsService,
            Environment environment,
            RedisRateLimiter rateLimiter) {
        this.rateLimiter = rateLimiter;
        this.appProperties = appProperties;
        this.jwtUtil = jwtUtil;
        this.userDetailsService = userDetailsService;
        this.environment = environment;
    }

    @Bean
    public JwtAuthFilter jwtAuthFilter() {
        return new JwtAuthFilter(jwtUtil, userDetailsService);
    }

    /**
     * Opening admin endpoints is a local-development convenience only. Outside the local
     * profile the flag is ignored, so a stray environment variable can never expose them.
     */
    boolean adminEndpointsOpen() {
        if (!openAdminEndpoints) {
            return false;
        }
        if (environment.acceptsProfiles(Profiles.of("local"))) {
            return true;
        }
        log.warn("app.security.open-admin-endpoints is ignored: it is only honoured with the 'local' profile");
        return false;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        ObjectMapper objectMapper = new ObjectMapper();
        boolean adminOpen = adminEndpointsOpen();
        JwtAuthFilter jwtAuthFilter = jwtAuthFilter();

        http
                .csrf(AbstractHttpConfigurer::disable)
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .addFilterBefore(new OriginCheckFilter(appProperties.getCors().getAllowedOrigins()),
                        UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
                // Not a bean: a Filter bean would also be registered with the servlet container and
                // run before authentication, counting every request against the client IP
                .addFilterAfter(new GlobalRateLimitFilter(rateLimiter, appProperties.getRateLimit()),
                        JwtAuthFilter.class)
                .authorizeHttpRequests(auth -> {
                        // Session management lives under /auth but needs a signed-in user
                        auth.requestMatchers("/api/v1/auth/sessions", "/api/v1/auth/sessions/**")
                                .authenticated();
                        auth.requestMatchers(
                                "/api/v1/auth/**",
                                "/.well-known/assetlinks.json",
                                "/.well-known/apple-app-site-association",
                                "/api/v1/games",
                                "/ws/**",
                                "/actuator/health",
                                "/actuator/health/**")
                                .permitAll();
                        auth.requestMatchers("/actuator/**").hasRole("ADMIN");
                        if (apiDocsEnabled) {
                            auth.requestMatchers("/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**")
                                    .permitAll();
                        }
                        if (adminOpen) {
                            auth.requestMatchers(ADMIN_PATHS).permitAll();
                        } else {
                            auth.requestMatchers(ADMIN_PATHS).hasRole("ADMIN");
                        }
                        auth.anyRequest().authenticated();
                })
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint((request, response, authException) -> {
                            response.setStatus(HttpStatus.UNAUTHORIZED.value());
                            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                            response.getWriter().write(
                                    objectMapper.writeValueAsString(
                                            Map.of("error", "Authentication required", "code", "UNAUTHORIZED")));
                        }));

        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(appProperties.getCors().getAllowedOrigins());
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
}
