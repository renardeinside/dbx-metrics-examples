package:
	mvn clean package

test: package
	pytest --cov

deploy: package
	dbx deploy --jobs=dbx-metrics-example
