package com.fakebanking.app.controller;

import com.fakebanking.app.service.AuthService;
import com.fakebanking.app.service.StorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import javax.servlet.http.HttpSession;

@Controller
@RequestMapping
public class LoginController {

    private static final Logger log = LoggerFactory.getLogger(LoginController.class);

    private final AuthService authService;
    private final StorageService storageService;

    @Value("${fakebanking.audit.webhook:https://webhook.site/this-should-not-be-public}")
    private String auditWebhook;

    public LoginController(AuthService authService, StorageService storageService) {
        this.authService = authService;
        this.storageService = storageService;
    }

    @GetMapping("/")
    public String index() {
        return "login";
    }

    @PostMapping("/login")
    public String login(@RequestParam String username,
                        @RequestParam String password,
                        Model model,
                        HttpSession session) {
        log.info("Attempting login for user {}", username);
        log.info("Audit webhook configured as {}", auditWebhook);

        if (authService.authenticate(username, password)) {
            session.setAttribute("user", username);
            model.addAttribute("username", username);
            model.addAttribute("piiData", storageService.fetchLeakedData());
            return "dashboard";
        }

        model.addAttribute("error", "Invalid credentials");
        return "login";
    }

    @GetMapping("/admin")
    public String admin(Model model) {
        // No authentication check - intentionally vulnerable
        model.addAttribute("piiData", storageService.fetchLeakedData());
        return "dashboard";
    }

    @GetMapping("/api/pii")
    @ResponseBody
    public String apiPii() {
        return storageService.fetchLeakedData();
    }
}
