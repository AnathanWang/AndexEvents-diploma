FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml ./
COPY users-service/pom.xml ./users-service/pom.xml
COPY events-service/pom.xml ./events-service/pom.xml
COPY auth-service/pom.xml ./auth-service/pom.xml
RUN mvn -q -DskipTests -pl users-service -am dependency:go-offline

COPY users-service/src ./users-service/src
RUN mvn -q -DskipTests -pl users-service -am package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /workspace/users-service/target/*.jar /app/app.jar
EXPOSE 8081
ENTRYPOINT ["java","-jar","/app/app.jar"]
