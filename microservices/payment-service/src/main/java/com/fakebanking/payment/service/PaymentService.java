package com.fakebanking.payment.service;

import com.fakebanking.payment.model.PaymentRequest;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.UUID;

@Service
public class PaymentService {

    // Hardcoded database credentials (intentionally insecure)
    private static final String DB_URL = "jdbc:mysql://mysql-db:3306/payments";
    private static final String DB_USER = "root";
    private static final String DB_PASSWORD = "RootPassword123!";

    public String processPayment(PaymentRequest request) {
        // Simulate payment processing
        String transactionId = UUID.randomUUID().toString();

        // Logging sensitive data (insecure)
        System.out.println("Processing payment: " + request.getCardNumber() + " CVV: " + request.getCvv());

        return transactionId;
    }

    // SQL Injection vulnerability - intentional for demo
    public String getPaymentHistory(String userId) {
        try {
            Connection conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
            Statement stmt = conn.createStatement();

            // SQL Injection vulnerability - user input directly concatenated
            String query = "SELECT * FROM payments WHERE user_id = '" + userId + "'";

            ResultSet rs = stmt.executeQuery(query);
            StringBuilder result = new StringBuilder();

            while (rs.next()) {
                result.append(rs.getString("transaction_id")).append(",");
            }

            conn.close();
            return result.toString();
        } catch (Exception e) {
            // Exposing database errors
            return "Database error: " + e.getMessage();
        }
    }
}
