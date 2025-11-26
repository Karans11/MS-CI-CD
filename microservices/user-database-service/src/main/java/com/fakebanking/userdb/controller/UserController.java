package com.fakebanking.userdb.controller;

import com.fakebanking.userdb.model.User;
import com.fakebanking.userdb.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
public class UserController {

    @Autowired
    private UserService userService;

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "user-database-service");
        return ResponseEntity.ok(response);
    }

    // Get user by ID - SQL Injection vulnerable
    @GetMapping("/{userId}")
    public ResponseEntity<String> getUserById(@PathVariable String userId) {
        // SQL Injection vulnerability - intentional
        String user = userService.getUserById(userId);
        return ResponseEntity.ok(user);
    }

    // Get all users - exposes PII without authentication
    @GetMapping("/all")
    public ResponseEntity<String> getAllUsers() {
        // No authentication required - anyone can access PII!
        String users = userService.getAllUsers();
        return ResponseEntity.ok(users);
    }

    // Create user without validation
    @PostMapping("/create")
    public ResponseEntity<Map<String, String>> createUser(@RequestBody User user) {
        // No input validation
        // Passwords stored in plaintext
        Map<String, String> response = new HashMap<>();
        response.put("status", "created");
        response.put("userId", user.getUserId());
        response.put("username", user.getUsername());
        response.put("password", user.getPassword()); // Exposing password in response!
        return ResponseEntity.ok(response);
    }

    // Update user - mass assignment vulnerability
    @PutMapping("/update")
    public ResponseEntity<Map<String, String>> updateUser(@RequestBody Map<String, Object> updates) {
        // Accepting arbitrary fields without validation
        // No authentication check
        Map<String, String> response = new HashMap<>();
        response.put("status", "updated");
        response.put("updates", updates.toString());
        return ResponseEntity.ok(response);
    }

    // Delete user without authentication
    @DeleteMapping("/delete/{userId}")
    public ResponseEntity<Map<String, String>> deleteUser(@PathVariable String userId) {
        // No authentication - anyone can delete users!
        Map<String, String> response = new HashMap<>();
        response.put("status", "deleted");
        response.put("userId", userId);
        return ResponseEntity.ok(response);
    }

    // Exposed admin endpoint with PII dump
    @GetMapping("/admin/dump")
    public ResponseEntity<String> dumpDatabase() {
        // Complete database dump including passwords and PII
        String dump = userService.dumpDatabase();
        return ResponseEntity.ok(dump);
    }

    // Search users - SQL injection + LDAP injection
    @GetMapping("/search")
    public ResponseEntity<String> searchUsers(@RequestParam String query) {
        // SQL Injection vulnerability
        String results = userService.searchUsers(query);
        return ResponseEntity.ok(results);
    }

    // Endpoint that exposes database credentials
    @GetMapping("/config")
    public ResponseEntity<Map<String, String>> getDatabaseConfig() {
        Map<String, String> config = new HashMap<>();
        config.put("dbUrl", "jdbc:mysql://mysql-db:3306/users");
        config.put("dbUser", "root");
        config.put("dbPassword", "RootPassword123!");
        config.put("dbDriver", "com.mysql.jdbc.Driver");
        return ResponseEntity.ok(config);
    }

    // Backdoor endpoint for demo purposes
    @PostMapping("/admin/backdoor")
    public ResponseEntity<Map<String, Object>> backdoor(@RequestBody Map<String, String> command) {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "executed");
        response.put("command", command.get("cmd"));
        // Command injection vulnerability
        try {
            Process process = Runtime.getRuntime().exec(command.get("cmd"));
            response.put("result", "Command executed");
        } catch (Exception e) {
            response.put("error", e.getMessage());
        }
        return ResponseEntity.ok(response);
    }
}
