*** Settings ***
Library     RequestsLibrary
Library     Process
Library     ../libraries/setup_utils.py
Library     ../libraries/common_utils.py    ${SOURCE}
Resource    ../resources/common.resource

*** Variables ***
${BIN_PATH}    ${SOURCE}${/}install${/}bin
${THREADS}     1
${CBWORKLOADGEN_WAIT_TIME}    20
${WORKSPACE}    %{PWD}

*** Keywords ***
Create CB bucket if it does not exist cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${ramQuota}=100
    [Documentation]    Create a couchbase bucket if it does not exist, using the couchbase-cli.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}
    ${resp}=    Run and log request on session    ${req}    GET    host=${host}    user=${user}    password=${password}
    ...         log_response=False
    Return from keyword if    ${resp.status_code} == 200
    ${command}=    Create List    ${BIN_PATH}${/}couchbase-cli    bucket-create    -c    ${host}    -u    ${user}
    ...                           -p    ${password}    --bucket    ${bucket}    --bucket-ramsize    ${ramQuota}
    ...                           --bucket-replica    0    --bucket-type    couchbase    --enable-flush    1    --wait
    Run and log and check process    ${command}
    check_query_metadata_transitioned    host=http://localhost    port=9499
    Sleep    5

Set index memory quota
    [Arguments]    ${host}=localhost:9000    ${user}=Administrator    ${password}=asdasd    ${ramQuota}=400
    [Documentation]    Set the RAM quota for the Index service.
    ${command}=    Create List    ${BIN_PATH}${/}couchbase-cli    setting-cluster    -c    ${host}    -u    ${user}
    ...            -p    ${password}    --cluster-index-ramsize     ${ramQuota}
    Run and log and check process    ${command}

Delete bucket cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Delete a bucket using the bucket-delete couchbase-cli command.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}
    ${resp}=    Run and log request on session    ${req}    GET    host=${host}    user=${user}    password=${password}
    ...         log_response=False
    Return from keyword if    ${resp.status_code} != 200
    ${command}=    Create List    ${BIN_PATH}${/}couchbase-cli    bucket-delete    -c    ${host}    -u    ${user}
    ...            -p    ${password}    --bucket    ${bucket}
    Run and log and check process    ${command}

Create CB scope if it does not exist
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default
    [Documentation]    Create a couchbase scope if it does not exist.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}/scopes/${scope}
    ${resp}=    Run and log request on session    ${req}    GET    host=${host}    user=${user}    password=${password}
    Return from keyword if    ${resp.status_code} == 200
    ${req}=    Set Variable    /pools/default/buckets/${bucket}/scopes
    ${pd}=    Set Variable    {"name":"${scope}"}
    Run and log and check request on session    ${req}    POST    200    payload=${pd}    host=${host}    user=${user}
    ...                                         password=${password}

Create CB scope if it does not exist cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default
    [Documentation]    Create a couchbase scope if it does not exist.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}/scopes/${scope}
    ${resp}=    Run and log request on session    ${req}    GET    host=${host}    user=${user}    password=${password}
    Return from keyword if    ${resp.status_code} == 200
    ${command}=    Create List    ${BIN_PATH}${/}couchbase-cli    collection-manage    -c    ${host}    -u    ${user}
    ...            -p    ${password}    --bucket    ${bucket}    --create-scope    ${scope}
    Run and log and check process    ${command}

Get scopes info
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default
    [Documentation]    Get information on existing scopes.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}/scopes
    ${resp}=    Run and log and check request on session    ${req}    GET    200    host=${host}    user=${user}
    ...         password=${password}
    Return from keyword    ${resp.json()}

Create collection if it does not exist
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default     ${collection}=default
    [Documentation]    Create a collection within a given scope if it does not already exist.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}/scopes/${scope}/${collection}
    ${resp}=    Run and log request on session    ${req}    GET    host=${host}    user=${user}    password=${password}
    Return from keyword if    ${resp.status_code} == 200
    ${req}=    Set Variable    /pools/default/buckets/${bucket}/scopes/${scope}
    ${pd}=    Set Variable    {"name":"${collection}"}
    Run and log and check request on session    ${req}    POST    200    payload=${pd}    host=${host}    user=${user}
    ...                                         password=${password}

Create collection if it does not exist cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default     ${collection}=default
    [Documentation]    Create a collection within a given scope if it does not already exist.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}/scopes/${scope}/${collection}
    ${resp}=    Run and log request on session    ${req}    GET    host=${host}    user=${user}    password=${password}
    Return from keyword if    ${resp.status_code} == 200
    ${command}=    Create List    ${BIN_PATH}${/}couchbase-cli    collection-manage    -c    ${host}    -u    ${user}
    ...            -p    ${password}    --bucket    ${bucket}    --create-collection    ${scope}.${collection}
    Run and log and check process    ${command}

Create CB bucket if it does not exist
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${ramQuota}=100
    [Documentation]    Create a couchbase bucket if it does not exist.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}
    ${resp}=    Run and log request on session    ${req}    GET    host=${host}    user=${user}    password=${password}
    ...         log_response=False
    Return from keyword if    ${resp.status_code} == 200
    ${req}=    Set Variable    /pools/default/buckets
    ${pd}=    Set Variable    {"name":"${bucket}","ramQuota":${ramQuota},"replicaNumber":0,"bucketType":"couchbase"}
    Run and log and check request on session    ${req}    POST    200    payload=${pd}    host=${host}    user=${user}
    ...                                         password=${password}

Set ramQuota
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${ramQuota}=100
    [Documentation]    Set a buckets RAM quota.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}
    ${pd}=    Set Variable    {"ramQuota":${ramQuota}}
    Run and log and check request on session    ${req}    POST    200    payload=${pd}    host=${host}    user=${user}
    ...                                         password=${password}

Disable flush
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Enable flush for a bucket.
    ${command}=    Create List    ${BIN_PATH}${/}couchbase-cli    bucket-edit    -c    ${host}    -u    ${user}
    ...            -p    ${password}    --bucket    ${bucket}    --enable-flush    0
    Run and log and check process    ${command}

Enable flush
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Enable flush for a bucket.
    ${command}=    Create List    ${BIN_PATH}${/}couchbase-cli    bucket-edit    -c    ${host}    -u    ${user}
    ...            -p    ${password}    --bucket    ${bucket}    --enable-flush    1
    Run and log and check process    ${command}

Flush bucket REST
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Flush all documents from a bucket.
    ${items}=    Get current item number    ${bucket}
    Return from keyword if    ${items} == 0
    ${original_uuids}=    Get vbucket uuids          ${bucket}       ${user}         ${password}
    ${req}=    Set Variable    /pools/default/buckets/${bucket}/controller/doFlush
    Run and log and check request on session    ${req}    POST    200    host=${host}    user=${user}
    ...                                         password=${password}
    FOR    ${i}    IN RANGE    10
        ${dbg_curr_items}=    Get current item number    ${bucket}
        ${uuids}=             Get vbucket uuids  ${bucket}       ${user}         ${password}
        ${res}=               All vbucket uuids different  ${original_uuids}      ${uuids}
        Return from keyword if    ${res}
        exponential sleep    ${i}
    END
    Fail    Timeout: Bucket failed to be flushed

Delete bucket if it does exist cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Delete a bucket.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}
    ${resp}=    Run and log request on session    ${req}    GET    host=${host}    user=${user}    password=${password}
    ...         log_response=False
    Return from keyword if    ${resp.status_code} != 200
    ${command}=    Create List    ${BIN_PATH}${/}couchbase-cli    bucket-delete    -c    ${host}    -u    ${user}    -p
    ...                           ${password}    --bucket    ${bucket}
    Run and log and check process    ${command}
    Sleep    5

Load documents into bucket using cbm
    [Arguments]    ${items}=1000    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024
    [Documentation]    Uses cbbackupmgr generator to load data into the bucket
    ${command}=    Create List    ${BIN_PATH}${/}cbbackupmgr    generate    -c    ${host}    -u    ${user}
    ...            -p     ${password}     -n    ${items}    -b     ${bucket}    -L    -j    -s    ${size}
    Run and log and check process    ${command}

Load documents into bucket using cbc
    [Arguments]    ${scope}=default    ${collection}=default    ${host}=http://localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd    ${bucket}=default    ${key}=pymc    ${group}=example
    [Documentation]    Uses cbc-create to load data into the scope.
    FOR    ${i}    IN RANGE    10
        ${result}=    Run process    ${BIN_PATH}${/}cbc    create    -U    ${host}/${bucket}    -u    ${user}
        ...           -P     ${password}    --scope    ${scope}    --collection    ${collection}
        ...           --json    ${key}${i}    -V    {"group":"${group}","num":${i}}
        Should be equal as integers    ${result.rc}    0
    END

Load documents into bucket using cbc bucket level
    [Arguments]    ${host}=http://localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd    ${bucket}=default    ${key}=key    ${group}=example    ${items}=10
    [Documentation]    Uses cbc-create to load data into the scope.
    ${previous_items}=    Get item count    bucket=${bucket}
    FOR    ${i}    IN RANGE    ${items}
        ${result}=    Run process    ${BIN_PATH}${/}cbc    create    -U    ${host}/${bucket}    -u    ${user}
        ...           -P     ${password}    --json    ${key}${i}    -V    {"group":"${group}","num":${i}}
        Should be equal as integers    ${result.rc}    0
    END
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Load documents into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load json docs with no xattr into the bucket
    ${previous_items}=    Get item count    bucket=${bucket}
    ${command}=    Create List    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...            -i    ${items}    -b     ${bucket}    -j    -s    ${size}    -t    ${THREADS}
    ...            --prefix    ${key-pref}
    Run and log and check process    ${command}    check_stderr=False    stdout=${TEMPDIR}/stdout.txt
    ...                              stderr=DEVNULL
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Load documents with xattr into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000   ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load json docs with xattr into the bucket
    ${previous_items}=    Get item count    bucket=${bucket}
    ${command}=    Create List    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...            -i    ${items}    -b     ${bucket}    -j    -s    ${size}    -t    ${THREADS}
    ...            --prefix    ${key-pref}    --xattr
    Run and log and check process    ${command}    check_stderr=False
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Load Binary documents into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000   ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load binary docs with no xattr into the bucket
    ${previous_items}=    Get item count    bucket=${bucket}
    ${command}=    Create List    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...            -i    ${items}    -b     ${bucket}    -s    ${size}    -t    ${THREADS}
    ...            --prefix    ${key-pref}
    Run and log and check process    ${command}    check_stderr=False
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Load Binary documents with xattr into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000  ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load binary docs with xattr into the bucket
    ${previous_items}=    Get item count    bucket=${bucket}
    ${command}=    Create List    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...            -i    ${items}    -b     ${bucket}    -s    ${size}    -t    ${THREADS}
    ...            --prefix    ${key-pref}    --xattr
    Run and log and check process    ${command}    check_stderr=False
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Get bucket uuid
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Get a buckets uuid.
    ${req}=    Set Variable    /pools/default/buckets/${bucket}
    ${resp}=    Run and log and check request on session    ${req}    GET    200    host=${host}    user=${user}
    ...         password=${password}    log_response=False
    Return from keyword    ${resp.json()["uuid"]}

Get item count
    [Arguments]    ${bucket}    ${host}=localhost   ${user}=Administrator    ${password}=asdasd
    [Documentation]    Get the number of items that have been persisted to disk in a bucket.
    ${ports}=    Get service ports    bucket=${bucket}
    ${req}=    Set Variable    /pools/default/buckets/${bucket}
    ${resp}=    Run and log request on session    ${req}    GET    host=http://${host}:${ports['mgmt']}    user=${user}
    ...         password=${password}    log_response=False
    Return from keyword if    ${resp.status_code} != 200    0
    FOR    ${i}    IN RANGE    5
        ${command}=    Create List     ${BIN_PATH}${/}cbstats    -u    ${user}    -p    ${password}
        ...            -b    ${bucket}    ${host}:${ports['kv']}    -j    all
        ${result}=    Run and log and check process    ${command}    log_stdout=False    check_exit_code=False
        Exit for loop if    ${result.rc}==0
        Sleep    1
    END
    Should Be Equal As Integers    ${result.rc}    0
    ${result_dict}=    Evaluate    json.loads('''${result.stdout}''')    json
    Return from keyword    ${result_dict['ep_total_persisted']}

Get current item number
    [Arguments]    ${bucket}=default    ${host}=localhost   ${user}=Administrator    ${password}=asdasd
    [Documentation]    Get the number of items currently in a bucket (not necessarily persisted to disk).
    ${ports}=    Get service ports    bucket=${bucket}
    ${command}=    Create List     ${BIN_PATH}${/}cbstats    -u    ${user}    -p    ${password}
    ...            -b    ${bucket}    ${host}:${ports['kv']}    -j    all
    ${result}=    Run and log and check process    ${command}    log_stdout=False
    ${result_dict}=    Evaluate    json.loads('''${result.stdout}''')    json
    Return from keyword    ${result_dict['curr_items']}

Get service ports
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Gets the ports for a node.
    ${req}=    Set Variable    /pools/default/nodeServices
    ${resp}=    Run and log and check request on session    ${req}    GET    200    host=${host}    user=${user}
    ...         password=${password}
    ${num_nodes}=    Get Length    ${resp.json()['nodesExt']}
    FOR    ${node}    IN RANGE    ${num_nodes}
        Return from keyword if    '${resp.json()['nodesExt'][${node}]['thisNode']}'=='True'
        ...                       ${resp.json()['nodesExt'][${node}]['services']}
    END
    Fail    Node not found

Wait for items to be persisted to disk
    [Arguments]    ${previous_items}    ${items}    ${bucket}=default
    [Documentation]    Checks the expected number of items have been persisted to disk.
    ${dbg_curr_items}=    Get current item number    ${bucket}
    FOR    ${i}   IN RANGE    10
        ${result}=    Get item count    bucket=${bucket}
        ${expected_result}=    Evaluate    ${previous_items}+${items}
        Return from keyword if    ${result}==${expected_result}
        Run keyword if    ${result}>=${expected_result}
        ...               Log    Cannot confirm correct number of docs persisted to disk    WARN
        Exponential sleep    ${i}
        Return from keyword if    ${result}>=${expected_result}
    END
    Fail    Timeout: Not all docs persisted to disk

Load data to all services
    [Arguments]    ${bucket}=default    ${data_items}=2048
    [Documentation]    Load data to all couchbase services.
    Load index data        bucket=${bucket}
    Load documents into bucket using cbc bucket level    items=${data_items}    bucket=${bucket}
    Load fts data          bucket=${bucket}
    Load analytics data    bucket=${bucket}
    Load eventing data    func_file_name=eventing_function.txt    func_name=eventing_func    bucket=${bucket}
    ...                   scope=_default
    Load eventing data    func_file_name=eventing_function_legacy.txt    func_name=eventing_func_legacy
    ...                   collection_aware=False

Exponential sleep
    [Arguments]    ${iteration}
    [Documentation]    Sleep for an amount of time that increases exponentially with each loop.
    ${time}=      Evaluate    0.5*(${iteration}+1)**2
    Sleep    ${time}

Wait for indexer to be active
    [Arguments]    ${host}=http://localhost    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Waits until the indexer is in an active state.
    FOR    ${i}    IN RANGE    10
        ${ports}=    Get service ports
        Log To Console    ${ports}     DEBUG
        Exit for loop if    'indexHttp' in ${ports}
        Exponential sleep    ${i}
    END
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}:${ports['indexHttp']}    auth=${auth}
    ${req}=    Set Variable    /api/v1/stats
    FOR    ${i}    IN RANGE    10
        ${resp}=    Run and log and check request on session    ${req}    GET    200    host=${host}
        ...         session=admin_api    log_response=True
        Return from keyword if    '${resp.json()}[indexer][indexer_state]' == 'Active'
        Exponential sleep    ${i}
    END
    Fail    Indexer failed to enter active state
