*** Settings ***
Library            RequestsLibrary
Library            Process
Resource           ../resources/couchbase.resource
Resource           ../resources/common.resource

*** Variables ***
${BIN_PATH}    ${SOURCE}${/}install${/}bin
${THREADS}     1
${CBWORKLOADGEN_WAIT_TIME}    20
${WORKSPACE}    %{PWD}

*** Keywords ***
Load eventing data
    [Arguments]    ${func_file_name}    ${func_name}    ${host}=http://localhost:9000   ${user}=Administrator
    ...            ${password}=asdasd    ${bucket}=default    ${scope}=_default    ${collection_aware}=True
    [Documentation]    Load and deploy an eventing function.
    ${command}=        Create List     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
    ...                -u    ${user}    -p    ${password}    --import    --file    ${func_file_name}
    Run and log and check process    ${command}
    ${command}=        Create List     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
    ...                -u    ${user}    -p    ${password}    --deploy    --name    ${func_name}
    IF    ${collection_aware}
    Append To List    ${command}    --bucket    ${bucket}    --scope    ${scope}
    END
    Run and log and check process    ${command}
    FOR    ${i}   IN RANGE    10
        ${status}=    Check eventing function deployed    func_name=${func_name}    bucket=${bucket}    scope=${scope}
        ...           collection_aware=${collection_aware}
        Exit for loop IF    '${status}' == 'deployed'
        Exponential sleep    ${i}
    END

Delete eventing function data
    [Arguments]    ${func_name}    ${host}=http://localhost:9000   ${user}=Administrator    ${password}=asdasd
    ...            ${bucket}=default    ${scope}=_default    ${collection_aware}=True
    [Documentation]    Delete an eventing function.
    ${command}=        Create List     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
    ...                -u    ${user}    -p    ${password}    --undeploy    --name    ${func_name}
    IF    ${collection_aware}
    Append To List    ${command}    --bucket    ${bucket}    --scope    ${scope}
    END
    Run and log and check process    ${command}
    FOR    ${i}   IN RANGE    10
        ${status}=    Check eventing function deployed    func_name=${func_name}    bucket=${bucket}    scope=${scope}
        ...           collection_aware=${collection_aware}
        Exit for loop IF    '${status}' == 'undeployed'
        Exponential sleep    ${i}
    END
    FOR    ${i}   IN RANGE    9
        ${command}=        Create List     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
        ...                -u    ${user}    -p    ${password}    --delete    --name    ${func_name}
        IF    ${collection_aware}
        Append To List    ${command}    --bucket    ${bucket}    --scope    ${scope}
        END
        ${result}=    Run and log and check process    ${command}    check_exit_code=False
        ${exit}=    Evaluate    ${result.rc} == 0
        Exit for loop IF    ${exit}
        Exponential sleep    ${i}
    END
    FOR    ${i}   IN RANGE    8
        ${status}=    Check eventing function exists    func_name=${func_name}    bucket=${bucket}    scope=${scope}
        ...           collection_aware=${collection_aware}
        Exit for loop IF    ${status}==False
        Exponential sleep    ${i}
    END

Delete all eventing data
    [Documentation]    Delete all eventing functions.
    Delete eventing function data    func_name=eventing_func    bucket=default    scope=_default
    Delete eventing function data    func_name=eventing_func_legacy    collection_aware=False

Check eventing function exists
    [Arguments]    ${func_name}    ${bucket}=default    ${host}=http://localhost    ${user}=Administrator
    ...            ${password}=asdasd    ${scope}=_default    ${collection_aware}=True
    [Documentation]    Check the eventing function given as func_name has been created.
    ${ports}=    Get service ports    bucket=${bucket}
    ${req}=    Set Variable    /api/v1/status/${func_name}
    IF    ${collection_aware}
    ${params}=    Create Dictionary    bucket=${bucket}    scope=_default
    ELSE
    ${params}=    Set Variable    ${NONE}
    END
    ${resp}=    Run and log request on session    ${req}    GET    host=${host}:${ports['eventingAdminPort']}
    ...         user=${user}    password=${password}    params=${params}
    Return from keyword if    ${resp.status_code}==200    True
    Return from keyword    False

Check eventing function deployed
    [Arguments]    ${func_name}    ${bucket}=default    ${host}=http://localhost    ${user}=Administrator
    ...            ${password}=asdasd    ${scope}=_default    ${collection_aware}=True
    [Documentation]    Check the eventing function given as func_name has been deployed.
    ${ports}=    Get service ports    bucket=${bucket}
    ${req}=    Set Variable    /api/v1/status/${func_name}
    IF    ${collection_aware}
    ${params}=    Create Dictionary    bucket=${bucket}    scope=_default
    ELSE
    ${params}=    Set Variable    ${NONE}
    END
    ${resp}=    Run and log and check request on session    ${req}    GET    200
    ...         host=${host}:${ports['eventingAdminPort']}    user=${user}    password=${password}    params=${params}
    ...         log_response=True
    Return from keyword if    '${resp.json()['app']['name']}'=='${func_name}'
    ...                        ${resp.json()['app']['composite_status']}
    Fail    Eventing function ${func_name} doesn't exist

Confirm existence status of all eventing functions
    [Arguments]    ${should_exist}
    [Documentation]    Check that all eventing functions either exist or do not exist as expected.
    FOR    ${i}   IN RANGE    8
        ${func_exists}=    Check eventing function exists    func_name=eventing_func    bucket=default    scope=_default
        Exit for loop IF    ${func_exists}==${should_exist}
        Exponential sleep    ${i}
    END
    Return from keyword if    ${func_exists}!=${should_exist}    False
    FOR    ${i}   IN RANGE    8
        ${func_exists}=    Check eventing function exists    func_name=eventing_func_legacy    collection_aware=False
        Exit for loop IF    ${func_exists}==${should_exist}
        Exponential sleep    ${i}
    END
    Return from keyword if    ${func_exists}!=${should_exist}    False
    Return from keyword    True
