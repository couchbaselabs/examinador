*** Settings ***
Documentation      This contains test related of triggering tasks.
Force tags         positive    tasks    adhoc
Library            Collections
Library            OperatingSystem
Library            REST        ${BACKUP_HOST}
Library            RequestsLibrary
Library            ../libraries/utils.py
Resource           ../resources/rest.resource
Resource           ../resources/couchbase.resource
Suite setup        Run keywords    Create client and repository dir   trigger_tasks          AND
...                Create repository for triggering adhoc tasks    name=${ADHOC_REPO}    AND
...                Create CB bucket if it does not exist                                   AND
...                Load documents into bucket using cbm
Suite Teardown     Remove Directory    ${TEMP_DIR}${/}trigger_tasks    recursive=True

*** Variables  ***
${BACKUP_NODE}    http://localhost:7101
${BACKUP_HOST}    ${BACKUP_NODE}/api/v1
${CB_NODE}        http://localhost:9001
${USER}           Administrator
${PASSWORD}       asdasd
${TEST_DIR}       ${TEMP_DIR}${/}trigger_tasks
${ADHOC_REPO}    trigger-task-repository

*** Test Cases ***
Try trigger a full backup
    [Tags]    post    backup    full
    [Documentation]    Trigger an adhoc full backup.
    # Trigger a full backup
    ${backup_name}=    Trigger backup    trigger-task-repository    full=true
    # Confirm task is running
    ${task}=    Confirm task is running    ${backup_name}    trigger-task-repository
    # Check that the task finishes and it is add to history
    Wait until task is finished             ${BACKUP_NODE}    ${backup_name}    trigger-task-repository
    ${history}=         Get task history    trigger-task-repository
    Length should be    ${history}          1
    Confirm task is last and successfull   ${history}    ${backup_name}
    # Confirm that the backup was actually done by using info
    ${info}=    Get repository info    trigger-task-repository
    Length should be    ${info["backups"]}               1
    Should be equal     ${info["backups"][0]["type"]}    FULL

Trigger an incremental backup
    [Tags]    post    backup    incr
    [Documentation]    Trigger an incremantal backup.
    ${backup_name}=    Trigger backup    trigger-task-repository    full=false
    ${task}=            Confirm task is running    ${backup_name}    trigger-task-repository
    Wait until task is finished                    ${BACKUP_NODE}    ${backup_name}            trigger-task-repository
    ${history}=         Get task history           trigger-task-repository
    Confirm task is last and successfull           ${history}        ${backup_name}
    # Confirm that the backup was actually done by using info
    ${info}=    Get repository info    trigger-task-repository
    Length should be    ${info["backups"]}               2
    Should be equal     ${info["backups"][1]["type"]}    INCR

Merge everything together
    [Tags]    post    merge
    [Documentation]    Merge all backups
    ${merge}=    Trigger a merge
    ${task}=     Confirm task is running    ${merge}          trigger-task-repository    task_type=MERGE
    Wait until task is finished             ${BACKUP_NODE}    ${merge}                   trigger-task-repository
    ${info}=    Get repository info    trigger-task-repository
    Length should be    ${info["backups"]}               1
    Should be equal     ${info["backups"][0]["type"]}    MERGE - FULL

Delete a backup
    [Tags]    post    remove
    ${info}=    Get repository info    trigger-task-repository
    REST.DELETE      /cluster/self/repository/active/trigger-task-repository/backups/${info["backups"][0]["date"]}    headers=${BASIC_AUTH}
    Integer     response status    200
    Directory should not exist    ${TEST_DIR}${/}trigger_archive${/}${info["backups"][0]["date"]}

*** Keywords ***
Trigger a merge
    ${merge}=           Post request       backup_service    /cluster/self/repository/active/trigger-task-repository/merge    {}
    Status should be    200                ${merge}
    Log                 ${merge.json()}    DEBUG
    Return from keyword    ${merge.json()["task_name"]}

Confirm task is running
    [Arguments]    ${task_name}    ${repository}    ${state}=active    ${task_type}=BACKUP
    ${resp}=            Get request     backup_service    /cluster/self/repository/${state}/${repository}
    Status should be                 200               ${resp}
    Log                              ${resp.json()}    DEBUG
    Dictionary should contain key    ${resp.json()["running_one_off"]}    ${task_name}
    ${task}=                         Get from dictionary                  ${resp.json()["running_one_off"]}    ${task_name}
    Should be equal                  ${task["type"]}                      ${task_type}
    Return from keyword              ${task}
