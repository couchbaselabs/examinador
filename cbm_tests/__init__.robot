***Settings***
Documentation      This test suite tests cbbackupmgr commands including backup, restore, info and merge.
Force Tags         cbbackupmgr
Resource           ../resources/setup.resource
Suite setup        Start cluster_run nodes and connect them    node_num=1    connect_nodes=1    services=n0:kv
Suite teardown     Environment dependent clean up
