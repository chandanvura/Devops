# ─────────────────────────────────────────────
# Stage 1 — Build  (has Maven + JDK, discarded after)
# ─────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /app

# Copy pom first — Docker caches this layer
# Only re-downloads dependencies when pom.xml changes
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Copy source and build JAR
COPY src ./src
RUN mvn clean package -DskipTests

# ─────────────────────────────────────────────
# Stage 2 — Runtime  (tiny JRE only, no build tools)
# ─────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Create non-root user — security best practice
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only the JAR from the build stage
COPY --from=build /app/target/devops-app-*.jar app.jar

# Set ownership
RUN chown appuser:appgroup app.jar

# Switch to non-root user
USER appuser

EXPOSE 8080

# Health check — used by Docker Compose and K8s readiness probe
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -q --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "app.jar"]
