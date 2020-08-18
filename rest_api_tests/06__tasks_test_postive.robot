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
...                Create repository for triggering adhoc tasks    name=${ADHOC_INSTANCE}    AND
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
${ADHOC_INSTANCE}    trigger-task-repository

*** Test Cases ***
Try trigger a full backup
    [Tags]    post    backup    full
    [Documentation]    Trigger an adhoc full backup.
    # Trigger a full backup
    ${backup_name}=    Trigger backup    full=true
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
    ${backup_name}=     Trigger backup             full=false
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
    Delete      /cluster/self/repository/active/trigger-task-repository/backups/${info["backups"][0]["date"]}    headers=${BASIC_AUTH}
    Integer     response status    200
    Directory should not exist    ${TEST_DIR}${/}trigger_archive${/}${info["backups"][0]["date"]}

*** Keywords ***
Create repository for triggering adhoc tasks
    [Documentation]    This will create an empty plan and used it as a base for an repository with name "${name}" and
    ...    archive "${archive}".
    [Arguments]    ${plan}=trigger-task-plan    ${name}=trigger-task-repository    ${archive}=trigger_archive
    Create directory    ${TEST_DIR}${/}${archive}
    POST                /plan/${plan}    {}    headers=${BASIC_AUTH}
    Integer             response status        200
    POST                /cluster/self/repository/active/${name}    {"archive":"${TEST_DIR}${/}${archive}", "plan":"${plan}"}    headers=${BASIC_AUTH}
    Integer             response status        200

Trigger backup
    [Arguments]         ${full}=false
    ${trigger}=         Post request    backup_service    /cluster/self/repository/active/trigger-task-repository/backup    {"full_backup":${full}}
    Status should be    200                  ${trigger}
    Log                 ${trigger.json()}    DEBUG
    Return from keyword    ${trigger.json()["task_name"]}

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
