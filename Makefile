SHELL := /bin/bash
.PHONY: all citest clean mypy dist docs install pep8 publish run-pre-commit run-tox setup-pre-commit test test_functional test_only test_redis test_vault help coverage-report

help:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

all: clean install run-pre-commit test test_functional coverage-report

test_functional:
	./tests_functional/runtests.py

test_vault:
	./tests_functional/test_vault.sh

test_redis:
	./tests_functional/test_redis.sh

watch:
	ls **/**.py | entr py.test -m "not integration" -s -vvv -l --tb=long --maxfail=1 tests/

watch_django:
	ls {**/**.py,~/.virtualenvs/dynaconf/**/**.py,.venv/**/**.py} | PYTHON_PATH=. DJANGO_SETTINGS_MODULE=foo.settings entr tests_functional/django_example/manage.py test polls -v 2

watch_coverage:
	ls {**/**.py,~/.virtualenvs/dynaconf/**/**.py} | entr -s "make test;coverage html"

test_only:
	py.test -m "not integration" -v --cov-config .coveragerc --cov=dynaconf -l --tb=short --maxfail=1 tests/
	coverage xml

test_integration:
	py.test -m integration -v --cov-config .coveragerc --cov=dynaconf --cov-append -l --tb=short --maxfail=1 tests/
	coverage xml

coverage-report:
	coverage report

mypy:
	mypy dynaconf/ --exclude '^dynaconf/vendor*'

test: pep8 mypy test_only

citest:
	py.test -v --cov-config .coveragerc --cov=dynaconf -l tests/ --junitxml=junit/test-results.xml
	coverage xml
	make coverage-report

ciinstall:
	python -m pip install --upgrade pip
	python -m pip install -r requirements_dev.txt

test_all: test_functional test_integration test_redis test_vault test
	@coverage html

install:
	pip install --upgrade pip
	pip install -r requirements_dev.txt

run-pre-commit:
	rm -rf .tox/
	rm -rf build/
	pre-commit run --all-files

pep8:
	# Flake8 ignores
	#   F841 (local variable assigned but never used, useful for debugging on exception)
	#   W504 (line break after binary operator, I prefer to put `and|or` at the end)
	#   F403 (star import `from foo import *` often used in __init__ files)
	# flake8 dynaconf --ignore=F403,W504,W503,F841,E401,F401,E402 --exclude=dynaconf/vendor
	flake8 dynaconf --exclude=dynaconf/vendor*

dist: clean
	@make minify_vendor
	@python setup.py sdist bdist_wheel
	@make source_vendor

publish:
	make run-tox
	@twine upload dist/*

clean:
	@find ./ -name '*.pyc' -exec rm -f {} \;
	@find ./ -name '__pycache__' -prune -exec rm -rf {} \;
	@find ./ -name 'Thumbs.db' -exec rm -f {} \;
	@find ./ -name '*~' -exec rm -f {} \;
	rm -rf .cache
	rm -rf build
	rm -rf dist
	rm -rf *.egg-info
	rm -rf htmlcov
	rm -rf .tox/
	rm -rf site

docs:
	rm -rf site
	mkdocs build --clean

run-tox:
	tox --recreate
	rm -rf .tox

minify_vendor:
	# Ensure vendor is source and cleanup vendor_src bck folder
	ls dynaconf/vendor/source && rm -rf dynaconf/vendor_src

	# Backup dynaconf/vendor folder as dynaconf/vendor_src
	mv dynaconf/vendor dynaconf/vendor_src

	# create a new dynaconf/vendor folder with minified files
	./minify.sh


source_vendor:
	# Ensure dynaconf/vendor_src is source and cleanup vendor folder
	ls dynaconf/vendor_src/source && rm -rf dynaconf/vendor

	# Restore dynaconf/vendor_src folder as dynaconf/vendor
	mv dynaconf/vendor_src dynaconf/vendor
