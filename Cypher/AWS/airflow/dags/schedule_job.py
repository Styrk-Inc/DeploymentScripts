import airflow
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from datetime import datetime, timedelta
from jinja2 import Template
import logging
import json
import pytz
import re
import os
import requests


class MyDag(DAG):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)


default_args = {
    "owner": "admin",
    "start_date": datetime(2023, 3, 24),
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

dag = MyDag(
    dag_id="schedule_job",
    default_args=default_args,
    schedule_interval=None,
    catchup=False,
)


def convert_json_array_to_list(json_array):
    values = [d["value"] for d in json_array]
    return values


def convert_to_dictionary(taskid, parallelchilds):
    uuid_list = parallelchilds.split(",")
    result_dict = {uuid: taskid for uuid in uuid_list}
    return result_dict


def convertToJsonObj(json_str):
    json_str = re.sub(r"(?<=,|\{)\s*'(\w+)'\s*:", r'"\1":', json_str)  # for keys
    json_str = re.sub(r"(?<!')'([^']+)'(?!\s*:)", r'"\1"', json_str)  # for values

    json_str = re.sub(r"\s*:\s*", ": ", json_str)
    json_str = re.sub(r",\s*", ", ", json_str)

    json_obj = json.loads(json_str)

    return json_obj


def generate_cron_expression(json_str):
    data = json_str

    cron_type = data.get("type")
    start_date = data.get("start_date")
    end_date = data.get("end_date")
    time = data.get("time")
    timezone = data.get("timezone")
    week_days = data.get("week_days", "")
    month_days = data.get("month_days", "")
    custom_dates = data.get("custom_dates", "")

    if not all([cron_type, start_date, end_date, time, timezone]):
        raise ValueError("All fields except week_days and month_days are required")

    start_datetime = datetime.strptime(f"{start_date} {time}", "%Y-%m-%d %H:%M:%S")
    end_datetime = datetime.strptime(f"{end_date} {time}", "%Y-%m-%d %H:%M:%S")

    if end_datetime < start_datetime:
        raise ValueError("End date must be after start date")

    target_tz = pytz.timezone(timezone)
    local_time = target_tz.localize(start_datetime)
    utc_time = local_time.astimezone(pytz.utc)

    minute = utc_time.minute
    hour = utc_time.hour

    if cron_type == "daily":
        cron_expression = f"{minute} {hour} * * *"

    elif cron_type == "weekly":
        days_of_week = convert_week_days(week_days)
        cron_expression = f"{minute} {hour} * * {days_of_week}"

    elif cron_type == "monthly":
        days_of_month = month_days.replace(",", " ")
        cron_expression = f"{minute} {hour} {days_of_month} * *"

    elif cron_type == "custom":
        if not custom_dates:
            raise ValueError("custom_dates are required for custom cron type")

        custom_day_month_pairs = [date.split("-") for date in custom_dates.split(",")]
        days = ",".join(pair[0] for pair in custom_day_month_pairs)
        months = ",".join(pair[1] for pair in custom_day_month_pairs)

        cron_expression = f"{minute} {hour} {days} {months} *"

    elif cron_type == "now":
        cron_expression = f"{minute} {hour} {utc_time.day} {utc_time.month} *"

    else:
        raise ValueError("Unsupported cron type")

    return cron_expression


def convert_week_days(week_days):
    days_map = {
        "Sunday": "0",
        "Monday": "1",
        "Tuesday": "2",
        "Wednesday": "3",
        "Thursday": "4",
        "Friday": "5",
        "Saturday": "6",
    }
    days = week_days.split(",")
    cron_days = ",".join(
        days_map[day.strip()] for day in days if day.strip() in days_map
    )
    return cron_days


def dag_generator(**kwargs):
    conf = kwargs["dag_run"].conf
    logging.info(f"dag_run: {conf}")

    dag_defn = conf.get("dag_defn")
    logging.info(f"dag_defn: {dag_defn}")

    template_name = dag_defn.get("scheduler_name")
    template_id = dag_defn.get("scheduler_id")
    url_details = dag_defn.get("url_details")
    schedule_details = dag_defn.get("schedule")

    logging.info(f"schedule_details: {schedule_details}")

    currentDay = datetime.now().day
    currentMonth = datetime.now().month
    currentYear = datetime.now().year

    sch_cron_exp = generate_cron_expression(schedule_details)

    dag_template = f"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
import logging
import json
import requests

class MyDag(DAG):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

default_args = {{
    'owner': 'me',
    'start_date': datetime({currentYear}, {currentMonth}, {currentDay}),
    'depends_on_past': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}}

dag = MyDag(
    dag_id='{template_id}',
    description='URL Hitter',
    default_args=default_args,
    schedule_interval='{sch_cron_exp}',
    catchup=False
)

def trim_keys(dict_list):
    modified_list = []
    
    for original_dict in dict_list:
        modified_dict = {{}}
        
        for key, value in original_dict.items():
            new_key = key.replace('\\ufeff', '')
            modified_dict[new_key] = value
        
        modified_list.append(modified_dict)
    
    return modified_list
    
def replaceSpace(in_list):
    return [{{k.replace(' ', '_') : v for k, v in d.items()}} for d in in_list]

def removeUnselected(in_list):
    return [d for d in in_list if d['selection'] == 1]

def convertToJsonObj(json_str):
    json_str = re.sub(r"(?<=,|\{{)\s*'(\w+)'\s*:", r'\"\\1\":', json_str) # for keys
    json_str = re.sub(r"(?<!')'([^']+)'(?!\s*:)", r'\"\\1\"', json_str) # for values

    json_str = re.sub(r'\s*:\s*', ': ', json_str)
    json_str = re.sub(r',\s*', ', ', json_str)

    json_obj = json.loads(json_str)
    
    return json_obj

url_data = {url_details}

def perform_request():
    url_info = url_data
    if url_info:
        if url_info['method'].upper() == 'GET':
            response = requests.get(
                url=url_info['endpoint'],
                headers=url_info['headers'],
                params=url_info.get('params', {{}})
            )
        else:
            payload = url_info['body']
            response = requests.request(
                method=url_info['method'],
                url=url_info['endpoint'],
                headers=url_info['headers'],
                json=payload.get('content', {{}}) if payload['type'] == 'json' else None,
                data=payload.get('content', {{}}) if payload['type'] != 'json' else None
            )
        logging.info(f"Response from {{url_info['name']}}: {{response.status_code}}, {{response.text}}")

task_url_hitter = PythonOperator(
    task_id='url_hitter',
    python_callable=perform_request,
    dag=dag
)
"""

    template = Template(dag_template)
    rendered_template = template.render(conf=conf)

    filename = f"{template_id}.py"
    filepath = os.path.join(os.path.dirname(__file__) or ".", filename)
    with open(filepath, "w") as f:
        f.write(rendered_template)
    logging.info(f"Flow created at path: {filepath} with name: {filename}")

    kwargs["ti"].xcom_push(key="dag_defn", value=dag_defn)


daggen_task = PythonOperator(task_id="DagGen", python_callable=dag_generator, dag=dag)

daggen_task
