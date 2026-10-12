package com.peertutorconnect.util;

import java.io.FileInputStream;
import java.io.InputStream;
import java.util.Properties;

public class AppConfig {

    private static final Properties PROPS = new Properties();

    static {
        try {
            String external = System.getenv("PTC_CONFIG");
            if (external != null && !external.isEmpty()) {
                try (InputStream in = new FileInputStream(external)) {
                    PROPS.load(in);
                }
            } else {
                try (InputStream in = AppConfig.class.getClassLoader()
                        .getResourceAsStream("config.properties")) {
                    if (in != null) {
                        PROPS.load(in);
                    }
                }
            }
        } catch (Exception e) {
            System.err.println("Could not load configuration: " + e.getMessage());
        }
    }

    public static String get(String key, String defaultValue) {
        String env = System.getenv(key.toUpperCase().replace('.', '_'));
        if (env != null && !env.isEmpty()) {
            return env;
        }
        String value = PROPS.getProperty(key);
        return (value != null && !value.trim().isEmpty()) ? value.trim() : defaultValue;
    }
}