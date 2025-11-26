package com.fakebanking.homepage.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

@RestController
public class HomepageController {

    // Hardcoded API keys and credentials (SAST vulnerability)
    @Value("${payment.service.url:http://payment-service:8082}")
    private String paymentServiceUrl;

    @Value("${user.service.url:http://user-database-service:8083}")
    private String userServiceUrl;

    // Multiple hardcoded secrets (SAST will catch these)
    private static final String INTERNAL_API_KEY = "sk-fake-banking-internal-key-12345";
    private static final String DB_PASSWORD = "SuperSecretPassword123";
    private static final String AWS_ACCESS_KEY = "AKIAIOSFODNN7EXAMPLE";
    private static final String AWS_SECRET_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY";
    private static final String STRIPE_SECRET = "sk_live_51fake123456789abcdefgh";
    private static final String JWT_SECRET = "myJWTSecretKey123456789";

    private RestTemplate restTemplate = new RestTemplate();

    @GetMapping("/api")
    public ResponseEntity<Map<String, Object>> apiInfo() {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Welcome to Fake Banking - Intentionally Vulnerable Demo");
        response.put("services", Map.of(
            "payment", paymentServiceUrl,
            "user", userServiceUrl
        ));
        response.put("version", "0.1.0-insecure");
        return ResponseEntity.ok(response);
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "homepage-service");
        return ResponseEntity.ok(response);
    }

    // Login endpoint with SQL injection vulnerability
    @PostMapping("/api/login")
    public ResponseEntity<Map<String, Object>> login(@RequestParam String username, @RequestParam String password) {
        Map<String, Object> response = new HashMap<>();

        try {
            // SQL Injection vulnerability - concatenating user input directly
            String dbUrl = "jdbc:mysql://mysql-db:3306/users";
            Connection conn = DriverManager.getConnection(dbUrl, "root", DB_PASSWORD);
            Statement stmt = conn.createStatement();

            // Vulnerable SQL query - direct string concatenation
            String query = "SELECT * FROM users WHERE username='" + username + "' AND password='" + password + "'";
            ResultSet rs = stmt.executeQuery(query);

            if (rs.next()) {
                response.put("success", true);
                response.put("message", "Login successful");
                response.put("userId", rs.getString("user_id"));
                response.put("username", rs.getString("username"));
                response.put("email", rs.getString("email"));
                response.put("accountBalance", rs.getDouble("balance"));
                // Exposing sensitive PII data
                response.put("ssn", rs.getString("ssn"));
                response.put("creditCard", rs.getString("credit_card"));
            } else {
                response.put("success", false);
                response.put("message", "Invalid credentials");
            }

            rs.close();
            stmt.close();
            conn.close();

        } catch (Exception e) {
            // Exposing stack trace in response (SAST vulnerability)
            response.put("success", false);
            response.put("error", e.getMessage());
            response.put("stackTrace", e.getStackTrace());
        }

        return ResponseEntity.ok(response);
    }

    // User registration with plaintext password storage
    @PostMapping("/api/register")
    public ResponseEntity<Map<String, Object>> register(
            @RequestParam String username,
            @RequestParam String password,
            @RequestParam String email,
            @RequestParam String ssn,
            @RequestParam String creditCard) {

        Map<String, Object> response = new HashMap<>();

        try {
            // Connect to exposed database
            String dbUrl = "jdbc:mysql://mysql-db:3306/users";
            Connection conn = DriverManager.getConnection(dbUrl, "root", DB_PASSWORD);
            Statement stmt = conn.createStatement();

            // Generate random user ID and account balance
            String userId = "USER" + new Random().nextInt(100000);
            double balance = 1000.0 + (new Random().nextDouble() * 9000.0);

            // Storing password in plaintext (SAST vulnerability)
            // SQL Injection vulnerability
            String insertQuery = "INSERT INTO users (user_id, username, password, email, ssn, credit_card, balance) VALUES ('"
                + userId + "', '" + username + "', '" + password + "', '" + email + "', '" + ssn + "', '" + creditCard + "', " + balance + ")";

            stmt.executeUpdate(insertQuery);

            response.put("success", true);
            response.put("message", "User registered successfully");
            response.put("userId", userId);
            response.put("balance", balance);

            stmt.close();
            conn.close();

        } catch (Exception e) {
            response.put("success", false);
            response.put("error", e.getMessage());
        }

        return ResponseEntity.ok(response);
    }

    // Command injection vulnerability
    @GetMapping("/api/execute")
    public ResponseEntity<Map<String, Object>> executeCommand(@RequestParam String cmd) {
        Map<String, Object> response = new HashMap<>();

        try {
            // Command injection vulnerability - executing user input directly
            Process process = Runtime.getRuntime().exec(cmd);
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            StringBuilder output = new StringBuilder();
            String line;

            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }

            response.put("command", cmd);
            response.put("output", output.toString());
            response.put("exitCode", process.waitFor());

        } catch (Exception e) {
            response.put("error", e.getMessage());
        }

        return ResponseEntity.ok(response);
    }

    // Path traversal vulnerability
    @GetMapping("/api/readfile")
    public ResponseEntity<Map<String, Object>> readFile(@RequestParam String filename) {
        Map<String, Object> response = new HashMap<>();

        try {
            // Path traversal vulnerability - no input validation
            File file = new File(filename);
            BufferedReader reader = new BufferedReader(new java.io.FileReader(file));
            StringBuilder content = new StringBuilder();
            String line;

            while ((line = reader.readLine()) != null) {
                content.append(line).append("\n");
            }

            reader.close();

            response.put("filename", filename);
            response.put("content", content.toString());

        } catch (Exception e) {
            response.put("error", e.getMessage());
        }

        return ResponseEntity.ok(response);
    }

    // Insecure endpoint that exposes all secrets
    @GetMapping("/api/config")
    public ResponseEntity<Map<String, String>> getConfig() {
        Map<String, String> config = new HashMap<>();
        config.put("paymentServiceUrl", paymentServiceUrl);
        config.put("userServiceUrl", userServiceUrl);
        config.put("internalApiKey", INTERNAL_API_KEY);
        config.put("dbPassword", DB_PASSWORD);
        config.put("awsAccessKey", AWS_ACCESS_KEY);
        config.put("awsSecretKey", AWS_SECRET_KEY);
        config.put("stripeSecret", STRIPE_SECRET);
        config.put("jwtSecret", JWT_SECRET);
        return ResponseEntity.ok(config);
    }

    // SQL Injection and XSS vulnerable endpoint
    @GetMapping("/api/search")
    public ResponseEntity<String> search(@RequestParam String query) {
        try {
            String dbUrl = "jdbc:mysql://mysql-db:3306/users";
            Connection conn = DriverManager.getConnection(dbUrl, "root", DB_PASSWORD);
            Statement stmt = conn.createStatement();

            // SQL Injection vulnerability
            String sqlQuery = "SELECT username, email FROM users WHERE username LIKE '%" + query + "%'";
            ResultSet rs = stmt.executeQuery(sqlQuery);

            StringBuilder results = new StringBuilder("<html><body><h1>Search Results</h1>");
            while (rs.next()) {
                // XSS vulnerability - no output encoding
                results.append("<p>User: " + rs.getString("username") + " - " + rs.getString("email") + "</p>");
            }
            results.append("</body></html>");

            rs.close();
            stmt.close();
            conn.close();

            return ResponseEntity.ok(results.toString());

        } catch (Exception e) {
            return ResponseEntity.ok("Error: " + e.getMessage());
        }
    }

    // Debug endpoint that leaks all environment variables and secrets
    @GetMapping("/debug")
    public ResponseEntity<Map<String, Object>> debug() {
        Map<String, Object> debugInfo = new HashMap<>();
        debugInfo.put("environment", System.getenv());
        debugInfo.put("properties", System.getProperties());
        debugInfo.put("secrets", Map.of(
            "dbPassword", DB_PASSWORD,
            "awsAccessKey", AWS_ACCESS_KEY,
            "awsSecretKey", AWS_SECRET_KEY,
            "stripeSecret", STRIPE_SECRET
        ));
        return ResponseEntity.ok(debugInfo);
    }

    // Get user account info with no authentication
    @GetMapping("/api/account/{userId}")
    public ResponseEntity<Map<String, Object>> getAccount(@PathVariable String userId) {
        Map<String, Object> response = new HashMap<>();

        try {
            String dbUrl = "jdbc:mysql://mysql-db:3306/users";
            Connection conn = DriverManager.getConnection(dbUrl, "root", DB_PASSWORD);
            Statement stmt = conn.createStatement();

            // No authentication required - anyone can access any user's data
            String query = "SELECT * FROM users WHERE user_id='" + userId + "'";
            ResultSet rs = stmt.executeQuery(query);

            if (rs.next()) {
                // Exposing all PII without authentication
                response.put("userId", rs.getString("user_id"));
                response.put("username", rs.getString("username"));
                response.put("email", rs.getString("email"));
                response.put("ssn", rs.getString("ssn"));
                response.put("creditCard", rs.getString("credit_card"));
                response.put("balance", rs.getDouble("balance"));
                response.put("password", rs.getString("password")); // Exposing plaintext password!
            }

            rs.close();
            stmt.close();
            conn.close();

        } catch (Exception e) {
            response.put("error", e.getMessage());
        }

        return ResponseEntity.ok(response);
    }
}
