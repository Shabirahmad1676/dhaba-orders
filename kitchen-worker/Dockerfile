FROM maven:3-eclipse-temurin-21-alpine AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B package -DskipTests

FROM eclipse-temurin:21-jre-alpine
ARG GIT_SHA=dev
ENV GIT_SHA=${GIT_SHA}
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /app/target/kitchen-worker-1.0.0.jar /app/worker.jar

USER appuser

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD ["java", "-jar", "/app/worker.jar", "--healthcheck"]

ENTRYPOINT ["java", "-jar", "/app/worker.jar"]
