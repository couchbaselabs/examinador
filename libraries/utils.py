"""This contain miscelaneous utility funtions used by the tests"""
import json
import random
import re
import string
import time
from datetime import datetime
from typing import Dict, Union, List

import requests
from dateutil.parser import parse
from robot.api.deco import keyword
from robot.api import logger


ROBOT_AUTO_KEYWORDS = False
DURATION_FORMAT = r'((?P<days>\d+)d ?)?((?P<hours>\d+)h ?)?((?P<minutes>\d+)m ?)?((?P<seconds>\d+)s ?)?$'


@keyword(types=[int, str, str])
def generate_random_string(length: int = 10, chars: str = string.ascii_letters+string.digits,
                           start_char: str = string.ascii_letters) -> str:
    """Generate a random string of length 'length' where the first character is taken from the start_char string and
    the remainder characters are taken from chars
    """
    if length < 1:
        return ''

    generated = random.choice(start_char)
    length -= 1
    if length > 0:
        generated += ''.join(random.choices(chars, k=length))

    return generated


@keyword(types=[str, str, str, str, int])
def wait_until_one_off_task_is_finished(host: str, task_name: str, instance_name: str, state: str = 'active',
                                        timeout: int = 60, retries: int = 10, user: str = 'Administrator',
                                        password: str = 'asdasd'):
    """Will wait until the task is no longer running"""
    for retry in range(retries):
        logger.debug(f'Checking if task {task_name} is still running. Attempt {retry}')
        res = requests.get(f'{host}/api/v1/cluster/self/instance/active/{instance_name}', auth=(user, password),
                           timeout=timeout)
        if res.status_code != 200:
            raise requests.HTTPError(f'Unexpected error code: {res.status_code} {res.json()}')

        instance = res.json()
        if 'running_one_off' not in instance or task_name not in instance['running_one_off']:
            # if no running one offs assume task is finished
            return

        time.sleep(1)
        continue

    raise AssertionError('Task is not finished')


@keyword
def dictionary_like_equals(first: Union[Dict, str], second: Union[Dict, str], remove_empty: List[str] = []) -> bool:
    """Compare either strings to dictionaries and see if they match"""
    logger.info(f'Comparing {sorted_json_string(first)} == {sorted_json_string(second)} filter: {remove_empty}')
    if sorted_json_string(first, remove_empty) != sorted_json_string(second, remove_empty):
        raise AssertionError(f'{sorted_json_string(first, remove_empty)} != {sorted_json_string(second, remove_empty)}')


@keyword(types=[int, bool])
def generate_random_task_template(number: int = 1, valid: bool = True) -> str:
    """Generates a list with random tasks"""
    return json.dumps(
        [generate_valid_task_template() if valid else generate_invalid_task_template() for i in range(0, number)]
    )


@keyword(types=[str, str, int])
def should_be_approx_x_from_now(time_str: str, offset: str = '1h', error_margin: int = 3600):
    """Checks whether a time represented by 'time_str' is approximately 'offset' from now. The acceptable error margin
    is error_margin in seconds.
    """
    timestamp = parse(time_str)
    now = datetime.now(timestamp.tzinfo)
    match = re.fullmatch(DURATION_FORMAT, offset)
    if not match:
        raise ValueError(f'Invalid offset {offset}')

    logger.info(match)

    days = int(match.group('days')) if match.group('days') else 0
    hours = int(match.group('hours')) if match.group('hours') else 0
    minutes = int(match.group('minutes')) if match.group('minutes') else 0
    seconds = int(match.group('seconds')) if match.group('seconds') else 0
    expected_diff = days * 86400 + hours * 3600 + minutes * 60 + seconds
    diff = (timestamp - now).total_seconds()
    logger.info(f'Got time {timestamp} now {now}')
    logger.info(f'Offset {offset} diff {diff} expected_diff {expected_diff} margin {error_margin}s')
    if abs(diff - expected_diff) > error_margin:
        raise AssertionError(f'The task was scheduled at {timestamp} when it should have been scheduled at'
                             f'{now} + {offset} with a margin of {error_margin}s')


def generate_valid_task_template() -> Dict:
    """Generates a random valid backup service task template"""
    task_type = random.choice(['BACKUP', 'MERGE'])
    return {
        'name': ''.join(random.choices(string.ascii_letters, k=20)),
        'task_type': task_type,
        'schedule': {
            'job_type': task_type,
            'frequency': random.randint(10, 120),
            'period': random.choice(['MINUTES', 'HOURS', 'DAYS', 'WEEKS']),
        },
    }


def generate_invalid_task_template() -> Dict:
    """Generates a random invalid backup service task template, the reason for it being invalid may vary
    Reasons are:
    0 - Invalid name
    1 - Invalid task type
    2 - Invalid frequency
    3 - Invalid period
    """
    reason = random.randint(0, 3)
    task = generate_valid_task_template()
    if reason == 0:
        task['name'] = random.choice(string.ascii_letters) * 100
    elif reason == 1:
        task['task_type'] = 5
    elif reason == 2:
        task['schedule']['frequency'] = -1.58
    elif reason == 3:
        task['schedule']['period'] = ['A', 'B', 'C']
    return task


def sorted_json_string(dict_like: Union[Dict, str], remove_empty: List[str] = []) -> str:
    """Convert a dictionary or a string into a key sorted JSON string"""
    val = dict_like
    if isinstance(val, str):
        val = json.loads(val)
    for remove in remove_empty:
        if remove in val and (val[remove] == '' or val[remove] is None):
            del val[remove]
    return json.dumps(val, sort_keys=True)
