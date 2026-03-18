FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml ./
COPY users-service/pom.xml ./users-service/pom.xml
COPY events-service/pom.xml ./events-service/pom.xml
COPY auth-service/pom.xml ./auth-service/pom.xml
RUN mvn -q -DskipTests -pl auth-service -am dependency:go-offline

COPY auth-service/src ./auth-service/src
RUN mvn -q -DskipTests -pl auth-service -am package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /workspace/auth-service/target/*.jar /app/app.jar
EXPOSE 8083
ENTRYPOINT ["java","-jar","/app/app.jar"]
