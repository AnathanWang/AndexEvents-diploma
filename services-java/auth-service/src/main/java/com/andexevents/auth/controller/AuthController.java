package com.andexevents.auth.controller;

import com.andexevents.auth.api.ApiResponse;
import com.andexevents.auth.auth.AuthContext;
import com.andexevents.auth.auth.AuthFilter;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    @GetMapping("/me")
    public ResponseEntity<ApiResponse<Map<String, Object>>> me(HttpServletRequest request) {
        AuthContext auth = (AuthContext) request.getAttribute(AuthFilter.ATTR);
        if (auth == null || auth.uid() == null || auth.uid().isBlank()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Unauthorized: Invalid token"));
        }

        return ResponseEntity.ok(ApiResponse.ok(Map.of(
                "uid", auth.uid(),
                "email", auth.email(),
                "userId", auth.userId()
        )));
    }

    @PostMapping("/validate")
    public ResponseEntity<ApiResponse<Map<String, Object>>> validate(HttpServletRequest request) {
        return me(request);
    }
}
