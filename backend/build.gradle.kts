plugins {
	java
	id("org.springframework.boot") version "3.4.3"
	id("io.spring.dependency-management") version "1.1.7"
	jacoco
}

group = "com.meeplehearth"
version = "0.0.1-SNAPSHOT"
description = "Meeple Board Game Community API"

java {
	toolchain {
		languageVersion = JavaLanguageVersion.of(21)
	}
}

configurations {
	compileOnly {
		extendsFrom(configurations.annotationProcessor.get())
	}
}

repositories {
	mavenCentral()
}

dependencies {
	// Spring Boot starters
	implementation("org.springframework.boot:spring-boot-starter-actuator")
	implementation("org.springframework.boot:spring-boot-starter-data-jpa")
	implementation("org.springframework.boot:spring-boot-starter-data-redis")
	implementation("org.springframework.boot:spring-boot-starter-security")
	implementation("org.springframework.boot:spring-boot-starter-validation")
	implementation("org.springframework.boot:spring-boot-starter-web")
	implementation("org.springframework.boot:spring-boot-starter-webflux")
	implementation("org.springframework.boot:spring-boot-starter-websocket")
	implementation("org.springframework.boot:spring-boot-starter-mail")
	implementation("org.springframework.boot:spring-boot-starter-cache")

	// Database
	runtimeOnly("org.postgresql:postgresql")
	implementation("org.flywaydb:flyway-core")
	implementation("org.flywaydb:flyway-database-postgresql")

	// JWT
	implementation("io.jsonwebtoken:jjwt-api:0.12.6")
	runtimeOnly("io.jsonwebtoken:jjwt-impl:0.12.6")
	runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.12.6")

	// Cloudflare R2 (S3-compatible)
	implementation(platform("software.amazon.awssdk:bom:2.29.0"))
	implementation("software.amazon.awssdk:s3")

	// Resilience4j circuit breakers
	implementation("io.github.resilience4j:resilience4j-spring-boot3:2.2.0")
	implementation("io.github.resilience4j:resilience4j-reactor:2.2.0")

	// Load .env file in local dev (safe no-op if file doesn't exist)
	implementation("me.paulschwarz:spring-dotenv:4.0.0")

	// Google OAuth (ID token verification). Versions aligned with firebase-admin's: the dependency
	// management plugin pins a direct dependency's version for transitive users too.
	implementation("com.google.api-client:google-api-client:2.7.2")
	implementation("com.google.http-client:google-http-client-gson:2.2.0")

	// API documentation
	implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.8.6")

	// CSV parsing (import-time only)
	implementation("org.apache.commons:commons-csv:1.12.0")

	// AI — rulebook ingestion
	implementation("org.apache.pdfbox:pdfbox:3.0.3")   // PDF text extraction
	implementation("org.jsoup:jsoup:1.18.1")            // 1jour1jeu HTML scraping

	// Push notifications (FCM). Inert until FIREBASE_SERVICE_ACCOUNT_JSON is set.
	implementation("com.google.firebase:firebase-admin:9.11.0")

	// Observability: Sentry error tracking (no-op without SENTRY_DSN), JSON logs in prod
	implementation("io.sentry:sentry-spring-boot-starter-jakarta:7.22.6")
	implementation("net.logstash.logback:logstash-logback-encoder:8.0")

	// Lombok
	compileOnly("org.projectlombok:lombok")
	annotationProcessor("org.projectlombok:lombok")

	// Test
	testImplementation("org.springframework.boot:spring-boot-starter-test")
	testImplementation("io.projectreactor:reactor-test")
	testImplementation("org.springframework.security:spring-security-test")
	testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
	testImplementation("com.squareup.okhttp3:okhttp-tls:4.12.0")
	testImplementation("org.awaitility:awaitility")
	testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
	useJUnitPlatform()
}

jacoco {
	toolVersion = "0.8.12"
}

// Only the executable Spring Boot jar is needed; the plain jar made `COPY *.jar` in the
// Dockerfile match two files
tasks.jar {
	enabled = false
}

tasks.test {
	finalizedBy(tasks.jacocoTestReport)
}

tasks.jacocoTestReport {
	dependsOn(tasks.test)
	reports {
		xml.required = true
		html.required = true
	}
}

// CLAUDE.md requires at least 70% line coverage; the suite sits well above that, so the
// gate is set higher to catch regressions. Runs as part of `check` (and therefore `build`).
tasks.jacocoTestCoverageVerification {
	dependsOn(tasks.test)
	violationRules {
		rule {
			limit {
				counter = "LINE"
				value = "COVEREDRATIO"
				minimum = "0.85".toBigDecimal()
			}
			limit {
				counter = "BRANCH"
				value = "COVEREDRATIO"
				minimum = "0.75".toBigDecimal()
			}
		}
	}
}

tasks.check {
	dependsOn(tasks.jacocoTestCoverageVerification)
}
