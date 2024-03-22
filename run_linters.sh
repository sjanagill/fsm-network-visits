#!/usr/bin/env bash
if [ -f requirements_dev.txt ]; then pip install -r requirements_dev.txt --no-cache; fi

black --line-length=120 cloud_functions/adjlist_to_bq/
flake8 --config conf/flake8.cfg cloud_functions/adjlist_to_bq/
pylint --rcfile conf/pylintrc.cfg cloud_functions/adjlist_to_bq/
mypy --strict --config=conf/mypy.ini --allow-untyped-calls cloud_functions/adjlist_to_bq/

black --line-length=120 cloud_functions/visits_to_bq/
flake8 --config conf/flake8.cfg cloud_functions/visits_to_bq/
pylint --rcfile conf/pylintrc.cfg cloud_functions/visits_to_bq/
mypy --strict --config=conf/mypy.ini --allow-untyped-calls cloud_functions/visits_to_bq/