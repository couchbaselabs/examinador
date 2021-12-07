***Settings***
Documentation      This test suite tests cbimport/cbexport/cbdocloader commands.
Force Tags         cbimport    cbexport    cbdocloader
Library            ../libraries/sdk_utils.py
Resource           ../resources/setup.resource
Resource           ../resources/cbm.resource
Suite setup        Run keywords    Start cluster_run nodes and connect them    node_num=1    connect_nodes=1
...                services=n0:kv+index+n1ql    index_size=512
...                AND    Enable flush
Suite teardown     Run keywords    Process server logs
...                AND    Environment dependent clean up