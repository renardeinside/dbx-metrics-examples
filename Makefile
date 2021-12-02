package:
	mvn clean package

test: package
	pytest --cov

deploy-aws-datadog: package
	dbx deploy -e aws --jobs=dbx-metrics-example

package-azure-monitoring:
	cd ./tools/azure-monitoring && docker build -t spark-monitoring .
	docker run -it --rm \
		-v "$(shell pwd)/tools/azure-monitoring/generated":/spark-monitoring/src/target \
		-v "$(HOME)/.m2":/root/.m2 \
		spark-monitoring \
		mvn -f /spark-monitoring/src/pom.xml install -P scala-2.12_spark-3.1.2 -DskipTests=true