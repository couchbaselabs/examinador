Examinador
======

Examinador is a framework a tool to run integration tests for the backup service.
To use the tool you will need Python 3.6.

Create and activate a virtual environment

```
python3 -m venv robot-env
source robot-env/bin/activate
```

Install all the dependencies

```
pip install -r requirements.txt
```

Run the REST API test suite

```
robot-env/bin/robot --variable NS_SERVER_PATH:<location to the ns_server_repo> rest_api_tests
```

Note that you must provided the path to the ns_server repo as currently it only supports running
test of a dev cluster using `cluster_run`. The idea is to expand so that it can take an arbitrary
set of nodes to do the tests. Before running the tests make sure you have build the server as if
not it will fail.

Setup takes around a minute, after that the test should run expediently.

To run the UI test selenium webdrivers are required this can be installed using the following command
```
webdrivermanager firefox chrome --linkpath /usr/local/bin
```

webdrivermanager is installed as part of the previous `pip install` run.
