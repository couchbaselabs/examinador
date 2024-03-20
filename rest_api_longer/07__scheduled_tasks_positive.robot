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
Schedule backups and merges every minute
    [tags]    backup    minutes
    [Documentation]    Creates a repository that schedules backups and merges every minute, waits 4 minutes, and then
    ...    checks to see if a merged backup exists in the repo.   
    [Teardown]    archive and delete repo    ${BACKUP_NODE}     every-min-backup-merge
    Create plan   every-min-backup-merge    {"tasks":[{"name":"backup_min","task_type":"BACKUP","schedule":{"frequency":1,"period":"MINUTES","job_type":"BACKUP"}},{"name":"merge_min","task_type":"MERGE","schedule":{"frequency":1,"period":"MINUTES","job_type":"MERGE"},"merge_options":{"offset_start":0,"offset_end":1}}]}
    Create Backup Service repo that uses plan    every-min-backup-merge
    Sleep     4m
    ${info}=            Get repository info              every-min-backup-merge
    Should be equal     ${info["backups"][0]["type"]}    MERGE - FULL                                   log_response=True