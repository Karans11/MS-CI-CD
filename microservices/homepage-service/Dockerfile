FROM eclipse-temurin:11-jre-alpine

# Running as root (intentionally insecure)
RUN mkdir -p /app && chmod -R 777 /app
WORKDIR /app

COPY target/homepage-service-0.1.0.jar app.jar

# Hardcoded environment variables with secrets
ENV JAVA_OPTS="-Xms256m -Xmx512m"
ENV INTERNAL_API_KEY="sk-fake-banking-internal-key-12345"
ENV DB_PASSWORD="SuperSecretPassword123"

EXPOSE 8081

# Running as root user
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
