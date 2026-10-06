FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY . .
# Tests and the coverage gate run in CI; the image only needs the executable jar
RUN chmod +x gradlew && ./gradlew bootJar --no-daemon

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S app && adduser -S app -G app
COPY --from=build /app/build/libs/*.jar app.jar
USER app
# Railway sets PORT; the app binds to it (default 8080)
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
