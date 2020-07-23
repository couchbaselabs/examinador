"""This file contains usefull and complex setup functionality"""
import subprocess
import time
from os.path import join

from robot.api.deco import keyword
from robot.api import logger


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
        raise subprocess.CalledProcessError
    time.sleep(wait_for)
    logger.info('Nodes connected', also_console=True)
