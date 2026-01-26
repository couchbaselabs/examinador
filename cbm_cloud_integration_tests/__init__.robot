***Settings***
Documentation      This test suite tests cbbackupmgr commands when integrating with cloud.
Force Tags         cbbackupmgr    cloud
Library            ../libraries/sdk_utils.py
Resource           ../resources/setup.resource
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource
Suite setup        Start cluster_run nodes and connect them    node_num=1    connect_nodes=1
...                services=n0:kv+index+n1ql
Suite teardown     Run keywords
...                    Process server logs    AND
...                    Environment dependent clean up
