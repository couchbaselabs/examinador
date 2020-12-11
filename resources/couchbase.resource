*** Settings ***
Library    RequestsLibrary
Library    Process

*** Variables ***
${BIN_PATH}    %{HOME}${/}source${/}install${/}bin
${THREADS}     1
${CBWORKLOADGEN_WAIT_TIME}    20

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
    ...                        --bucket-replica    0    --bucket-type    couchbase    --enable-flush    1
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
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}/collections/${scope}
    Return from keyword if    ${resp.status_code} == 200
    ${resp}=    Post request    admin_api    /pools/default/buckets/${bucket}/collections    {"name":"${scope}"}
    Status should be    200    ${resp}

Create CB scope if it does not exist cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default
    [Documentation]    Create a couchbase scope if it does not exist.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}/collections/${scope}
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
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}/collections
    Status should be    200    ${resp}
    Return from keyword    ${resp.json()}

Create collection if it does not exist
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default     ${collection}=default
    [Documentation]    Create a collection within a given scope if it does not already exist.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}/collections/${scope}/${collection}
    Return from keyword if    ${resp.status_code} == 200
    ${resp}=    Post request    admin_api    /pools/default/buckets/${bucket}/collections/${scope}
    ...          {"name":${collection}}
    Status should be    200    ${resp}

Create collection if it does not exist cli
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${scope}=default     ${collection}=default
    [Documentation]    Create a collection within a given scope if it does not already exist.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}/collections/${scope}/${collection}
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

Flush bucket REST
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${ramQuota}=100
    [Documentation]    Flush all documents from a bucket.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Post request    admin_api    /pools/default/buckets/${bucket}    {"flushEnabled":1}
    Status should be    200    ${resp}
    ${resp}=    Post request    admin_api    /pools/default/buckets/${bucket}/controller/doFlush
    Status should be    200    ${resp}

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
    FOR    ${i}    IN RANGE    ${items}
        ${result}=    Run process    ${BIN_PATH}${/}cbc    create    -U    ${host}/${bucket}    -u    ${user}
        ...                         -P     ${password}    --json    ${key}${i}    -V    {"group":"${group}","num":${i}}
        Should Be Equal As Integers    ${result.rc}    0
    END

Load documents into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load data into the bucket
    ${result}=    Run process    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...                          -i    ${items}    -b     ${bucket}    -j    -s    ${size}    -t    ${THREADS}
    ...                          --prefix    ${key-pref}    stdout=${TEMPDIR}/stdout.txt     stderr=DEVNULL
    Should Be Equal As Integers    ${result.rc}    0
    Sleep    ${CBWORKLOADGEN_WAIT_TIME}

Load documents with xattr into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000   ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load data into the bucket
    ${result}=    Run process    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...                          -i    ${items}    -b     ${bucket}    -j    -s    ${size}    -t    ${THREADS}
    ...                          --prefix    ${key-pref}    --xattr
    Should Be Equal As Integers    ${result.rc}    0
    Sleep    ${CBWORKLOADGEN_WAIT_TIME}

Load Binary documents into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000   ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load data into the bucket
    ${result}=    Run process    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...                          -i    ${items}    -b     ${bucket}    -s    ${size}    -t    ${THREADS}
    ...                          --prefix    ${key-pref}
    Should Be Equal As Integers    ${result.rc}    0
    Sleep    ${CBWORKLOADGEN_WAIT_TIME}

Load Binary documents with xattr into bucket using cbworkloadgen
    [Arguments]    ${items}=2048    ${bucket}=default    ${host}=localhost:9000   ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024    ${key-pref}=pymc
    [Documentation]    Uses cbworkloadgen to load data into the bucket
    ${result}=    Run process    ${BIN_PATH}${/}cbworkloadgen    -n    ${host}    -u    ${user}    -p     ${password}
    ...                          -i    ${items}    -b     ${bucket}    -s    ${size}    -t    ${THREADS}
    ...                          --prefix    ${key-pref}    --xattr
    Should Be Equal As Integers    ${result.rc}    0
    Sleep    ${CBWORKLOADGEN_WAIT_TIME}

Get bucket uuid
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    [Documentation]    Get a buckets uuid.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}
    Status should be    200    ${resp}
    Return from keyword    ${resp.json()["uuid"]}
