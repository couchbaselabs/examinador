*** Settings ***
Library            RequestsLibrary
Library            Process
Library            OperatingSystem
Library            ../libraries/cbm_utils.py     ${BIN_PATH}    ${TEMP_DIR}${/}data${/}backups

*** Variables ***
${BIN_PATH}        %{HOME}${/}source${/}install${/}bin
${WORKSPACE}       Get Environment Variable    PWD

*** Keywords ***
Get info as json
    [Arguments]        ${repo}    ${arch}=${TEMP_DIR}${/}data${/}backups    ${type}=0x03
    ${result}=         Run Process     ${BIN_PATH}${/}cbbackupmgr    info    --archive     ${arch}     -r    ${repo}
    ...                                --json
    Should Be Equal As Integers    ${result.rc}    0
    ${result_dict}=    Evaluate    json.loads('''${result.stdout}''')    json
    Return from keyword    ${result_dict}

Get info as user
    [Arguments]        ${repo}    ${arch}=${TEMP_DIR}${/}data${/}backups    ${type}=0x03    ${depth}=2
    ${result}=         Run Process     ${BIN_PATH}${/}cbbackupmgr    info    --archive     ${arch}     -r    ${repo}
    ...                                --depth    ${depth}
    Should Be Equal As Integers    ${result.rc}    0
    Return from keyword    ${result.stdout}

Collect logs and remove archive
    [Arguments]        ${arch}=${TEMP_DIR}${/}data${/}backups
    ${result}=         Run Process     ${BIN_PATH}${/}cbbackupmgr    collect-logs    --archive     ${arch}     -o    ${WORKSPACE}${/}reports
    Should Be Equal As Integers    ${result.rc}    0
    Remove Directory    ${arch}    recursive=True

Get cbriftdump data
    [Arguments]        ${dir}
    [Documentation]    Get the rift stores from the path specified by dir.
    ${result}=         Run Process    ${BIN_PATH}${/}cbriftdump    -d    ${dir}    --json
    ...                               stdout=${TEMPDIR}${/}stdout.txt     stderr=DEVNULL
    ${result_list}=    Rift To List    ${result.stdout}
    Return from keyword    ${result_list}

Get doc info
    [Arguments]         ${bucket}=default   ${host}=http://localhost:9000    ${user}=Administrator
    ...                 ${password}=asdasd
    [Documentation]     This function will get the contents of the bucket.
    ${trigger}=         Run Process     ${BIN_PATH}${/}cbtransfer     ${host}    stdout:
    ...                 -u    ${USER}    -p    ${PASSWORD}    -b    ${bucket}    stdout=${TEMPDIR}${/}stdout.txt
    ...                 stderr=DEVNULL
    Should Be Equal As Integers    ${trigger.rc}    0
    ${result_list}=    cbtransfer To List    ${trigger.stdout}
    Return from keyword    ${result_list}

Merge multiple backups
    [Arguments]         ${repo}    ${start}    ${end}    ${arch}=${TEMP_DIR}/data/backups
    ${trigger}=         Run Process     ${BIN_PATH}${/}cbbackupmgr     merge    --archive    ${arch}    -r    ${repo}
    ...                 --start    ${start}    --end    ${end}
    Should Be Equal As Integers    ${trigger.rc}    0
