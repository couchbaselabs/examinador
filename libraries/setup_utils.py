"""This file contains usefull and complex setup functionality"""
import shutil
import subprocess
import time
import os
from os.path import join
from datetime import datetime

import requests
from robot.api.deco import keyword
from robot.api import logger


ROBOT_AUTO_KEYWORDS = False

@keyword(types=[str, int, int])
def check_node_started(host: str, port: int, max_tries: int = 30):
    """Will poll the pools endpoint until it receives a 200. It will fail after 'max_tries'.

    The sleep between tries increases every time. Large retry numbers could cause long sleeps.

    Args:
        host: The host to do requests to.
        port: The port to do the request to.
        max_tries: The number of tries. It should be larger or equal to 1.
    """

    logger.info(f'Checking that node {host}:{port} is ready', also_console=True)
    for i in range(max_tries):
        logger.info(f'{datetime.now()} Polling attempt {i+1}', also_console=True)
        try:
            res = requests.get(f'{host}:{port}/pools', timeout=5)
            logger.debug(f'Response status code: {res.status_code}')
            if res.status_code == 200:
                logger.info('Node is ready', also_console=True)
                time.sleep(5)
                return
        except Exception:
            pass

        # max sleep of 10 seconds
        time.sleep(min(1 + i, 10))

    raise AssertionError(f'Could not confirm Couchbase cluster running in {host}:{port}')

@keyword(types=[str, int, int])
def check_query_metadata_transitioned(host:str, port:int, max_tries: int = 30):
    """Will poll the backup endpoint of query until it receives a 200. It will fail after 'max_tries'.

    The sleep between tries increases every time. Large retry numbers could cause long sleeps.

    Args:
        host: The host to do requests to.
        port: The port to do the request to.
        max_tries: The number of tries. It should be larger or equal to 1.
    """

    logger.info(f'Checking that query metadata has transitioned ({host}:{port})', also_console=True)
    for i in range(max_tries):
        logger.info(f'{datetime.now()} Polling attempt {i+1}', also_console=True)
        try:
            res = requests.get(f'{host}:{port}/api/v1/backup', timeout=5, auth=('Administrator', 'asdasd'))
            logger.info(f'Response status code: {res.status_code}', also_console=True)
            if res.status_code == 200:
                logger.info('Query is ready', also_console=True)
                return
        except Exception:
            pass

        # max sleep of 10 seconds
        time.sleep(min(1 + i, 10))

    raise AssertionError(f'Could not confirm query metadata has transitioned {host}:{port}')

@keyword(types=[str, int, str, int])
def connect_nodes(cwd: str, node_num: int, services: str, data_size: int = 512, index_size: int = 256):
    """Runs cluster connect with the given options. It will sleep for wait_for seconds after to give time for the
    rebalance to take place and the nodes to get initialize.

    Args:
        cwd: These should be the ns_server directory.
        node_num: The number of nodes to connect.
        services: The services that each node should have following the cluster connect sintax (e.g n0:kv,n1:kv+backup).
        data_size: The size in MB for the data service.

    It will realise a CalledProcessError if cluster_connect fails.
    """
    # retry up to 3 times
    connected = False
    for i in range(5):
        logger.info(f'Connecting nodes {services}', also_console=True)
        complete = subprocess.run([join(cwd, 'cluster_connect'), '-n', str(node_num), '-T', services, '-s',
                                   str(data_size), '-I', str(index_size), '-r', '0', '-M', 'memory_optimized'],
                                   capture_output=True, timeout=120)
        if complete.returncode != 0:
            logger.warn(f'Cluster connect failed, rc {complete.returncode}: {str(complete.stdout)}')
            time.sleep(5 * (i + 1))
        else:
            connected = True
            break

    if not connected:
        raise subprocess.CalledProcessError(complete.returncode, complete.args)


    logger.info('Nodes connected', also_console=True)
    logger.debug(complete.stdout)

    # wait until the rebalance is finished
    for i in range(50):
        time.sleep(min(1 + i, 10))

        try:
            res = requests.get('http://localhost:9000/pools/default/rebalanceProgress', timeout=5,
                               auth=('Administrator', 'asdasd'))
            if res.status_code != 200:
                continue
            if res.json()['status'] == 'none':
                logger.info('Nodes rebalanced', also_console=True)
                return
        except Exception:
            pass

    raise AssertionError('Nodes did not rebalance in a timely fashion')


@keyword(types=[str, str, str, str, int])
def confirm_backup_service_running(host: str, log_path: str, user: str = 'Administrator', password: str = 'asdasd',
                                   context: int = 15):
    """confirm the backup service is running in the given host if it is not it will error out and log the last lines
    off the backup_service log"""
    worked = False
    try:
        logger.info(f'Confiming the backup service is running in host: {host}')
        res = requests.get(f'{host}/api/v1/config', auth=(user, password), timeout=60)
        worked = res.status_code == 200
    except Exception as connection_error:
        logger.warn(f'Connection error occured: {connection_error}')

    if not worked:
        log_end_of_backup_service_logs(log_path, context)
        raise AssertionError(f'Backup service is not running in host {host}')


@keyword(types=[str])
def remove_directory_and_ignore_errors(path: str):
    """Remove directory specifed by path and everything in it and log a warning for any errors"""
    shutil.rmtree(path, onerror = log_error)
    logger.info(f'Directory {path} has been removed')


def log_error(_, path, exc_info):
    """Log any errors that occurred while removing a directory"""
    logger.warn(f'Error while removing directory {path}: {exc_info}')


def get_last_lines_of_log(log_path: str, context: int):
    """Retrieve the last context lines of the backup service log"""
    list_of_lines = []
    with open(join(log_path, 'backup_service.log'), 'rb') as log_file:
        log_file.seek(0, os.SEEK_END)
        buffer = bytearray()
        pointer_location = log_file.tell()

        while pointer_location >= 0:
            log_file.seek(pointer_location)
            pointer_location = pointer_location - 1
            new_byte = log_file.read(1)
            if new_byte == b'\n':
                list_of_lines.append(buffer.decode()[::-1])
                if len(list_of_lines) == context:
                    return list(reversed(list_of_lines))
                buffer = bytearray()
            else:
                buffer.extend(new_byte)

        # As file is read completely, if there is still data in buffer, then its first line.
        if len(buffer) > 0:
            list_of_lines.append(buffer.decode()[::-1])

    return None


def log_end_of_backup_service_logs(log_path: str, context: int):
    """Log the last lines of the abckup service log"""
    try:
        logger.info(get_last_lines_of_log(log_path, context))
    except FileNotFoundError as e:
        logger.error(f'Could not open log file, it does not exist: {e}')
