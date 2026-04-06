package com.devops.app;

import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.HashMap;

@RestController
@RequestMapping("/api")
public class AppController {

    private static final String VERSION = System.getenv().getOrDefault("APP_VERSION", "1.0.0");
    private static final String ENV     = System.getenv().getOrDefault("APP_ENV", "local");

    @GetMapping("/hello")
    public ResponseEntity<Map<String, String>> hello() {
        Map<String, String> resp = new HashMap<>();
        resp.put("message",   "Hello from DevOps Project!");
        resp.put("version",   VERSION);
        resp.put("env",       ENV);
        resp.put("timestamp", LocalDateTime.now().toString());
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> resp = new HashMap<>();
        resp.put("status",  "UP");
        resp.put("service", "devops-app");
        resp.put("version", VERSION);
        return ResponseEntity.ok(resp);
    }

    @GetMapping("/info")
    public ResponseEntity<Map<String, String>> info() {
        Map<String, String> resp = new HashMap<>();
        resp.put("app",         "devops-app");
        resp.put("description", "Production-grade DevOps demo project");
        resp.put("stack",       "Java 17 / Spring Boot / Docker / K8s / Jenkins / Terraform");
        resp.put("env",         ENV);
        return ResponseEntity.ok(resp);
    }
}
