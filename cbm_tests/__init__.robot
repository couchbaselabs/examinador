***Settings***
Documentation      This test suite tests cbbackupmgr commands including backup, restore, info and merge.
Force Tags         cbbackupmgr
Library            ../libraries/sdk_utils.py
Resource           ../resources/setup.resource
Resource           ../resources/cbm.resource
Suite setup        Run keywords    Start cluster_run nodes and connect them    node_num=1    connect_nodes=1
...                services=n0:kv+index+n1ql
...                AND    Enable flush
Suite teardown     Run keywords    Collect server logs
...                AND    Drop gsi indexes
...                AND    Environment dependent clean up
