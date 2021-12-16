"""This contain miscelaneous utility funtions used by the tests"""
import json
import os
import random
import re
import string
import subprocess
import time

from datetime import datetime
from typing import Dict, Union, List, Tuple

import requests

from dateutil.parser import parse
from robot.api.deco import keyword
from robot.api import logger
from robot.utils.asserts import assert_equal, fail


ROBOT_AUTO_KEYWORDS = False
DURATION_FORMAT = r'((?P<days>\d+)d ?)?((?P<hours>\d+)h ?)?((?P<minutes>\d+)m ?)?((?P<seconds>\d+)s ?)?$'


def get_user_and_password(**kwargs) -> Tuple[str, str]:
    """Helper function to get user and password"""
    return kwargs.get('user', 'Administrator'), kwargs.get('password', 'asdasd')


def convert_duration_format_to_seconds(duration: str) -> int:
    """converts a string of format Dd Hh Mm Ss to a absolute number of seconds"""
    match = re.fullmatch(DURATION_FORMAT, duration)
    if not match:
        raise ValueError(f'Invalid durration {duration}')

    days = int(match.group('days')) if match.group('days') else 0
    hours = int(match.group('hours')) if match.group('hours') else 0
    minutes = int(match.group('minutes')) if match.group('minutes') else 0
    seconds = int(match.group('seconds')) if match.group('seconds') else 0
    return days * 86400 + hours * 3600 + minutes * 60 + seconds


@keyword
def list_should_be_same_by_key(expected: List[Dict], got: List[Dict], key: str):
    """Given to list of objects it will check that the elements in the same index share the same value for the given
    key.
    """
    if len(expected) != len(got):
        raise AssertionError(f'Expected {len(expected)} backups got {len(got)} backups')

    for (index, (expected_item, got_item)) in enumerate(zip(expected, got)):
        if expected_item[key] != got_item[key]:
            raise AssertionError(f'Element in index {index} does not match {expected_item[key]} != {got_item[key]}')


@keyword
def is_approx_from_now(time_str: str, duration: str = '5m', margin: int = 30):
    """checks that the givent time is  n units +- margin seconds from the current time """
    timestamp = parse(time_str)
    now = datetime.now(timestamp.tzinfo)

    diff = (timestamp - now).total_seconds()
    expected_diff = convert_duration_format_to_seconds(duration)
    if abs(diff - expected_diff) > margin:
        raise AssertionError(f'Time {timestamp} is not {duration} from {now}')


@keyword
def archive_and_delete_repo(host: str, repo: str, **kwargs):
    """Archives the active repo and then deletes it"""
    user, password = get_user_and_password(**kwargs)
    timeout = int(kwargs.get('timeout', 60))

    # archive repo
    new_id = ''.join(random.choice(string.ascii_letters) for i in range(20))
    res = requests.post(f'{host}/api/v1/cluster/self/repository/active/{repo}/archive', auth=(user, password),
                        timeout=timeout, json={'id': new_id})
    if res.status_code != 200:
        raise requests.HTTPError(f'Could not archive repository {repo} got status {res.status_code}: {res.text}')

    logger.debug(f'Archived repo {repo} with new id {new_id}')
    # delete repo
    res = requests.delete(f'{host}/api/v1/cluster/self/repository/archived/{new_id}', auth=(user, password),
                          params={'remove_repository': True})
    if res.status_code != 200:
        raise requests.HTTPError(f'Could not delete repository got status {res.status_code}: {res.text}')


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


@keyword
def wait_until_task_is_finished(host: str, task_name: str, repo: str, state: str = 'active',
                                task_type: str = 'running_one_off', **kwargs):
    """Wait until a task is finished
    Args:
        - host (str): the host for the backup service.
        - task_name (str): the task we are looking for.
        - task_type [running_one_off, running_tasks]: The type of task we are waiting for.
        - state ([active, imported, archived]): The repository state.
        - kwargs:
            - timeout (int): request timeout.
            - retries (int): how many times to poll the endpoint at a maximum.
            - user (str): The user to use for the requests.
            - passwrod (str): The password to use for the requests.
    """
    timeout = int(kwargs.get('timeout', 60))
    retries = int(kwargs.get('retries', 10))
    user, password = get_user_and_password(**kwargs)

    if task_type not in ['running_one_off', 'running_tasks']:
        raise ValueError('taks type must be one off [running_one_off, running_tasks]')

    for retry in range(retries):
        logger.debug(f'Checking if task {task_type} {task_name} is still running. Attempt {retry}')
        res = requests.get(f'{host}/api/v1/cluster/self/repository/{state}/{repo}', auth=(user, password),
                           timeout=timeout)
        if res.status_code != 200:
            raise requests.HTTPError(f'Unexpected error code: {res.status_code} {res.json()}')

        repository = res.json()
        logger.debug(f'/api/v1/cluster/self/repository/{state}/{repo} response: {repository}')

        if task_type not in repository or task_name not in repository[task_type]:
            if retry == 0:
                logger.debug('Task finished before first run')
            # if no running one offs assume task is finished
            return

        time.sleep(1 * (retries + 1))
        continue

    raise AssertionError('Task is not finished')


@keyword
def dictionary_like_equals(first: Union[Dict, str], second: Union[Dict, str], remove_empty: List[str] = []):
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

    expected_diff = convert_duration_format_to_seconds(offset)
    diff = (timestamp - now).total_seconds()

    logger.info(f'Got time {timestamp} now {now}')
    logger.info(f'Offset {offset} diff {diff} expected_diff {expected_diff} margin {error_margin}s')
    if abs(diff - expected_diff) > error_margin:
        raise AssertionError(f'The task was scheduled at {timestamp} when it should have been scheduled at'
                             f'{now} + {offset} with a margin of {error_margin}s')


@keyword(types=[str])
def hex_encode(data: str) -> str:
    """Takes a string and returns it encoded in hex."""
    return data.encode().hex()


@keyword(types=[str])
def get_data_directory_path_of_only_backup(repo_path: str):
    """Returns the data directory of the only backup in a given backup repository"""
    repo_subdir_paths = [f.path for f in os.scandir(repo_path) if f.is_dir()]
    assert_equal(len(repo_subdir_paths), 1, "The number of backups is not 1")
    backup_subdir_paths = [f.path for f in os.scandir(repo_subdir_paths[0]) if f.is_dir()]
    assert_equal(len(backup_subdir_paths), 1, "The number of buckets in a backup is not 1")
    return os.path.join(backup_subdir_paths[0], 'data')


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
    dict_value: Dict = dict_like if isinstance(dict_like, dict) else json.loads(dict_like)
    for remove in remove_empty:
        if remove in dict_value and (dict_value[remove] == '' or dict_value[remove] is None):
            del dict_value[remove]
    return json.dumps(dict_value, sort_keys=True)


def log_subprocess_run_results(completed_process):
    """Log information about a completed subprocess"""
    logger.debug(f'Return code: {completed_process.returncode}')
    logger.debug(f'Arguments: {completed_process.args}')
    logger.debug(f'Output: {completed_process.stdout}')


def check_subprocess_status(completed_process):
    "Check subprocess return code and raise an error if it is not 0"
    if completed_process.returncode != 0:
        raise subprocess.CalledProcessError(completed_process.returncode, completed_process.args,
            completed_process.stdout)


def check_simple_data_contents(data, expected_length, group):
    """Check that the simple data contents are as expected"""
    assert_equal(len(data), expected_length, "Document contents changed: unexpected number of documents")

    for doc in data:
        assert_equal(doc["group"], group, "Document contents changed: group has changed")


def check_all_nums_distinct(data, expected_length):
    """Check that all of the given documents have distinct nums from 0 to expected_length - 1"""
    remaining_num_values = set(range(expected_length))
    for doc in data:
        current_num = doc['num']
        if current_num in remaining_num_values:
            remaining_num_values.remove(current_num)
        else:
            fail(f'Document contents changed: found unexpected doc with num = {doc["num"]}')
