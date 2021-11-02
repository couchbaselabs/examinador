*** Settings ***
Library    RequestsLibrary
Library    Process
Resource           ../resources/couchbase.resource

*** Variables ***
${BIN_PATH}    %{HOME}${/}source${/}install${/}bin
${THREADS}     1
${CBWORKLOADGEN_WAIT_TIME}    20
${WORKSPACE}    %{PWD}

*** Keywords ***
Load eventing data
    [Arguments]    ${host}=http://localhost:9000   ${user}=Administrator    ${password}=asdasd
    [Documentation]    Load and deploy an eventing function.
    ${result}=         Run Process     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
    ...                -u    ${user}    -p    ${password}    --import    --file    eventing_function.txt
    Log To Console    ${result.stdout}     DEBUG
    Should Be Equal As Integers    ${result.rc}    0
    ${result}=         Run Process     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
    ...                -u    ${user}    -p    ${password}    --deploy    --name    eventing_func
    ...                --boundary    from-now
    Log To Console    ${result.stdout}     DEBUG
    Should Be Equal As Integers    ${result.rc}    0
    FOR    ${i}   IN RANGE    10
        ${result}=         Run Process     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
        ...                -u    ${user}    -p    ${password}    --list
        Log To Console    ${result.stdout}     DEBUG
        Should Be Equal As Integers    ${result.rc}    0
        ${status}=    Check eventing function deployed
        Exit for loop IF    ${status}
        Exponential sleep    ${i}
    END

Delete eventing data
    [Arguments]    ${host}=http://localhost:9000   ${user}=Administrator    ${password}=asdasd
    [Documentation]    Delete an eventing function.
    ${result}=         Run Process     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
    ...                -u    ${user}    -p    ${password}    --undeploy    --name    eventing_func
    Log To Console    ${result.stdout}     DEBUG
    Should Be Equal As Integers    ${result.rc}    0
    FOR    ${i}   IN RANGE    10
        ${result}=         Run Process     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
        ...                -u    ${user}    -p    ${password}    --list
        Log To Console    ${result.stdout}     DEBUG
        Should Be Equal As Integers    ${result.rc}    0
        ${status}=    Check eventing function deployed
        Exit for loop IF    not ${status}
        Exponential sleep    ${i}
    END
    FOR    ${i}   IN RANGE    9
        ${result}=         Run Process     ${BIN_PATH}${/}couchbase-cli    eventing-function-setup    -c    ${host}
        ...                -u    ${user}    -p    ${password}    --delete    --name    eventing_func
        Log To Console    ${result.stdout}     DEBUG
        ${exit}=    Evaluate    ${result.rc} == 0
        Exit for loop IF    ${exit}
        Exponential sleep    ${i}
    END
    FOR    ${i}   IN RANGE    8
        ${status}=    Check eventing function exists
        Exit for loop IF    ${status}==False
        Exponential sleep    ${i}
    END

Check eventing function exists
    [Arguments]    ${bucket}=default    ${host}=http://localhost    ${user}=Administrator    ${password}=asdasd
    ...            ${function_name}=eventing_func
    [Documentation]    Check the eventing function given as function_name has been created.
    ${ports}=    Get service ports    bucket=${bucket}
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}:${ports['eventingAdminPort']}    auth=${auth}
    ${resp}=    Get request    admin_api    /api/v1/functions/${function_name}
    Return from keyword if    ${resp.status_code}==200    True
    Return from keyword    False

Check eventing function deployed
    [Arguments]    ${bucket}=default    ${host}=http://localhost    ${user}=Administrator    ${password}=asdasd
    ...            ${function_name}=eventing_func
    [Documentation]    Check the eventing function given as function_name has been deployed.
    ${ports}=    Get service ports    bucket=${bucket}
    ${auth}=    Create List    ${user}    ${password}
    Create session    admin_api    ${host}:${ports['eventingAdminPort']}    auth=${auth}
    ${resp}=    Get request    admin_api    /api/v1/functions/${function_name}
    Log To Console    ${resp.json()}     DEBUG
    Should be equal as integers    ${resp.status_code}    200
    Return from keyword if    '${resp.json()['appname']}'=='${function_name}'
    ...                        ${resp.json()['settings']['deployment_status']}
    Fail    Eventing function ${function_name} doesn't exist
