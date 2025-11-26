FROM eclipse-temurin:11-jre-alpine

# Running as root (intentionally insecure)
RUN mkdir -p /app && chmod -R 777 /app
WORKDIR /app

COPY target/payment-service-0.1.0.jar app.jar

# Hardcoded environment variables with secrets
ENV JAVA_OPTS="-Xms256m -Xmx512m"
ENV DB_PASSWORD="RootPassword123!"
ENV PAYMENT_GATEWAY_SECRET="sk_test_fake_secret_87654321"
ENV PAYMENT_API_KEY="pk_test_fake_key_12345678"

EXPOSE 8082

# Running as root user
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
