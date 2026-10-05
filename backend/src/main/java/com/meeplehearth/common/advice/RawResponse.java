package com.meeplehearth.common.advice;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Opts a controller (or one handler method) out of the {@code {"data": ...}} wrapper applied by
 * {@link ResponseWrappingAdvice}, for documents whose format is fixed by a third party
 * (for example the /.well-known files read by iOS and Android).
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.TYPE, ElementType.METHOD})
public @interface RawResponse {
}
