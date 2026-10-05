package com.meeplehearth.common;

import com.meeplehearth.common.advice.ResponseWrappingAdvice;
import com.meeplehearth.common.dto.ApiResponse;
import com.meeplehearth.common.dto.ErrorResponse;
import com.meeplehearth.common.dto.PageMeta;
import com.meeplehearth.common.dto.PageResponse;
import com.meeplehearth.common.exception.ApiException;
import com.meeplehearth.common.exception.GlobalExceptionHandler;
import com.meeplehearth.common.ratelimit.RedisRateLimiter;
import org.junit.jupiter.api.Test;
import org.springframework.core.MethodParameter;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.time.Duration;
import java.util.List;
import java.util.function.Function;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class CommonUnitTest {

    // ------------------------------------------------------------------ ApiException

    @Test
    void apiExceptionFactoriesCarryStatusCodeAndMessage() {
        record Case(ApiException ex, HttpStatus status, String code) { }
        List<Case> cases = List.of(
                new Case(ApiException.notFound("m"), HttpStatus.NOT_FOUND, "NOT_FOUND"),
                new Case(ApiException.notFound("GAME_NOT_FOUND", "m"), HttpStatus.NOT_FOUND, "GAME_NOT_FOUND"),
                new Case(ApiException.badRequest("m"), HttpStatus.BAD_REQUEST, "BAD_REQUEST"),
                new Case(ApiException.badRequest("BAD", "m"), HttpStatus.BAD_REQUEST, "BAD"),
                new Case(ApiException.forbidden("m"), HttpStatus.FORBIDDEN, "FORBIDDEN"),
                new Case(ApiException.forbidden("NOPE", "m"), HttpStatus.FORBIDDEN, "NOPE"),
                new Case(ApiException.conflict("m"), HttpStatus.CONFLICT, "CONFLICT"),
                new Case(ApiException.conflict("DUP", "m"), HttpStatus.CONFLICT, "DUP"),
                new Case(ApiException.unauthorized("m"), HttpStatus.UNAUTHORIZED, "UNAUTHORIZED"),
                new Case(ApiException.unauthorized("EXPIRED", "m"), HttpStatus.UNAUTHORIZED, "EXPIRED"),
                new Case(ApiException.tooManyRequests("SLOW_DOWN", "m"), HttpStatus.TOO_MANY_REQUESTS, "SLOW_DOWN"));

        for (Case c : cases) {
            assertThat(c.ex().getStatus()).as(c.code()).isEqualTo(c.status());
            assertThat(c.ex().getCode()).isEqualTo(c.code());
            assertThat(c.ex().getMessage()).isEqualTo("m");
        }
    }

    // ------------------------------------------------------------------ GlobalExceptionHandler

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void apiExceptionsMapToTheirStatusAndCode() {
        ResponseEntity<ErrorResponse> response = handler.handleApiException(ApiException.conflict("TAKEN", "Taken"));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(response.getBody()).isEqualTo(new ErrorResponse("Taken", "TAKEN"));
    }

    @Test
    void validationErrorsListEveryFieldError() throws Exception {
        BeanPropertyBindingResult binding = new BeanPropertyBindingResult(new Object(), "request");
        binding.addError(new org.springframework.validation.FieldError("request", "email", "must be a well-formed email address"));
        binding.addError(new org.springframework.validation.FieldError("request", "password", "size must be between 8 and 128"));
        MethodParameter parameter = new MethodParameter(
                CommonUnitTest.class.getDeclaredMethod("validationErrorsListEveryFieldError"), -1);

        ResponseEntity<ErrorResponse> response = handler.handleValidation(new MethodArgumentNotValidException(parameter, binding));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).isEqualTo(new ErrorResponse(
                "email: must be a well-formed email address, password: size must be between 8 and 128", "VALIDATION_ERROR"));
    }

    @Test
    void unknownResourcesAre404AndEverythingElseIsAnOpaque500() {
        ResponseEntity<ErrorResponse> notFound = handler.handleNoResource(new NoResourceFoundException(HttpMethod.GET, "x"));
        assertThat(notFound.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(notFound.getBody()).isEqualTo(new ErrorResponse("Resource not found", "NOT_FOUND"));

        ResponseEntity<ErrorResponse> internal = handler.handleGeneral(new IllegalStateException("db password is hunter2"));
        assertThat(internal.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        // Internal details never leak to the client
        assertThat(internal.getBody()).isEqualTo(new ErrorResponse("An unexpected error occurred", "INTERNAL_ERROR"));
    }

    // ------------------------------------------------------------------ ResponseWrappingAdvice

    private final ResponseWrappingAdvice advice = new ResponseWrappingAdvice();

    static class Endpoints {
        public String value() {
            return "";
        }
    }

    private static MethodParameter returnTypeOf(Class<?> type) throws Exception {
        return new MethodParameter(type.getMethod(type == Endpoints.class ? "value" : "toString"), -1);
    }

    @Test
    void onlyOurOwnControllersAreWrapped() throws Exception {
        assertThat(advice.supports(returnTypeOf(Endpoints.class), MappingJackson2HttpMessageConverter.class)).isTrue();
        // Framework and library endpoints (actuator, springdoc...) keep their own format
        assertThat(advice.supports(returnTypeOf(Object.class), MappingJackson2HttpMessageConverter.class)).isFalse();
        MethodParameter actuatorLike = mock(MethodParameter.class);
        when(actuatorLike.getDeclaringClass()).thenAnswer(inv -> actuatorEndpoint.class);
        assertThat(advice.supports(actuatorLike, MappingJackson2HttpMessageConverter.class)).isFalse();
    }

    @Test
    void bodiesAreWrappedInDataUnlessAlreadyEnveloped() {
        ApiResponse<String> wrapped = ApiResponse.of("x");
        PageResponse<String> page = PageResponse.empty();
        ErrorResponse error = new ErrorResponse("e", "E");

        assertThat(write(wrapped)).isSameAs(wrapped);
        assertThat(write(page)).isSameAs(page);
        assertThat(write(error)).isSameAs(error);
        assertThat(write(null)).isNull();
        assertThat(write(java.util.Map.of("k", 1))).isEqualTo(ApiResponse.of(java.util.Map.of("k", 1)));
        assertThat(write("text")).isEqualTo(new ApiResponse<>("text"));
    }

    private Object write(Object body) {
        return advice.beforeBodyWrite(body, null, MediaType.APPLICATION_JSON, MappingJackson2HttpMessageConverter.class,
                null, null);
    }

    // ------------------------------------------------------------------ PageResponse

    @Test
    void pageResponseUsesOneBasedPagesAndHasMore() {
        PageImpl<Integer> firstOfThree = new PageImpl<>(List.of(1, 2), PageRequest.of(0, 2), 5);

        PageResponse<Integer> raw = PageResponse.of(firstOfThree);
        assertThat(raw.data()).containsExactly(1, 2);
        assertThat(raw.meta()).isEqualTo(new PageMeta(1, 2, 5, true));

        PageImpl<Integer> last = new PageImpl<>(List.of(5), PageRequest.of(2, 2), 5);
        PageResponse<String> mapped = PageResponse.of(last, (Function<Integer, String>) i -> "#" + i);
        assertThat(mapped.data()).containsExactly("#5");
        assertThat(mapped.meta()).isEqualTo(new PageMeta(3, 2, 5, false));

        assertThat(PageResponse.<String>empty()).isEqualTo(new PageResponse<>(List.of(), new PageMeta(1, 20, 0, false)));
    }

    // ------------------------------------------------------------------ RedisRateLimiter

    @Test
    @SuppressWarnings("unchecked")
    void rateLimiterTreatsAMissingScriptResultAsZero() {
        StringRedisTemplate template = mock(StringRedisTemplate.class);
        when(template.execute(any(RedisScript.class), anyList(), anyString())).thenReturn(null);
        RedisRateLimiter limiter = new RedisRateLimiter(template);

        assertThat(limiter.increment("k", Duration.ofSeconds(1))).isZero();
        assertThat(limiter.tryAcquire("k", 0, Duration.ofSeconds(1))).isTrue();
    }

    /** Name contains "actuator", like controllers of the actuator packages. */
    @SuppressWarnings("checkstyle:TypeName")
    static class actuatorEndpoint {
    }
}
