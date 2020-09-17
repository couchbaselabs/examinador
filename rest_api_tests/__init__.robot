*** Settings ***
Documentation    This test suite focuses on running tests against the backup service REST API
Force Tags       rest
Resource          ../resources/setup.resource
Suite setup      Run keywords    Start cluster_run nodes and connect them    node_num=2    connect_nodes=2    services=n0:kv,n1:backup    AND
...              confirm backup service running    http://localhost:7101    ${NS_SERVER_PATH}${/}logs${/}n_1
Suite teardown   Environment dependent clean up
