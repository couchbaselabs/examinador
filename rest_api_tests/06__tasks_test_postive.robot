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
Try trigger a full backup
    [Tags]    post
    [Documentation]    Trigger an adhoc full backup.
    # Trigger a full backup
    ${backup_name}=    Trigger backup    full=true
    # Confirm task is running
    ${task}=    Confirm task is running    ${backup_name}    trigger-task-instance
    # Check that the task finishes and it is add to history
    Wait until one off task is finished    ${BACKUP_NODE}    ${backup_name}    trigger-task-instance
    ${history}=         Get task history    trigger-task-instance
    Length should be    ${history}          1
    Confirm task is last and successfull   ${history}    ${backup_name}
    # Confirm that the backup was actually done by using info
    ${resp}=    Get request    backup_service    /cluster/self/instance/active/trigger-task-instance/info
    Status should be    200                                     ${resp}
    Log                 ${resp.json()}                          DEBUG
    Length should be    ${resp.json()["backups"]}               1
    Should be equal     ${resp.json()["backups"][0]["type"]}    FULL

Trigger an incremental backup
    [Tags]    post
    [Documentation]    Trigger an incremantal backup.
    ${backup_name}=     Trigger backup             full=false
    ${task}=            Confirm task is running    ${backup_name}    trigger-task-instance
    Wait until one off task is finished            ${BACKUP_NODE}    ${backup_name}            trigger-task-instance
    ${history}=         Get task history           trigger-task-instance
    Confirm task is last and successfull           ${history}        ${backup_name}
    # Confirm that the backup was actually done by using info
    ${resp}=    Get request    backup_service    /cluster/self/instance/active/trigger-task-instance/info
    Status should be    200                                     ${resp}
    Log                 ${resp.json()}                          DEBUG
    Length should be    ${resp.json()["backups"]}               2
    Should be equal     ${resp.json()["backups"][1]["type"]}    INCR


*** Keywords ***
Create instance for triggering adhoc tasks
    [Documentation]    This will create an empty profile and used it as a base for an instance with name "${name}" and
    ...    archive "${archive}".
    [Arguments]    ${profile}=trigger-task-profile    ${name}=trigger-task-instance    ${archive}=trigger_archive
    Create directory    ${TEST_DIR}${/}${archive}
    POST                /profile/${profile}    {}    headers=${BASIC_AUTH}
    Integer             response status        200
    POST                /cluster/self/instance/active/${name}    {"archive":"${TEST_DIR}${/}${archive}", "profile":"${profile}"}    headers=${BASIC_AUTH}
    Integer             response status        200

Trigger backup
    [Arguments]         ${full}=false
    ${trigger}=         Post request    backup_service    /cluster/self/instance/active/trigger-task-instance/backup    {"full_backup":${full}}
    Status should be    200                  ${trigger}
    Log                 ${trigger.json()}    DEBUG
    Return from keyword    ${trigger.json()["task_name"]}

Confirm task is running
    [Arguments]    ${task_name}    ${instance}    ${state}=active    ${task_type}=BACKUP
    ${resp}=            Get request     backup_service    /cluster/self/instance/${state}/${instance}
    Status should be                 200               ${resp}
    Log                              ${resp.json()}    DEBUG
    Dictionary should contain key    ${resp.json()["running_one_off"]}    ${task_name}
    ${task}=                         Get from dictionary                  ${resp.json()["running_one_off"]}    ${task_name}
    Should be equal                  ${task["type"]}                      ${task_type}
    Return from keyword              ${task}

Get task history
    [Arguments]   ${instance}    ${state}=active
    [Documentation]    Gets the task history for the requested instance.
    ${resp}=            Get request      backup_service   /cluster/self/instance/${state}/${instance}/taskHistory
    Status should be    200              ${resp}
    Return from keyword                  ${resp.json()}

Confirm task is last and successfull
    [Arguments]        ${history}                    ${backup_name}
    Should be equal    ${history[0]["task_name"]}    ${backup_name}
    Should be equal    ${history[0]["status"]}       done
