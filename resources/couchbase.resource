*** Settings ***
Library    RequestsLibrary
Library    Process

*** Variables ***
${BIN_PATH}    %{HOME}/source/install/bin

*** Keywords ***
Create CB bucket if it does not exist
    [Arguments]    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ...            ${ramQuota}=100
    [Documentation]    Create a couchbase bucket if it does not exist.
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}    auth=${auth}
    ${resp}=    Get request    admin_api    /pools/default/buckets/${bucket}
    Return from keyword if    ${resp.status_code} == 200
    ${resp}=    Post request    admin_api    /pools/default/buckets    {"name":"${bucket}","ramQuota":${ramQuota},"replicaNumber":0,"bucketType":"couchbase"}
    Status should be    200    ${resp}

Load documents into bucket using cbm
    [Arguments]    ${items}=1000    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd    ${size}=1024
    [Documentation]    Uses cbbackupmgr generator to load data into the bucket
    ${result}=    Run process    ${BIN_PATH}/cbbackupmgr    generate    -c    ${host}    -u    ${user}    -p     ${password}
    ...           -n    ${items}    -b     ${bucket}    -L    -j    -s    ${size}
    Should Be Equal As Integers    ${result.rc}    0
