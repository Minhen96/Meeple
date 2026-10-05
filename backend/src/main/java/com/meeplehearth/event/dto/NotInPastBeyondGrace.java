package com.meeplehearth.event.dto;

import jakarta.validation.Constraint;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import jakarta.validation.Payload;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.time.Duration;
import java.time.Instant;

/**
 * The instant may be at most {@link #GRACE} in the past, allowing slight client clock drift
 * (FEATURES section 4.1: {@code scheduledAt >= NOW() - 5 minutes}). {@code null} is valid; combine
 * with {@code @NotNull} when the field is required.
 */
@Documented
@Constraint(validatedBy = NotInPastBeyondGrace.Validator.class)
@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.RECORD_COMPONENT})
@Retention(RetentionPolicy.RUNTIME)
public @interface NotInPastBeyondGrace {

    Duration GRACE = Duration.ofMinutes(5);

    String message() default "must not be more than 5 minutes in the past";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};

    class Validator implements ConstraintValidator<NotInPastBeyondGrace, Instant> {

        /** Shared with the service layer, which validates internally built requests too. */
        public static boolean isAllowed(Instant value, Instant now) {
            return value == null || !value.isBefore(now.minus(GRACE));
        }

        @Override
        public boolean isValid(Instant value, ConstraintValidatorContext context) {
            return isAllowed(value, Instant.now());
        }
    }
}
