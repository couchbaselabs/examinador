*** Settings ***
Documentation    This contains test related to scheduled tasks
Force tags       positive    tasks    scheduled
Library            Collections
Library            OperatingSystem
Library            REST        ${BACKUP_HOST}
Library            RequestsLibrary
Library            ../libraries/utils.py
Resource           ../resources/rest.resource
Resource           ../resources/couchbase.resource
Suite setup        Run keywords    Create client and repository dir   scheduled              AND
...                Create CB bucket if it does not exist                                     AND
...                Load documents into bucket using cbm
Suite Teardown     Remove Directory    ${TEMP_DIR}${/}scheduled recursive=True

*** Variables ***
${BACKUP_NODE}    http://localhost:7101
${BACKUP_HOST}    ${BACKUP_NODE}/api/v1
${CB_NODE}        http://localhost:9001
${USER}           Administrator
${PASSWORD}       asdasd
${TEST_DIR}       ${TEMP_DIR}${/}scheduled
${ADHOC_INSTANCE}    scheduled-repository


*** Test Cases ***
Schedule backups every 5 minutes
    [tags]    backup    minutes
    [Documentation]    Creates a repository that schedules backups every 5 minutes it will wait until the task is
    ...    triggered and verify that it run properly.
    [Setup]       Create plan and repo with minute frequency    5-min-backup    every-5
    [Teardown]    archive and delete repo    ${BACKUP_NODE}     every-5
    Sleep               5s     # Give time for the task to get scheduled
    ${resp}=            Get request    backup_service    /cluster/self/repository/active/every-5
    Status should be    200               ${resp}
    Log                 ${resp.json()}    DEBUG
    Dictionary should contain key      ${resp.json()["scheduled"]}    5-min-backup
    Is approx from now    ${resp.json()["scheduled"]["5-min-backup"]["next_run"]}    5m
    Sleep     5m
    Wait until task is finished    ${BACKUP_NODE}    5-min-backup     every-5    state


*** Keywords ***
Create plan and repo with minute frequency
    [Arguments]    ${task_name}    ${plan_name}    ${frequency}=5    ${task_type}=BACKUP
    ${resp}=    POST request    backup_service    /plan/${plan_name}    {"tasks":[{"name":"${task_name}","task_type":"${task_type}","schedule":{"frequency":${frequency},"period":"MINUTES","job_type":"${task_type}"}}]}
    Status should be    200     ${resp}
    ${resp}=    POST request    backup_service    /cluster/self/repository/active/${plan_name}    {"plan":"${plan_name}", "archive":"${TEST_DIR}${/}${plan_name}"}
    Status should be    200     ${resp}
