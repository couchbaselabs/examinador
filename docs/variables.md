# Robot Variables

The are a multitude of variables that can be provided to the command to alter the
behaviour of the test framework. The variables are provided using the syntax

```
--variable <VARIABLE_NAME>:<VARIABLE_VALUE>
```
For example
```
--variable NS_SERVER_PATH:\Users\me\source\ns_server
```

## Location Variables

This are variables that point `Examinador` to the correct place for variables scripts and
executables.

The following are listed with the following syntax "**VARIABLE_NAME: (type) [default_value]** Description".

**NS_SERVER_PATH: (str) [$HOME/source/ns_server]** The location to the ns_server repo.

**COUCHBASE_LOG_PATH: (str) [NS_SERVER_PATH/logs/n_1]** Location for the logs.

**BIN_PATH: (str) [$HOME/source/install/bin]** The location to the build Couchbase directory.

**WORKSPACE: (str) [$CWD]** The location of the examinador directory.

### Setup and teardown

This variables override or alter the behaviour of the current setups and teardown functions.
Currently the backup service ui and test setups use the same keywords for the setup which
is `Start cluster_run nodes and connect them` for teardown they run `Environment dependent cleanup`.

**SKIP_SETUP: (bool) [False]** Will skip the setup stage, this means it won't try and run cluster_run or
    cluster_connect. This is useful if you want to point it to an already running cluster
    instead of setting up a new one.

**SKIP_TEARDOWN: (bool) [False]** Will skip the teardown stage which means it won't stop the running cluster
    nor will it delete the data and logs.

**DELETE_LOGS: (bool) [False]** When set to `True` the teardown will stop the nodes and delete the data and
    the logs. If set to `False` it won't delete the logs.

**RUNNING_MODE: (str) [CV]** If set to anything other than `CV` then the nodes and the data will only be
    cleaned up if the test pass.

**WAIT_UNTIL_READY: (int) [25]** How long it should wait until the cluster is up and rebalanced.
    (This is a hack until I add proper functions to observe that the cluster is ready).

### Host and REST

This are variables that control where REST calls should be made, if the cluster is pre-setup and not
setup by the Setup function then the hosts will have to be overridden so that the tests work.

**BACKUP_NODE: (str) [http://localhost:7101]** The address and port of the backup service.

**BACKUP_HOST: (str) [http://localhost:7101/api/v1]** The root path for the backup service V1 API.

**CB_NODE: (str) [http://localhost:9001]** The host of the node that is running the backup service. The
    port should be the management port.

**USER: (str) [Administrator]** The user to use for communicating with the cluster.

**PASSWORD: (str) [asdasd]** The password to use for communicating with the cluster.
