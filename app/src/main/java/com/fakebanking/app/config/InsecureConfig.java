package com.fakebanking.app.config;

public class InsecureConfig {

    // Hard-coded Azure service principal credentials (intentionally insecure)
    public static final String AZURE_CLIENT_ID = "3f3e8ac9-ffff-4444-bbbb-1234567890ab";
    public static final String AZURE_CLIENT_SECRET = "P@ssw0rd-ThisIsHardCodedAndBad!";
    public static final String AZURE_TENANT_ID = "66bbf43f-e999-1111-aaaa-abcdef123456";

    // Storage account info exposed directly in code
    public static final String STORAGE_ACCOUNT_URL = "https://fakebankingstorage.blob.core.windows.net/leaked-data/personal-info.json";
    public static final String STORAGE_SAS_TOKEN = "?sp=rl&st=2024-01-01T00:00:00Z&se=2030-01-01T00:00:00Z&spr=https&sv=2021-06-08&sr=b&sig=ThisTokenShouldNotBeHere";

    private InsecureConfig() {
        // utility
    }
}
