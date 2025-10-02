package com.learning.task.controller;

import com.learning.task.dto.TaskRequest;
import com.learning.task.dto.TaskResponse;
import com.learning.task.service.TaskService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST controller for task management endpoints.
 */
@RestController
@RequestMapping("/api/tasks")
@RequiredArgsConstructor
public class TaskController {

    private final TaskService taskService;

    /**
     * Get all tasks for the authenticated user.
     *
     * @return list of tasks
     */
    @GetMapping
    public ResponseEntity<List<TaskResponse>> getAllTasks() {
        List<TaskResponse> tasks = taskService.getAllTasks();
        return ResponseEntity.ok(tasks);
    }

    /**
     * Get a specific task by ID.
     *
     * @param id the task ID
     * @return task response
     */
    @GetMapping("/{id}")
    public ResponseEntity<TaskResponse> getTaskById(@PathVariable Long id) {
        TaskResponse task = taskService.getTaskById(id);
        return ResponseEntity.ok(task);
    }

    /**
     * Create a new task.
     *
     * @param request the task request
     * @return created task
     */
    @PostMapping
    public ResponseEntity<TaskResponse> createTask(@Valid @RequestBody TaskRequest request) {
        TaskResponse task = taskService.createTask(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(task);
    }

    /**
     * Update an existing task.
     *
     * @param id the task ID
     * @param request the task request
     * @return updated task
     */
    @PutMapping("/{id}")
    public ResponseEntity<TaskResponse> updateTask(@PathVariable Long id, @Valid @RequestBody TaskRequest request) {
        TaskResponse task = taskService.updateTask(id, request);
        return ResponseEntity.ok(task);
    }

    /**
     * Delete a task.
     *
     * @param id the task ID
     * @return no content response
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteTask(@PathVariable Long id) {
        taskService.deleteTask(id);
        return ResponseEntity.noContent().build();
    }

    /**
     * Toggle task completion status.
     *
     * @param id the task ID
     * @return updated task
     */
    @PatchMapping("/{id}/complete")
    public ResponseEntity<TaskResponse> toggleTaskCompletion(@PathVariable Long id) {
        TaskResponse task = taskService.toggleTaskCompletion(id);
        return ResponseEntity.ok(task);
    }
}
