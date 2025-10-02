package com.learning.task;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * Main application class for the Task Management API.
 * Provides RESTful endpoints for task management with JWT-based authentication.
 */
@SpringBootApplication
@EnableJpaAuditing
public class TaskApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(TaskApiApplication.class, args);
    }
}
