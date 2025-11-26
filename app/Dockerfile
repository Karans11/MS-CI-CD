FROM openjdk:11-jre-slim

# Running as root with world-writable app directory (intentionally insecure)
RUN mkdir -p /app && chmod -R 777 /app
WORKDIR /app

COPY target/fake-banking-app-0.1.0.jar app.jar

ENV JAVA_OPTS="-Xms256m -Xmx512m -Dspring.profiles.active=default"

EXPOSE 80

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
