*** Settings ***
Documentation    This test suite focuses on running tests against the backup service REST API
Force Tags       rest
Resource          ../setup/setup.resource
Suite setup      Start cluster_run nodes and connect them    node_num=2    connect_nodes=2    services=n0:kv,n1:backup
Suite teardown   Environment dependent clean up
