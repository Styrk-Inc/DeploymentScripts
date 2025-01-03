from datetime import datetime, timedelta
import sys
import sys
import os

from airflow.decorators import task

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.providers.http.operators.http import SimpleHttpOperator
from airflow.models import Variable

default_args = {
    'owner': 'admin',
    'depends_on_past': False,
    'start_date': datetime(2023, 12, 15),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG('bulk_scan_dag',
          default_args=default_args,
          description='DAG to trigger bulk scan every 5 minutes',
          schedule_interval=Variable.get("scan_schedule", default_var="*/15 * * * *"),
          catchup=False)

start = EmptyOperator(task_id='start', dag=dag)

call_bulk_scan = SimpleHttpOperator(
    task_id='call_bulk_scan',
    http_conn_id='bulk_scan_api',  # Define the connection in Airflow UI
    endpoint='/scan/start-bulk-scan/',
    method='POST',
    # response_check=lambda response: response.status_code == 200,
    dag=dag)

start >> call_bulk_scan
