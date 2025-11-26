package com.fakebanking.app.service;

import com.fakebanking.app.config.InsecureConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class StorageService {

    private static final Logger log = LoggerFactory.getLogger(StorageService.class);

    private final RestTemplate restTemplate = new RestTemplate();

    public String fetchLeakedData() {
        String targetUrl = InsecureConfig.STORAGE_ACCOUNT_URL + InsecureConfig.STORAGE_SAS_TOKEN;
        log.info("Fetching PII from public blob using URL {}", targetUrl);

        ResponseEntity<String> response = restTemplate.getForEntity(targetUrl, String.class);
        return response.getBody();
    }
}
