#!/usr/bin/env bash

# User-provided configuration must always be respected.
#
# Therefore, this script must only derives Airflow AIRFLOW__ variables from other variables
# when the user did not provide their own configuration.

# Modified to include Amazon Aurora MySQL DB and Amazon SQS

TRY_LOOP="20"

# Global defaults and back-compat
: "${AIRFLOW_HOME:="/usr/local/airflow"}"
: "${AIRFLOW__CORE__FERNET_KEY:=${FERNET_KEY:=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)")}}"

# Updated to CeleryExecutor
AIRFLOW__CORE__EXECUTOR=CeleryExecutor

# Load DAGs examples (default: Yes) changed to No
AIRFLOW__CORE__LOAD_EXAMPLES=False

# Added Celery details
export \
  AIRFLOW_HOME \
  AIRFLOW__CORE__EXECUTOR \
  AIRFLOW__CORE__FERNET_KEY \
  AIRFLOW__CORE__LOAD_EXAMPLES \
  AIRFLOW__CELERY__RESULT_BACKEND \
  AIRFLOW__CORE__SQL_ALCHEMY_CONN \
  AIRFLOW__CELERY__BROKER_URL \


# Added Aurora MySQL DB and Amazon SQS details
: "${MYSQL_HOST:="%mysql_host_dns%"}"
: "${MYSQL_PORT:="3306"}"
: "${MYSQL_USER:="%mysql_user%"}"
: "${MYSQL_PASSWORD:="%mysql_password%"}"
: "${MYSQL_DB:="%mysql_db%"}"

AIRFLOW__CORE__SQL_ALCHEMY_CONN="mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}"
AIRFLOW__CELERY__RESULT_BACKEND="db+mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}"

AIRFLOW__CELERY__BROKER_URL="sqs://"

airflow initdb
airflow create_user -r admin -u admin -e admin@example.com -f admin -l admin -p %user_password%


case "$1" in
  webserver)
    airflow initdb
    exec airflow "$@"
    ;;
  scheduler)
    sleep 10
    exec airflow "$@"
    ;;
  worker)
    sleep 10
    aws s3 cp %s3_key_path% /usr/local/airflow/certs
    chmod 400 /usr/local/airflow/certs/%key_name%
    exec airflow worker -q %sqs_name%
    ;;
  flower)
    sleep 10
    exec airflow "$@"
    ;;
  version)
    exec airflow "$@"
    ;;
  *)
    # The command is something like bash, not an airflow subcommand. Just run it in the right environment.
    exec "$@"
    ;;
esac
