package com.learning.task.service;

import com.learning.task.dto.AuthResponse;
import com.learning.task.dto.LoginRequest;
import com.learning.task.dto.RegisterRequest;
import com.learning.task.entity.User;
import com.learning.task.repository.UserRepository;
import com.learning.task.security.JwtTokenProvider;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class AuthServiceTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private AuthenticationManager authenticationManager;
    @Mock
    private JwtTokenProvider tokenProvider;

    @InjectMocks
    private AuthService authService;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
    }

    @Test
    void register_success() {
        RegisterRequest request = new RegisterRequest();
        request.setUsername("alice");
        request.setEmail("alice@example.com");
        request.setPassword("secret");

        when(userRepository.existsByUsername("alice")).thenReturn(false);
        when(userRepository.existsByEmail("alice@example.com")).thenReturn(false);
        when(passwordEncoder.encode("secret")).thenReturn("ENC");
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> {
            User u = invocation.getArgument(0);
            u.setId(1L);
            return u;
        });
        when(tokenProvider.generateTokenFromUsername("alice")).thenReturn("jwt-token");

        AuthResponse response = authService.register(request);

        assertEquals("jwt-token", response.getToken());
        assertEquals("alice", response.getUsername());

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(userCaptor.capture());
        User saved = userCaptor.getValue();
        assertEquals("alice", saved.getUsername());
        assertEquals("alice@example.com", saved.getEmail());
        assertEquals("ENC", saved.getPassword());
    }

    @Test
    void register_duplicateUsername_throws() {
        RegisterRequest request = new RegisterRequest();
        request.setUsername("dup");
        request.setEmail("d@example.com");
        request.setPassword("x");

        when(userRepository.existsByUsername("dup")).thenReturn(true);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));
        assertTrue(ex.getMessage().toLowerCase().contains("username"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void register_duplicateEmail_throws() {
        RegisterRequest request = new RegisterRequest();
        request.setUsername("user");
        request.setEmail("dup@example.com");
        request.setPassword("x");

        when(userRepository.existsByUsername("user")).thenReturn(false);
        when(userRepository.existsByEmail("dup@example.com")).thenReturn(true);

        RuntimeException ex = assertThrows(RuntimeException.class, () -> authService.register(request));
        assertTrue(ex.getMessage().toLowerCase().contains("email"));
        verify(userRepository, never()).save(any());
    }

    @Test
    void login_success() {
        LoginRequest request = new LoginRequest();
        request.setUsername("bob");
        request.setPassword("pw");

        Authentication authentication = mock(Authentication.class);
        UserDetails principal = org.springframework.security.core.userdetails.User
                .withUsername("bob").password("pw").authorities("ROLE_USER").build();
        when(authentication.getPrincipal()).thenReturn(principal);
        when(authenticationManager.authenticate(any(UsernamePasswordAuthenticationToken.class))).thenReturn(authentication);
        when(tokenProvider.generateToken(authentication)).thenReturn("jwt");

        // Mock SecurityContext to avoid NPE
        SecurityContext context = mock(SecurityContext.class);
        SecurityContextHolder.setContext(context);

        AuthResponse response = authService.login(request);

        assertEquals("jwt", response.getToken());
        assertEquals("bob", response.getUsername());
        verify(context).setAuthentication(authentication);
    }
}
