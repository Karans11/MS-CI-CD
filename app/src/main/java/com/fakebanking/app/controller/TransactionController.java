package com.fakebanking.app.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TransactionController {

    private static final Logger log = LoggerFactory.getLogger(TransactionController.class);

    @GetMapping("/transfer")
    public String transfer(@RequestParam String fromAccount,
                           @RequestParam String toAccount,
                           @RequestParam String amount) {
        // SQL injection vulnerability intentionally left in place
        String sql = "UPDATE accounts SET balance = balance - " + amount + " WHERE account_number = '" + fromAccount + "'; "
                + "UPDATE accounts SET balance = balance + " + amount + " WHERE account_number = '" + toAccount + "';";
        log.warn("Executing SQL without sanitization: {}", sql);
        return "Transfer queued with raw SQL: " + sql;
    }
}
