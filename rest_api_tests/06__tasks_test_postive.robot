*** Settings ***
Documentation      This contains test related of triggering tasks.
Force tags         positive    tags
Library            Collections
Library            OperatingSystem
Library            REST        ${BACKUP_HOST}
Library            RequestsLibrary
Library            ../libraries/utils.py
Resource           ../resources/rest.resource
Resource           ../resources/couchbase.resource
Suite setup        Run keywords    Create client and instance dir   trigger_tasks          AND
...                Create instance for triggering adhoc tasks    name=${ADHOC_INSTANCE}    AND
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
${ADHOC_INSTANCE}    trigger-task-instance

*** Test Cases ***
Try trigger a backup
    [Tags]    post
    [Documentation]    Trigger an adhoc full backup.
    # Trigger a full backup
    ${trigger}=         Post request    backup_service    /cluster/self/instance/active/trigger-task-instance/backup    {"full_backup":true}
    Status should be    200                  ${trigger}
    Log                 ${trigger.json()}    DEBUG
    # Confirm task is running
    ${resp}=            Get request     backup_service    /cluster/self/instance/active/trigger-task-instance
    Status should be                 200               ${resp}
    Log                              ${resp.json()}    DEBUG
    Length should be                 ${resp.json()["running_one_off"]}    1
    Dictionary should contain key    ${resp.json()["running_one_off"]}    ${trigger.json()["task_name"]}
    ${task}=                         Get from dictionary                  ${resp.json()["running_one_off"]}    ${trigger.json()["task_name"]}
    Should be equal                  ${task["type"]}                      BACKUP
    # Check that the task finishes and it is add to history
    Wait until one off task is finished    ${BACKUP_NODE}    ${task["task_name"]}    trigger-task-instance
    Get    /cluster/self/instance//active/trigger-task-instance/taskHistory    headers=${BASIC_AUTH}
    Integer    response status    200
    Array      response body      minItems=1    maxItems=1
    String     $.[0].task_name         ${task["task_name"]}
    String     $.[0].status       done
    # Confirm that the backup was actually done by using info
    ${resp}=    Get request    backup_service    /cluster/self/instance/active/trigger-task-instance
    Status should be    200    ${resp}
    Length shoud be     ${resp.json()["backups"]}    1
    Should be equal     ${resp.json()["backups"][0]["type"]}    FULL

*** Keywords ***
Create instance for triggering adhoc tasks
    [Documentation]    This will create an empty profile and used it as a base for an instance with name "${name}" and
    ...    archive "${archive}".
    [Arguments]    ${profile}=trigger-task-profile    ${name}=trigger-task-instance    ${archive}=trigger_archive
    Create directory    ${TEST_DIR}${/}${archive}
    POST                /profile/${profile}    {}    headers=${BASIC_AUTH}
    Integer             response status        200
    POST                /cluster/self/instance/active/${name}    {"archive":"${archive}", "profile":"${profile}"}    headers=${BASIC_AUTH}
    Integer             response status        200
