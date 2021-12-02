package:
	mvn clean package

test: package
	pytest --cov

deploy-aws-datadog: package
	dbx deploy -e aws --jobs=dbx-metrics-example
