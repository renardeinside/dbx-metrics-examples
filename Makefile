package:
	mvn clean package

test: package
	pytest --cov

deploy-aws-datadog: package
	dbx deploy -e aws --jobs=dbx-metrics-example

launch-aws-datadog:
	dbx launch -e aws --jobs=dbx-metrics-example --trace

package-azure-monitoring:
	rm -rf ./tools/azure-monitoring/generated
	cd ./tools/azure-monitoring && docker build -t spark-monitoring .
	docker run -it --rm \
		-v "$(shell pwd)/tools/azure-monitoring/generated":/spark-monitoring/src/target \
		-v "$(HOME)/.m2":/root/.m2 \
		spark-monitoring \
		mvn -f /spark-monitoring/src/pom.xml install -P scala-2.12_spark-3.1.2 -DskipTests=true

deploy-azure:
	dbx deploy -e azure --jobs=dbx-metrics-example

launch-azure:
	dbx launch -e azure --job=dbx-metrics-example --trace


deploy-gcp-datadog: package
	dbx deploy -e gcp --jobs=dbx-metrics-example

launch-gcp-datadog:
	dbx launch -e gcp --job=dbx-metrics-example --trace