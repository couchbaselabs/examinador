*** Settings ***
Library            RequestsLibrary
Library            Process
Library            OperatingSystem
Library            ../libraries/cbm_utils.py     ${BIN_PATH}    ${TEMP_DIR}${/}data${/}backups
Resource           ../resources/couchbase.resource
Resource           ../resources/common.resource

*** Variables ***
${BIN_PATH}        ${SOURCE}${/}install${/}bin
${WORKSPACE}       %{PWD}

*** Keywords ***
Get info as user
    [Arguments]        ${repo}    ${arch}=${TEMP_DIR}${/}data${/}backups    ${depth}=2
    ${command}=         Create List     ${BIN_PATH}${/}cbbackupmgr    info    --archive     ${arch}     -r    ${repo}
    ...                 --depth    ${depth}
    ${result}=    Run and log and check process    ${command}    log_stdout=False
    Return from keyword    ${result.stdout}

Collect backup logs and remove archive
    [Arguments]        ${arch}=${TEMP_DIR}${/}data${/}backups    ${host}=http://localhost:9000    ${user}=Administrator
    ...                ${password}=asdasd
    ${command}=         Create List     ${BIN_PATH}${/}cbbackupmgr    collect-logs    --archive     ${arch}
    ...                 -o    ${WORKSPACE}${/}reports    --skip-sys-info
    Run and log and check process    ${command}
    Remove Directory    ${arch}    recursive=True

Collect server logs
    [Arguments]        ${host}=http://localhost:9000    ${user}=Administrator    ${password}=asdasd
    ${command}=         Create List     ${BIN_PATH}${/}couchbase-cli    collect-logs-start      -c    ${host}
    ...                 -u    ${user}    -p    ${password}    --output-directory    ${WORKSPACE}${/}reports
    ...                 --all-nodes
    Run and log and check process    ${command}
    FOR    ${i}   IN RANGE    300
        Sleep    2s
        ${command}=         Create List     ${BIN_PATH}${/}couchbase-cli    collect-logs-status      -c    ${host}
        ...                 -u    ${user}    -p    ${password}
        ${result}=    Run Process    @{command}
        Should Be Empty    ${result.stderr}
        Should be equal as integers    ${result.rc}    0
        ${exit}=    Evaluate    "completed" in """${result.stdout}"""
        Exit for loop IF    ${exit}
    END
    Log To Console    ${result.stdout}     DEBUG

Get cbriftdump data
    [Arguments]        ${dir}
    [Documentation]    Get the rift stores from the path specified by dir.
    ${command}=    Create List    ${BIN_PATH}${/}cbriftdump    -d    ${dir}    --json
    ${result}=     Run and log and check process    ${command}    log_stdout=False    stdout=${TEMPDIR}${/}stdout.txt
    ...            stderr=DEVNULL
    ${result_list}=    Rift To List    ${result.stdout}
    Return from keyword    ${result_list}

Merge multiple backups
    [Arguments]         ${repo}    ${start}    ${end}    ${arch}=${TEMP_DIR}/data/backups
    ${command}=         Create List     ${BIN_PATH}${/}cbbackupmgr     merge    --archive    ${arch}    -r    ${repo}
    ...                 --start    ${start}    --end    ${end}    --no-progress-bar
    Run and log and check process    ${command}

Run restore and wait until persisted
    [Arguments]         ${repo}    ${archive}=None    ${bucket}=default   ${host}=http://localhost:9000
    ...                 ${user}=Administrator    ${password}=asdasd    ${timeout_value}=240    ${items}=2048
    ...                 ${users}=False
    ...                 &{kwargs}
    [Documentation]     This function will run restore and wait for docs to be persisted to disk.
    ${previous_items}=    Get item count    bucket=${bucket}
    Restore docs    repo=${repo}    host=${host}    user=${user}    password=${password}
    ...             timeout_value=${timeout_value}    users=${users}    &{kwargs}
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}
