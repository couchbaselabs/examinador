***Settings***
Documentation      This test suite tests cbbackupmgr commands when working on nodes with multiple services running.
Force Tags         cbbackupmgr    multi-service
Resource           ../resources/setup.resource
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource
Suite setup        Run keywords    Start cluster_run nodes and connect them    node_num=1    connect_nodes=1
...                services=n0:kv+index+n1ql+fts+cbas+eventing
...                AND    Enable flush
Suite teardown     Run keywords    Process server logs
...                AND    Delete bucket cli    bucket=meta
...                AND    Environment dependent clean up
