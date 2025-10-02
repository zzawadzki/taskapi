package com.learning.task.repository;

import com.learning.task.entity.Task;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Repository interface for Task entity operations.
 */
@Repository
public interface TaskRepository extends JpaRepository<Task, Long> {

    /**
     * Find all tasks for a specific user.
     *
     * @param userId the ID of the user
     * @return list of tasks belonging to the user
     */
    List<Task> findByUserId(Long userId);

    /**
     * Find a specific task by ID and user ID.
     *
     * @param id the task ID
     * @param userId the user ID
     * @return an Optional containing the task if found
     */
    Optional<Task> findByIdAndUserId(Long id, Long userId);

    /**
     * Delete a task by ID and user ID.
     *
     * @param id the task ID
     * @param userId the user ID
     */
    void deleteByIdAndUserId(Long id, Long userId);
}
