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
@{EVENTING_FUNCS}=    eventing_func    eventing_func_legacy

*** Keywords ***
Load eventing data
    [Arguments]    ${func_file_name}    ${func_name}    ${host}=http://localhost:9000   ${user}=Administrator
    ...            ${password}=asdasd
    [Documentation]    Load and deploy an eventing function.
    ${command}=        Create List     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
    ...                -u    ${user}    -p    ${password}    --import    --file    ${func_file_name}
    Run and log and check process    ${command}
    ${command}=        Create List     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
    ...                -u    ${user}    -p    ${password}    --deploy    --name    ${func_name}
    Run and log and check process    ${command}
    FOR    ${i}   IN RANGE    10
        ${command}=        Create List     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
        ...                -u    ${user}    -p    ${password}    --list
        Run and log and check process    ${command}
        ${status}=    Check eventing function deployed    func_name=${func_name}
        Exit for loop IF    ${status}
        Exponential sleep    ${i}
    END

Delete eventing function data
    [Arguments]    ${func_name}    ${host}=http://localhost:9000   ${user}=Administrator    ${password}=asdasd
    [Documentation]    Delete an eventing function.
    ${command}=        Create List     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
    ...                -u    ${user}    -p    ${password}    --undeploy    --name    ${func_name}
    Run and log and check process    ${command}
    FOR    ${i}   IN RANGE    10
        ${command}=        Create List     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
        ...                -u    ${user}    -p    ${password}    --list
        Run and log and check process    ${command}
        ${status}=    Check eventing function deployed    func_name=${func_name}
        Exit for loop IF    not ${status}
        Exponential sleep    ${i}
    END
    FOR    ${i}   IN RANGE    9
        ${command}=        Create List     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
        ...                -u    ${user}    -p    ${password}    --delete    --name    ${func_name}
        ${result}=    Run and log and check process    ${command}    check_exit_code=False
        ${exit}=    Evaluate    ${result.rc} == 0
        Exit for loop IF    ${exit}
        Exponential sleep    ${i}
    END
    FOR    ${i}   IN RANGE    8
        ${status}=    Check eventing function exists    func_name=${func_name}
        Exit for loop IF    ${status}==False
        Exponential sleep    ${i}
    END

Delete all eventing data
    [Documentation]    Delete all eventing functions.
    FOR    ${func_name}    IN    @{EVENTING_FUNCS}
        Delete eventing function data    func_name=${func_name}
    END

Check eventing function exists
    [Arguments]    ${func_name}    ${bucket}=default    ${host}=http://localhost    ${user}=Administrator
    ...            ${password}=asdasd
    [Documentation]    Check the eventing function given as func_name has been created.
    ${ports}=    Get service ports    bucket=${bucket}
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}:${ports['eventingAdminPort']}    auth=${auth}
    ${resp}=    Get request    admin_api    /api/v1/functions/${func_name}
    Return from keyword if    ${resp.status_code}==200    True
    Return from keyword    False

Check eventing function deployed
    [Arguments]    ${func_name}    ${bucket}=default    ${host}=http://localhost    ${user}=Administrator
    ...            ${password}=asdasd
    [Documentation]    Check the eventing function given as func_name has been deployed.
    ${ports}=    Get service ports    bucket=${bucket}
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}:${ports['eventingAdminPort']}    auth=${auth}
    ${resp}=    Get request    admin_api    /api/v1/functions/${func_name}
    Log To Console    ${resp.json()}     DEBUG
    Should be equal as integers    ${resp.status_code}    200
    Return from keyword if    '${resp.json()['appname']}'=='${func_name}'
    ...                        ${resp.json()['settings']['deployment_status']}
    Fail    Eventing function ${func_name} doesn't exist

Confirm existence status of all eventing functions
    [Arguments]    ${should_exist}
    [Documentation]    Check that all eventing functions either exist or do not exist.
    FOR    ${func_name}    IN    @{EVENTING_FUNCS}
        ${func_exists}=    Check eventing function exists    func_name=${func_name}
        Return from keyword if    ${func_exists}!=${should_exist}    False
    END
    Return from keyword    True