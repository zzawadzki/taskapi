package com.learning.task.service;

import com.learning.task.dto.TaskRequest;
import com.learning.task.dto.TaskResponse;
import com.learning.task.entity.Task;
import com.learning.task.entity.User;
import com.learning.task.exception.ResourceNotFoundException;
import com.learning.task.exception.UnauthorizedException;
import com.learning.task.repository.TaskRepository;
import com.learning.task.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Service for task operations.
 */
@Service
@RequiredArgsConstructor
public class TaskService {

    private final TaskRepository taskRepository;
    private final UserRepository userRepository;

    /**
     * Get all tasks for the authenticated user.
     *
     * @return list of task responses
     */
    public List<TaskResponse> getAllTasks() {
        User user = getCurrentUser();
        List<Task> tasks = taskRepository.findByUserId(user.getId());
        return tasks.stream()
                .map(TaskResponse::fromEntity)
                .collect(Collectors.toList());
    }

    /**
     * Get a specific task by ID.
     *
     * @param id the task ID
     * @return task response
     * @throws ResourceNotFoundException if task not found
     */
    public TaskResponse getTaskById(Long id) {
        User user = getCurrentUser();
        Task task = taskRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Task not found with id: " + id));
        return TaskResponse.fromEntity(task);
    }

    /**
     * Create a new task.
     *
     * @param request the task request
     * @return created task response
     */
    @Transactional
    public TaskResponse createTask(TaskRequest request) {
        User user = getCurrentUser();

        Task task = new Task();
        task.setTitle(request.getTitle());
        task.setDescription(request.getDescription());
        task.setCompleted(request.getCompleted() != null ? request.getCompleted() : false);
        task.setUser(user);

        Task savedTask = taskRepository.save(task);
        return TaskResponse.fromEntity(savedTask);
    }

    /**
     * Update an existing task.
     *
     * @param id the task ID
     * @param request the task request
     * @return updated task response
     * @throws ResourceNotFoundException if task not found
     */
    @Transactional
    public TaskResponse updateTask(Long id, TaskRequest request) {
        User user = getCurrentUser();
        Task task = taskRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Task not found with id: " + id));

        task.setTitle(request.getTitle());
        task.setDescription(request.getDescription());
        if (request.getCompleted() != null) {
            task.setCompleted(request.getCompleted());
        }

        Task updatedTask = taskRepository.save(task);
        return TaskResponse.fromEntity(updatedTask);
    }

    /**
     * Delete a task.
     *
     * @param id the task ID
     * @throws ResourceNotFoundException if task not found
     */
    @Transactional
    public void deleteTask(Long id) {
        User user = getCurrentUser();
        Task task = taskRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Task not found with id: " + id));
        taskRepository.delete(task);
    }

    /**
     * Toggle task completion status.
     *
     * @param id the task ID
     * @return updated task response
     * @throws ResourceNotFoundException if task not found
     */
    @Transactional
    public TaskResponse toggleTaskCompletion(Long id) {
        User user = getCurrentUser();
        Task task = taskRepository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Task not found with id: " + id));

        task.setCompleted(!task.getCompleted());
        Task updatedTask = taskRepository.save(task);
        return TaskResponse.fromEntity(updatedTask);
    }

    /**
     * Get the currently authenticated user.
     *
     * @return current user entity
     * @throws UnauthorizedException if user not authenticated
     */
    private User getCurrentUser() {
        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        if (principal instanceof UserDetails) {
            String username = ((UserDetails) principal).getUsername();
            return userRepository.findByUsername(username)
                    .orElseThrow(() -> new UnauthorizedException("User not found"));
        }

        throw new UnauthorizedException("User not authenticated");
    }
}
