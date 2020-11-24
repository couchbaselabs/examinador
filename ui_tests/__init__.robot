*** Settings ***
Documentation    This test suite focuses on running UI tests against the backup service
Force Tags       rest    UI
Resource          ../resources/setup.resource
Suite setup      Start cluster_run nodes and connect them    node_num=1    connect_nodes=1    services=n0:kv+backup
Suite teardown   Environment dependent clean up
