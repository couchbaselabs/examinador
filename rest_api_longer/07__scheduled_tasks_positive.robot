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
Resource           ../resources/common.resource
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
${ADHOC_REPO}    scheduled-repository


*** Test Cases ***
Schedule backups every 5 minutes
    [tags]    backup    minutes
    [Documentation]    Creates a repository that schedules backups every 5 minutes it will wait until the task is
    ...    triggered and verify that it run properly.
    [Setup]       Create plan and repo with minute frequency    5-min-backup    every-5
    [Teardown]    archive and delete repo    ${BACKUP_NODE}     every-5
    Sleep               5s     # Give time for the task to get scheduled
    ${req}=    Set Variable    /cluster/self/repository/active/every-5
    ${resp}=    Run and log and check request on session    ${req}    GET    200    session=backup_service
    ...                                                     log_response=True
    Dictionary should contain key      ${resp.json()["scheduled"]}    5-min-backup
    Is approx from now    ${resp.json()["scheduled"]["5-min-backup"]["next_run"]}    5m
    Sleep     6m
    Wait until task is finished    ${BACKUP_NODE}    5-min-backup     every-5    active    running_tasks
    ${history}=    Get task history    every-5
    Confirm task is last and successfull    ${history}   5-min-backup
    ${info}=            Get repository info              every-5
    Length should be    ${info["backups"]}               1
    Should be equal     ${info["backups"][0]["type"]}    FULL


*** Keywords ***
Create plan and repo with minute frequency
    [Arguments]    ${task_name}    ${plan_name}    ${frequency}=5    ${task_type}=BACKUP
    ${req}=    Set Variable    /plan/${plan_name}
    ${pd}=    Set Variable    {"tasks":[{"name":"${task_name}","task_type":"${task_type}","schedule":{"frequency":${frequency},"period":"MINUTES","job_type":"${task_type}"}}]}
    Run and log and check request on session    ${req}    POST    200    payload=${pd}     session=backup_service
    ...                                         log_response=True
    ${req}=    Set Variable    /cluster/self/repository/active/${plan_name}
    ${pd}=    Set Variable    {"plan":"${plan_name}", "archive":"${TEST_DIR}${/}${plan_name}"}
    Run and log and check request on session    ${req}    POST    200    payload=${pd}     session=backup_service
    ...                                         log_response=True
