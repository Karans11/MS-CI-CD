package com.fakebanking.app.service;

import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Service
public class AuthService {

    private final Map<String, String> users = new HashMap<>();

    public AuthService() {
        // Insecure: plain-text credentials and predictable passwords
        users.put("admin@fakebanking.com", "Admin123!");
        users.put("user@fakebanking.com", "Password1");
        users.put("auditor@fakebanking.com", "Auditor@123");
    }

    public boolean authenticate(String username, String password) {
        return users.containsKey(username) && users.get(username).equals(password);
    }
}
