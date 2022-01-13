*** Settings ***
Library            RequestsLibrary
Library            Process
Library            OperatingSystem

*** Keywords ***
Run and log and check process
    [Arguments]    ${command}    ${log_stdout}=True    ${check_stderr}=True    ${check_exit_code}=True
    ...            ${expected_exit_code}=0    ${shell}=False    ${stdout}=STDOUT    ${stderr}=STDERR
    [Documentation]    Run and log the start and the results of the process on the DEBUG level, also check results.
    ${result}=    Run and log process    ${command}    log_stdout=${log_stdout}    shell=${shell}    stdout=${stdout}
    ...           stderr=${stderr}
    Run Keyword If    ${check_stderr}    Should Be Empty    ${result.stderr}
    Run Keyword If    ${check_exit_code}    Should be equal as integers    ${result.rc}    ${expected_exit_code}
    Return from keyword    ${result}

Run and log process
    [Arguments]    ${command}    ${log_stdout}=True    ${shell}=False    ${stdout}=STDOUT    ${stderr}=STDERR
    [Documentation]    Run and log the start and the results of the process on the DEBUG level.
    ${command_str}=    Catenate    @{command}
    Log To Console     Running ${command_str} ...    DEBUG
    ${result}=    Run process    @{command}    shell=${shell}    stdout=${stdout}    stderr=${stderr}
    Run Keyword If    ${log_stdout}    Log To Console    ${result.stdout}    DEBUG
    Return from keyword    ${result}
