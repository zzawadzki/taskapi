package com.learning.task.service;

import com.learning.task.dto.TaskRequest;
import com.learning.task.dto.TaskResponse;
import com.learning.task.entity.Task;
import com.learning.task.entity.User;
import com.learning.task.exception.ResourceNotFoundException;
import com.learning.task.exception.UnauthorizedException;
import com.learning.task.repository.TaskRepository;
import com.learning.task.repository.UserRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class TaskServiceTest {

    @Mock
    private TaskRepository taskRepository;
    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private TaskService taskService;

    private AutoCloseable mocks;

    @BeforeEach
    void setUp() {
        mocks = MockitoAnnotations.openMocks(this);
        // Default SecurityContext with principal "alice"
        UserDetails principal = org.springframework.security.core.userdetails.User
                .withUsername("alice").password("pw").authorities("ROLE_USER").build();
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(new UsernamePasswordAuthenticationToken(principal, principal.getPassword(), principal.getAuthorities()));
        SecurityContextHolder.setContext(context);

        User alice = new User();
        alice.setId(10L);
        alice.setUsername("alice");
        alice.setEmail("alice@example.com");
        alice.setPassword("enc");
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(alice));
    }

    @AfterEach
    void tearDown() throws Exception {
        SecurityContextHolder.clearContext();
        if (mocks != null) mocks.close();
    }

    @Test
    void getAllTasks_returnsMappedList_forCurrentUser() {
        Task t1 = buildTask(1L, 10L, "T1", false);
        Task t2 = buildTask(2L, 10L, "T2", true);
        when(taskRepository.findByUserId(10L)).thenReturn(List.of(t1, t2));

        List<TaskResponse> responses = taskService.getAllTasks();
        assertEquals(2, responses.size());
        assertEquals("T1", responses.get(0).getTitle());
        assertEquals(true, responses.get(1).getCompleted());
    }

    @Test
    void getTaskById_whenOwned_returnsDto() {
        Task t = buildTask(5L, 10L, "My Task", false);
        when(taskRepository.findByIdAndUserId(5L, 10L)).thenReturn(Optional.of(t));

        TaskResponse resp = taskService.getTaskById(5L);
        assertEquals(5L, resp.getId());
        assertEquals("My Task", resp.getTitle());
    }

    @Test
    void getTaskById_whenMissing_throwsNotFound() {
        when(taskRepository.findByIdAndUserId(99L, 10L)).thenReturn(Optional.empty());
        assertThrows(ResourceNotFoundException.class, () -> taskService.getTaskById(99L));
    }

    @Test
    void createTask_setsDefaults_andPersistsWithUser() {
        TaskRequest req = new TaskRequest("Title", null, null);
        when(taskRepository.save(any(Task.class))).thenAnswer(invocation -> {
            Task saved = invocation.getArgument(0);
            saved.setId(100L);
            saved.setCreatedAt(LocalDateTime.now());
            saved.setUpdatedAt(LocalDateTime.now());
            return saved;
        });

        TaskResponse resp = taskService.createTask(req);
        assertEquals("Title", resp.getTitle());
        assertEquals(false, resp.getCompleted()); // default

        ArgumentCaptor<Task> captor = ArgumentCaptor.forClass(Task.class);
        verify(taskRepository).save(captor.capture());
        Task persisted = captor.getValue();
        assertNotNull(persisted.getUser());
        assertEquals(10L, persisted.getUser().getId());
    }

    @Test
    void updateTask_updatesFields_andRespectsNullableCompleted() {
        Task existing = buildTask(7L, 10L, "Old", false);
        when(taskRepository.findByIdAndUserId(7L, 10L)).thenReturn(Optional.of(existing));
        when(taskRepository.save(any(Task.class))).thenAnswer(invocation -> invocation.getArgument(0));

        TaskRequest req = new TaskRequest("New", "Desc", null); // completed null - keep existing
        TaskResponse resp = taskService.updateTask(7L, req);

        assertEquals("New", resp.getTitle());
        assertEquals("Desc", resp.getDescription());
        assertEquals(false, resp.getCompleted());

        // Now set completed true
        TaskRequest req2 = new TaskRequest("New2", "Desc2", true);
        TaskResponse resp2 = taskService.updateTask(7L, req2);
        assertEquals(true, resp2.getCompleted());
    }

    @Test
    void deleteTask_whenOwned_deletes() {
        Task existing = buildTask(8L, 10L, "To delete", false);
        when(taskRepository.findByIdAndUserId(8L, 10L)).thenReturn(Optional.of(existing));

        taskService.deleteTask(8L);
        verify(taskRepository).delete(existing);
    }

    @Test
    void toggleTaskCompletion_flipsAndPersists() {
        Task existing = buildTask(9L, 10L, "Toggle", false);
        when(taskRepository.findByIdAndUserId(9L, 10L)).thenReturn(Optional.of(existing));
        when(taskRepository.save(any(Task.class))).thenAnswer(invocation -> invocation.getArgument(0));

        TaskResponse resp = taskService.toggleTaskCompletion(9L);
        assertTrue(resp.getCompleted());

        // call again -> should flip back
        TaskResponse resp2 = taskService.toggleTaskCompletion(9L);
        assertFalse(resp2.getCompleted());
    }

    @Test
    void getCurrentUser_whenNoPrincipal_throwsUnauthorized() {
        // Set authentication with non-UserDetails principal to simulate unauthenticated user
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(new UsernamePasswordAuthenticationToken("anon", "", List.of()));
        SecurityContextHolder.setContext(context);
        assertThrows(UnauthorizedException.class, () -> taskService.getAllTasks());
    }

    private Task buildTask(Long id, Long userId, String title, boolean completed) {
        User u = new User();
        u.setId(userId);
        u.setUsername("alice");
        u.setEmail("alice@example.com");
        u.setPassword("enc");

        Task t = new Task();
        t.setId(id);
        t.setTitle(title);
        t.setDescription("desc");
        t.setCompleted(completed);
        t.setUser(u);
        t.setCreatedAt(LocalDateTime.now());
        t.setUpdatedAt(LocalDateTime.now());
        return t;
    }
}
