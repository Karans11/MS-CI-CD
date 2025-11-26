package com.fakebanking.payment.controller;

import com.fakebanking.payment.model.PaymentRequest;
import com.fakebanking.payment.service.PaymentService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/payments")
public class PaymentController {

    @Autowired
    private PaymentService paymentService;

    // Hardcoded payment gateway credentials (intentionally insecure)
    @Value("${payment.gateway.api.key:pk_test_fake_key_12345678}")
    private String paymentGatewayApiKey;

    @Value("${payment.gateway.secret:sk_test_fake_secret_87654321}")
    private String paymentGatewaySecret;

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "payment-service");
        return ResponseEntity.ok(response);
    }

    // Process payment without proper validation (insecure)
    @PostMapping("/process")
    public ResponseEntity<Map<String, Object>> processPayment(@RequestBody PaymentRequest request) {
        Map<String, Object> response = new HashMap<>();

        // No authentication or authorization check!
        // No input validation!

        try {
            String transactionId = paymentService.processPayment(request);
            response.put("status", "success");
            response.put("transactionId", transactionId);
            response.put("amount", request.getAmount());
            response.put("message", "Payment processed successfully");
        } catch (Exception e) {
            response.put("status", "error");
            response.put("error", e.getMessage());
            // Leaking stack trace (insecure)
            response.put("stackTrace", e.getStackTrace());
        }

        return ResponseEntity.ok(response);
    }

    // Vulnerable SQL injection endpoint
    @GetMapping("/history")
    public ResponseEntity<String> getPaymentHistory(@RequestParam String userId) {
        // SQL Injection vulnerability - intentional
        String result = paymentService.getPaymentHistory(userId);
        return ResponseEntity.ok(result);
    }

    // Exposed admin endpoint without authentication
    @PostMapping("/admin/refund")
    public ResponseEntity<Map<String, String>> refundPayment(@RequestParam String transactionId, @RequestParam double amount) {
        Map<String, String> response = new HashMap<>();
        // No authentication check - anyone can trigger refunds!
        response.put("status", "refunded");
        response.put("transactionId", transactionId);
        response.put("amount", String.valueOf(amount));
        return ResponseEntity.ok(response);
    }

    // Endpoint that exposes payment gateway credentials (highly insecure!)
    @GetMapping("/config")
    public ResponseEntity<Map<String, String>> getConfig() {
        Map<String, String> config = new HashMap<>();
        config.put("apiKey", paymentGatewayApiKey);
        config.put("secret", paymentGatewaySecret);
        config.put("webhookUrl", "https://payment-gateway.fake.com/webhook");
        config.put("merchantId", "MERCHANT_12345");
        return ResponseEntity.ok(config);
    }

    // Mass assignment vulnerability
    @PostMapping("/update")
    public ResponseEntity<Map<String, String>> updatePayment(@RequestBody Map<String, Object> updates) {
        // Accepting arbitrary fields without validation
        Map<String, String> response = new HashMap<>();
        response.put("status", "updated");
        response.put("message", "Payment updated with: " + updates.toString());
        return ResponseEntity.ok(response);
    }
}
