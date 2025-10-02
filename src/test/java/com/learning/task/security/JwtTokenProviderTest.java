package com.learning.task.security;

import com.learning.task.config.JwtConfig;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;

import static org.junit.jupiter.api.Assertions.*;

class JwtTokenProviderTest {

    private JwtTokenProvider jwtTokenProvider;

    @BeforeEach
    void setUp() {
        JwtConfig config = new JwtConfig();
        // use 256-bit+ secret for HS256
        config.setSecret("0123456789_0123456789_0123456789_0123456789_secret_key_for_tests");
        config.setExpiration(1000L * 60); // 1 minute
        jwtTokenProvider = new JwtTokenProvider(config);
    }

    @Test
    void generateAndValidateToken_fromAuthentication() {
        UserDetails userDetails = User.withUsername("alice").password("pw").authorities("ROLE_USER").build();
        Authentication auth = new UsernamePasswordAuthenticationToken(userDetails, userDetails.getPassword(), userDetails.getAuthorities());

        String token = jwtTokenProvider.generateToken(auth);
        assertNotNull(token);
        assertTrue(jwtTokenProvider.validateToken(token));
        assertEquals("alice", jwtTokenProvider.getUsernameFromToken(token));
    }

    @Test
    void generateAndValidateToken_fromUsername() {
        String token = jwtTokenProvider.generateTokenFromUsername("bob");
        assertNotNull(token);
        assertTrue(jwtTokenProvider.validateToken(token));
        assertEquals("bob", jwtTokenProvider.getUsernameFromToken(token));
    }

    @Test
    void validateToken_returnsFalse_forMalformedToken() {
        assertFalse(jwtTokenProvider.validateToken("not-a-jwt"));
    }

    @Test
    void validateToken_returnsFalse_forExpiredToken() throws InterruptedException {
        JwtConfig shortCfg = new JwtConfig();
        shortCfg.setSecret("0123456789_0123456789_0123456789_0123456789_secret_key_for_tests");
        shortCfg.setExpiration(1); // 1 ms
        JwtTokenProvider shortLived = new JwtTokenProvider(shortCfg);

        String token = shortLived.generateTokenFromUsername("temp");
        // ensure it expires
        Thread.sleep(5);
        assertFalse(shortLived.validateToken(token));
    }
}
