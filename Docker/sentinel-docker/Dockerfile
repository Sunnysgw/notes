FROM openjdk:11

EXPOSE 8850

COPY sentinel-dashboard-1.8.1.jar /

RUN apt install -y  install net-tools

RUN apt install -y install vim

ENTRYPOINT ["java", "-Dserver.port=8850", "-jar", "/sentinel-dashboard-1.8.1.jar"]
