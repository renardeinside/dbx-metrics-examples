build-metrics:
	mvn clean package

local-test: build-metrics
	pytest --cov

deploy-with-jar: build-metrics
	dbx deploy --jobs=dbx-metrics-example
