*** Settings ***
Library    RequestsLibrary
Library    Process

*** Variables ***
${BIN_PATH}    %{HOME}${/}source${/}install${/}bin
${THREADS}     1
${CBWORKLOADGEN_WAIT_TIME}    20
${WORKSPACE}    %{PWD}

*** Keywords ***
Create CB bucket if it does not exist cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${ramQuota}=100
    [Documentation]    Create a couchbase bucket if it does not exist, using the couchbase-cli.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}
    Return from keyword if    ${resp.status_code} == 200
    ${resp}=    Run process    ${BIN_PATH}${/}couchbase-cli    bucket-create    -c    ${host}    -u    ${user}
    ...                        -p    ${password}    --bucket    ${bucket}    --bucket-ramsize    ${ramQuota}
    ...                        --bucket-replica    0    --bucket-type    couchbase    --enable-flush    1    --wait
    Log To Console    ${resp.stdout}     DEBUG
    Should be equal as integers    ${resp.rc}    0
    Sleep    5

Set index memory quota
    [Arguments]    ${host}=localhost:9000    ${user}=Administrator    ${password}=asdasd    ${ramQuota}=400
    [Documentation]    Set the RAM quota for the Index service.
    ${resp}=    Run process    ${BIN_PATH}${/}couchbase-cli    setting-cluster    -c    ${host}    -u    ${user}
    ...                        -p    ${password}    --cluster-index-ramsize     ${ramQuota}
    Should be equal as integers    ${resp.rc}    0

Delete bucket cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Delete a bucket using the bucket-delete couchbase-cli command.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}
    Return from keyword if    ${resp.status_code} != 200
    ${resp}=    Run process    ${BIN_PATH}${/}couchbase-cli    bucket-delete    -c    ${host}    -u    ${user}
    ...                        -p    ${password}    --bucket    ${bucket}
    Should be equal as integers    ${resp.rc}    0

Create CB scope if it does not exist
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default
    [Documentation]    Create a couchbase scope if it does not exist.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}/scopes/${scope}
    Return from keyword if    ${resp.status_code} == 200
    ${resp}=    Post request    admin_api    /pools/default/buckets/${bucket}/scopes    {"name":"${scope}"}
    Status should be    200    ${resp}

Create CB scope if it does not exist cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default
    [Documentation]    Create a couchbase scope if it does not exist.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}/scopes/${scope}
    Return from keyword if    ${resp.status_code} == 200
    ${resp}=    Run process    ${BIN_PATH}${/}couchbase-cli    collection-manage    -c    ${host}    -u    ${user}
    ...                        -p    ${password}    --bucket    ${bucket}    --create-scope    ${scope}
    Should be equal as integers    ${resp.rc}    0

Get scopes info
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default
    [Documentation]    Get information on existing scopes.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}/scopes
    Status should be    200    ${resp}
    Return from keyword    ${resp.json()}

Create collection if it does not exist
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default     ${collection}=default
    [Documentation]    Create a collection within a given scope if it does not already exist.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}/scopes/${scope}/${collection}
    Return from keyword if    ${resp.status_code} == 200
    ${resp}=    Post request    admin_api    /pools/default/buckets/${bucket}/scopes/${scope}
    ...          {"name":${collection}}
    Status should be    200    ${resp}

Create collection if it does not exist cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default     ${collection}=default
    [Documentation]    Create a collection within a given scope if it does not already exist.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}/scopes/${scope}/${collection}
    Return from keyword if    ${resp.status_code} == 200
    ${resp}=    Run process    ${BIN_PATH}${/}couchbase-cli    collection-manage    -c    ${host}    -u    ${user}
    ...                      -p    ${password}    --bucket    ${bucket}    --create-collection    ${scope}.${collection}
    Should be equal as integers    ${resp.rc}    0

Create CB bucket if it does not exist
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${ramQuota}=100
    [Documentation]    Create a couchbase bucket if it does not exist.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}
    Return from keyword if    ${resp.status_code} == 200
    ${resp}=    Post request    admin_api    /pools/default/buckets
    ...          {"name":"${bucket}","ramQuota":${ramQuota},"replicaNumber":0,"bucketType":"couchbase"}
    Status should be    200    ${resp}

Set ramQuota
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${ramQuota}=100
    [Documentation]    Set a buckets RAM quota.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Post request    admin_api    /pools/default/buckets/${bucket}    {"ramQuota":${ramQuota}}
    Status should be    200    ${resp}

Enable flush
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Flush all documents from a bucket.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Post request    admin_api    /pools/default/buckets/${bucket}    {"flushEnabled":1}
    Status should be    200    ${resp}

Flush bucket REST
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Flush all documents from a bucket.
    ${items}=    Get current item number    ${bucket}
    Return from keyword if    ${items} == 0
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Post request    admin_api    /pools/default/buckets/${bucket}/controller/doFlush
    Status should be    200    ${resp}
    FOR    ${i}    IN RANGE    10
        ${items}=    Get current item number    ${bucket}
        Return from keyword if    ${items} == 0
        exponential sleep    ${i}
    END
    Fail    Timeout: Bucket failed to be flushed

Load documents into bucket using cbm
    [Arguments]    ${items}=1000    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024
    [Documentation]    Uses cbbackupmgr generator to load data into the bucket
    ${result}=    Run process    ${BIN_PATH}${/}cbbackupmgr    generate    -c    ${host}    -u    ${user}
    ...           -p     ${password}     -n    ${items}    -b     ${bucket}    -L    -j    -s    ${size}
    Should Be Equal As Integers    ${result.rc}    0

Load documents into bucket using cbc
    [Arguments]    ${scope}=default    ${collection}=default    ${host}=http://localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd    ${bucket}=default    ${key}=pymc    ${group}=example
    [Documentation]    Uses cbc-create to load data into the scope.
    FOR    ${i}    IN RANGE    10
        ${result}=    Run process    ${BIN_PATH}${/}cbc    create    -U    ${host}/${bucket}    -u    ${user}
        ...                          -P     ${password}    --scope    ${scope}    --collection    ${collection}
        ...                          --json    ${key}${i}    -V    {"group":"${group}","num":${i}}
        Should Be Equal As Integers    ${result.rc}    0
    END

Load documents into bucket using cbc bucket level
    [Arguments]    ${host}=http://localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd    ${bucket}=default    ${key}=key    ${group}=example    ${items}=10
    [Documentation]    Uses cbc-create to load data into the scope.
    ${previous_items}=    Get item count    bucket=${bucket}
    FOR    ${i}    IN RANGE    ${items}
        ${result}=    Run process    ${BIN_PATH}${/}cbc    create    -U    ${host}/${bucket}    -u    ${user}
        ...                         -P     ${password}    --json    ${key}${i}    -V    {"group":"${group}","num":${i}}
        Should Be Equal As Integers    ${result.rc}    0
    END
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Load documents into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load json docs with no xattr into the bucket
    ${previous_items}=    Get item count    bucket=${bucket}
    ${result}=    Run process    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...                          -i    ${items}    -b     ${bucket}    -j    -s    ${size}    -t    ${THREADS}
    ...                          --prefix    ${key-pref}    stdout=${TEMPDIR}/stdout.txt     stderr=DEVNULL
    Log To Console    ${result.stdout}     DEBUG
    Should Be Equal As Integers    ${result.rc}    0
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Load documents with xattr into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000   ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load json docs with xattr into the bucket
    ${previous_items}=    Get item count    bucket=${bucket}
    ${result}=    Run process    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...                          -i    ${items}    -b     ${bucket}    -j    -s    ${size}    -t    ${THREADS}
    ...                          --prefix    ${key-pref}    --xattr
    Log To Console    ${result.stdout}     DEBUG
    Should Be Equal As Integers    ${result.rc}    0
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Load Binary documents into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000   ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load binary docs with no xattr into the bucket
    ${previous_items}=    Get item count    bucket=${bucket}
    ${result}=    Run process    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...                          -i    ${items}    -b     ${bucket}    -s    ${size}    -t    ${THREADS}
    ...                          --prefix    ${key-pref}
    Log To Console    ${result.stdout}     DEBUG
    Should Be Equal As Integers    ${result.rc}    0
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Load Binary documents with xattr into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000  ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load binary docs with xattr into the bucket
    ${previous_items}=    Get item count    bucket=${bucket}
    ${result}=    Run process    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...                          -i    ${items}    -b     ${bucket}    -s    ${size}    -t    ${THREADS}
    ...                          --prefix    ${key-pref}    --xattr
    Log To Console    ${result.stdout}     DEBUG
    Should Be Equal As Integers    ${result.rc}    0
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Get bucket uuid
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Get a buckets uuid.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}
    Status should be    200    ${resp}
    Return from keyword    ${resp.json()["uuid"]}

Get item count
    [Arguments]    ${bucket}    ${host}=localhost   ${user}=Administrator    ${password}=asdasd
    [Documentation]    Get the number of items that have been persisted to disk in a bucket.
    ${ports}=    Get service ports    bucket=${bucket}
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    http://${host}:${ports['mgmt']}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}
    Return from keyword if    ${resp.status_code} != 200    0
    FOR    ${i}    IN RANGE    5
        ${result}=         Run Process     ${BIN_PATH}${/}cbstats    -u    ${user}    -p    ${password}
        ...                -b    ${bucket}    ${host}:${ports['kv']}    -j    all
        Exit for loop if    ${result.rc}==0
        Log To Console    ${result.stdout}     DEBUG
        Sleep    1
    END
    Should Be Equal As Integers    ${result.rc}    0
    ${result_dict}=    Evaluate    json.loads('''${result.stdout}''')    json
    Return from keyword    ${result_dict['ep_total_persisted']}

Get current item number
    [Arguments]    ${bucket}=default    ${host}=localhost   ${user}=Administrator    ${password}=asdasd
    [Documentation]    Get the number of items currently in a bucket (not necessarily persisted to disk).
    ${ports}=    Get service ports    bucket=${bucket}
    ${result}=         Run Process     ${BIN_PATH}${/}cbstats    -u    ${user}    -p    ${password}
    ...                -b    ${bucket}    ${host}:${ports['kv']}    -j    all
    Should Be Equal As Integers    ${result.rc}    0
    ${result_dict}=    Evaluate    json.loads('''${result.stdout}''')    json
    Return from keyword    ${result_dict['curr_items']}

Get service ports
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Gets the ports for a node.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/nodeServices
    Status should be    200    ${resp}
    ${num_nodes}=    Get Length    ${resp.json()['nodesExt']}
    FOR    ${node}    IN RANGE    ${num_nodes}
        Return from keyword if    '${resp.json()['nodesExt'][${node}]['thisNode']}'=='True'
        ...                       ${resp.json()['nodesExt'][${node}]['services']}
    END
    Fail    Node not found

Wait for items to be persisted to disk
    [Arguments]    ${previous_items}    ${items}    ${bucket}=default
    [Documentation]    Checks the expected number of items have been persisted to disk.
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
    Load eventing data

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
    FOR    ${i}    IN RANGE    10
        ${resp}=    Get request    admin_api    /api/v1/stats
        Log To Console    ${resp.json()}     DEBUG
        Status should be    200    ${resp}
        Return from keyword if    '${resp.json()}[indexer][indexer_state]' == 'Active'
        Exponential sleep    ${i}
    END
    Fail    Indexer failed to enter active state
