package com.meeplehearth.common.advice;

import com.meeplehearth.common.dto.ApiResponse;
import com.meeplehearth.common.dto.ErrorResponse;
import com.meeplehearth.common.dto.PageResponse;
import org.springframework.core.MethodParameter;
import org.springframework.http.MediaType;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseBodyAdvice;

@RestControllerAdvice(basePackages = "com.meeplehearth")
public class ResponseWrappingAdvice implements ResponseBodyAdvice<Object> {

    @Override
    public boolean supports(MethodParameter returnType, Class<? extends HttpMessageConverter<?>> converterType) {
        // Only process our own controllers, not Actuator or SpringDoc
        String className = returnType.getDeclaringClass().getName();
        return className.startsWith("com.meeplehearth") &&
               !className.contains("actuator");
    }

    @Override
    public Object beforeBodyWrite(
            Object body,
            MethodParameter returnType,
            MediaType selectedContentType,
            Class<? extends HttpMessageConverter<?>> selectedConverterType,
            ServerHttpRequest request,
            ServerHttpResponse response) {

        // Already wrapped — pass through as-is
        if (body instanceof ApiResponse<?>) return body;
        if (body instanceof PageResponse<?>) return body;
        if (body instanceof ErrorResponse) return body;

        // Null body (e.g. 204 No Content) — pass through
        if (body == null) return null;

        // Wrap everything else in { "data": ... }
        return ApiResponse.of(body);
    }
}
