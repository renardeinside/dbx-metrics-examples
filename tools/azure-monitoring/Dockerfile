FROM alpine/git AS cloner
WORKDIR /
RUN git clone https://github.com/mspnp/spark-monitoring.git

FROM maven:3.6.1-jdk-8 as builder
COPY --from=cloner /spark-monitoring /spark-monitoring
RUN chmod +x spark-monitoring/build.sh


