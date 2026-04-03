package com.meeplehearth.user.controller;

import com.meeplehearth.user.service.UserService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/users")
public class AdminUserController {

    private final UserService userService;

    public AdminUserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/{userId}/promote")
    public ResponseEntity<Void> promoteToAdmin(@PathVariable UUID userId) {
        userService.promoteToAdmin(userId);
        return ResponseEntity.noContent().build();
    }
}
