package com.learning.task.dto;

import com.learning.task.entity.Task;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * DTO for task response.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class TaskResponse {

    private Long id;
    private String title;
    private String description;
    private Boolean completed;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    /**
     * Convert Task entity to TaskResponse DTO.
     *
     * @param task the task entity
     * @return TaskResponse DTO
     */
    public static TaskResponse fromEntity(Task task) {
        return new TaskResponse(
            task.getId(),
            task.getTitle(),
            task.getDescription(),
            task.getCompleted(),
            task.getCreatedAt(),
            task.getUpdatedAt()
        );
    }
}
