*** Settings ***
Library            RequestsLibrary
Library            Process
Library            OperatingSystem

*** Comments ***
    Log to Console    session: ${session}    DEBUG
    Log to Console    req: ${request}    DEBUG
    Log to Console    params: ${params}    DEBUG


*** Keywords ***
Run and log and check process
    [Arguments]    ${command}    ${log_stdout}=True    ${check_stderr}=True    ${check_exit_code}=True
    ...            ${expected_exit_code}=0    ${shell}=False    ${stdout}=STDOUT    ${stderr}=STDERR
    [Documentation]    Run and log the start and the results of the process at the DEBUG level, also check results.
    ${result}=    Run and log process    ${command}    log_stdout=${log_stdout}    shell=${shell}    stdout=${stdout}
    ...           stderr=${stderr}
    Run Keyword If    ${check_stderr}    Should Be Empty    ${result.stderr}
    Run Keyword If    ${check_exit_code}    Should be equal as integers    ${result.rc}    ${expected_exit_code}
    Return from keyword    ${result}

Run and log process
    [Arguments]    ${command}    ${log_stdout}=True    ${shell}=False    ${stdout}=STDOUT    ${stderr}=STDERR
    [Documentation]    Run and log the start and the results of the process at the DEBUG level.
    ${command_str}=    Catenate    @{command}
    Log To Console     Running ${command_str} ...    DEBUG
    ${result}=    Run process    @{command}    shell=${shell}    stdout=${stdout}    stderr=${stderr}
    Run Keyword If    ${log_stdout}    Log To Console    ${result.stdout}    DEBUG
    Return from keyword    ${result}

Run and log and check request
    [Arguments]    ${request}    ${method}    ${expected_status}    ${payload}=${NONE}    ${headers}=${NONE}
    ...            ${log_response}=True
    [Documentation]    Send and log a REST request at the DEBUG level, also check response status.
    Run and log request    ${request}    ${method}    ${payload}    ${headers}    ${log_response}
    Integer    response status    ${expected_status}

Run and log request
    [Arguments]    ${request}    ${method}    ${payload}=${NONE}    ${headers}=${NONE}
    ...            ${log_response}=True
    [Documentation]    Send and log a REST request at the DEBUG level.
    IF    '${payload}' != '${NONE}'
    Log To Console    Sending HTTP ${method} request to ${request} with payload ${payload} ...    DEBUG
    ELSE
    Log To Console    Sending HTTP ${method} request to ${request} ...    DEBUG
    END
    Run Keyword    REST.${method}    ${request}    ${payload}    headers=${headers}

Run and log and check request on session
    [Arguments]    ${request}    ${method}    ${expected_status}    ${payload}=${NONE}    ${host}=http://localhost:9000
    ...            ${user}=Administrator    ${password}=asdasd    ${session}=${NONE}    ${params}=${NONE}
    ...            ${log_response}=True
    [Documentation]    Send and log a REST request at the DEBUG level, also check response status.
    ${resp}=    Run and log request on session    ${request}    ${method}    ${payload}    ${host}    ${user}
    ...         ${password}    ${session}    ${params}    ${log_response}
    Status should be    ${expected_status}    ${resp}
    Return from keyword    ${resp}

Run and log request on session
    [Arguments]    ${request}    ${method}    ${payload}=${NONE}    ${host}=http://localhost:9000
    ...            ${user}=Administrator    ${password}=asdasd    ${session}=${NONE}    ${params}=${NONE}
    ...            ${log_response}=True
    [Documentation]    Send and log a REST request at the DEBUG level.
    ${method_kw}=    Catenate    ${method}    On Session
    IF    '${payload}' != '${NONE}'
    Log To Console    Sending HTTP ${method} request to ${host}${request} with payload ${payload} ...    DEBUG
    ELSE
    Log To Console    Sending HTTP ${method} request to ${host}${request} ...    DEBUG
    END
    ${auth}=    Create List    ${user}    ${password}
    IF    '${session}' == '${NONE}'
    ${session}=    Set Variable    internal_session_name
    ${auth}=    Create List    ${user}    ${password}
    Create session    ${session}    ${host}    auth=${auth}
    END
    ${resp}=    Run Keyword    ${method_kw}    alias=${session}    url=${request}    params=${params}    data=${payload}
    ...         expected_status=any
    IF    ${log_response}
    Log To Console    Received response: ${resp.text}    DEBUG
    ELSE
    Log To Console    Response received but not logged    DEBUG
    END
    Return from keyword    ${resp}
