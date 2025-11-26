package com.fakebanking.userdb.service;

import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

@Service
public class UserService {

    // Hardcoded database credentials (intentionally insecure)
    private static final String DB_URL = "jdbc:mysql://mysql-db:3306/users";
    private static final String DB_USER = "root";
    private static final String DB_PASSWORD = "RootPassword123!";

    // SQL Injection vulnerability - intentional for demo
    public String getUserById(String userId) {
        try {
            Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
            Statement stmt = conn.createStatement();

            // SQL Injection vulnerability - user input directly concatenated
            String query = "SELECT * FROM users WHERE user_id = '" + userId + "'";

            ResultSet rs = stmt.executeQuery(query);
            StringBuilder result = new StringBuilder();

            while (rs.next()) {
                result.append("User: ").append(rs.getString("username"))
                      .append(", Email: ").append(rs.getString("email"))
                      .append(", Password: ").append(rs.getString("password")) // Exposing passwords!
                      .append(", SSN: ").append(rs.getString("ssn")) // Exposing PII!
                      .append(", Account: ").append(rs.getString("account_number"));
            }

            conn.close();
            return result.toString();
        } catch (Exception e) {
            // Exposing database errors
            return "Database error: " + e.getMessage() + " | " + e.getStackTrace()[0];
        }
    }

    public String getAllUsers() {
        try {
            Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
            Statement stmt = conn.createStatement();

            String query = "SELECT * FROM users";
            ResultSet rs = stmt.executeQuery(query);
            StringBuilder result = new StringBuilder();

            while (rs.next()) {
                result.append("User: ").append(rs.getString("username"))
                      .append(", Email: ").append(rs.getString("email"))
                      .append(", Password: ").append(rs.getString("password"))
                      .append(", SSN: ").append(rs.getString("ssn"))
                      .append(", DOB: ").append(rs.getString("date_of_birth"))
                      .append(", Account: ").append(rs.getString("account_number"))
                      .append("\n");
            }

            conn.close();
            return result.toString();
        } catch (Exception e) {
            return "Database error: " + e.getMessage();
        }
    }

    public String searchUsers(String query) {
        try {
            Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
            Statement stmt = conn.createStatement();

            // SQL Injection vulnerability
            String sql = "SELECT * FROM users WHERE username LIKE '%" + query + "%' OR email LIKE '%" + query + "%'";

            ResultSet rs = stmt.executeQuery(sql);
            StringBuilder result = new StringBuilder();

            while (rs.next()) {
                result.append(rs.getString("username")).append(",");
            }

            conn.close();
            return result.toString();
        } catch (Exception e) {
            return "Database error: " + e.getMessage();
        }
    }

    public String dumpDatabase() {
        try {
            Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
            Statement stmt = conn.createStatement();

            // Complete database dump with all sensitive data
            String query = "SELECT user_id, username, password, email, ssn, date_of_birth, account_number, credit_card, cvv FROM users";
            ResultSet rs = stmt.executeQuery(query);
            StringBuilder result = new StringBuilder();
            result.append("=== COMPLETE DATABASE DUMP ===\n");

            while (rs.next()) {
                result.append("UserID: ").append(rs.getString("user_id"))
                      .append(" | Username: ").append(rs.getString("username"))
                      .append(" | Password: ").append(rs.getString("password"))
                      .append(" | Email: ").append(rs.getString("email"))
                      .append(" | SSN: ").append(rs.getString("ssn"))
                      .append(" | DOB: ").append(rs.getString("date_of_birth"))
                      .append(" | Account: ").append(rs.getString("account_number"))
                      .append(" | CC: ").append(rs.getString("credit_card"))
                      .append(" | CVV: ").append(rs.getString("cvv"))
                      .append("\n");
            }

            conn.close();
            return result.toString();
        } catch (Exception e) {
            return "Database dump failed: " + e.getMessage();
        }
    }
}
