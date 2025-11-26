FROM eclipse-temurin:11-jre-alpine

# Running as root (intentionally insecure)
RUN mkdir -p /app && chmod -R 777 /app
WORKDIR /app

COPY target/user-database-service-0.1.0.jar app.jar

# Hardcoded environment variables with secrets
ENV JAVA_OPTS="-Xms256m -Xmx512m"
ENV DB_URL="jdbc:mysql://mysql-db:3306/users"
ENV DB_USER="root"
ENV DB_PASSWORD="RootPassword123!"
ENV ADMIN_USERNAME="admin"
ENV ADMIN_PASSWORD="admin123"
ENV ADMIN_TOKEN="admin-token-12345"

EXPOSE 8083

# Running as root user
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
