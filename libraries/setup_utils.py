"""This file contains usefull and complex setup functionality"""
import subprocess
import time
import os
from os.path import join

import requests
from robot.api.deco import keyword
from robot.api import logger


ROBOT_AUTO_KEYWORDS = False


@keyword(types=[str, int, str, int, int])
def connect_nodes(cwd: str, node_num: int, services: str, data_size: int = 256, wait_for: int = 30):
    """Runs cluster connect with the given options. It will sleep for wait_for seconds after to give time for the
    rebalance to take place and the nodes to get initialize.

    Args:
        cwd: These should be the ns_server directory.
        node_num: The number of nodes to connect.
        services: The services that each node should have following the cluster connect sintax (e.g n0:kv,n1:kv+backup).
        data_size: The size in MB for the data service.
        wait_for: How long to sleep after initializing nodes.

    It will realise a CalledProcessError if cluster_connect fails.
    """
    logger.info(f'Connecting nodes {services}', also_console=True)
    complete = subprocess.run([join(cwd, 'cluster_connect'), '-n', str(node_num), '-T', services, '-s', str(data_size),
                               '-r', '0'], capture_output=True, timeout=30)
    if complete.returncode != 0:
        logger.warn(f'Cluster connect failed, rc {complete.returncode}: {complete.stdout}')
        raise subprocess.CalledProcessError(complete.returncode, complete.args)
    time.sleep(wait_for)
    logger.info('Nodes connected', also_console=True)


@keyword(types=[str, str, str, str, int])
def confirm_backup_service_running(host: str, log_path: str, user: str = 'Administrator', password: str = 'asdasd',
                                   context: int = 15):
    """confirm the backup service is running in the given host if it is not it will error out and log the last lines
    off the backup_service log"""
    res = requests.get(f'{host}/api/v1/config', auth=(user, password))
    if res.status_code != 200:
        log_end_of_backup_service_logs(log_path, context)
        raise AssertionError(f'Backup service is not running in host {host}')


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


def log_end_of_backup_service_logs(log_path: str, context: int):
    """Log the last lines of the abckup service log"""
    try:
        logger.info(get_last_lines_of_log(log_path, context))
    except FileNotFoundError as e:
        logger.error(f'Could not open log file, it does not exist: {e}')
