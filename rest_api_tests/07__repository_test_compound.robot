*** Settings ***
Documentation
...    Do tests on repository that encompas multiple actions
Force Tags      repository
Library         OperatingSystem
Library         Collections
Library         REST        ${BACKUP_HOST}
Library         ../libraries/utils.py
Resource        ../resources/rest.resource
Resource        ../resources/couchbase.resource
Suite setup        Run keywords    Create client and repository dir   compound                                    AND
...                Create repository for triggering adhoc tasks    plan=compound    name=${ADHOC_REPO}     archive=compound    AND
...                Create CB bucket if it does not exist                                                          AND
...                Load documents into bucket using cbm    AND
...                Run ten backups
Suite Teardown     Remove Directory    ${TEMP_DIR}${/}compound    recursive=True


*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1
${BACKUP_NODE}    http://localhost:7101
${CB_NODE}        http://localhost:9001
${USER}           Administrator
${PASSWORD}       asdasd
${ADHOC_REPO}     compound-repository
${TEST_DIR}       ${TEMP_DIR}${/}compound


*** Test Cases ***
Test info pagination
    [Tags]    positive
    [Documentation]
    ...           The test will make 10 backups and then try to do both info and get task history with the pagination
    ...           options and confirm that they work.
    [Setup]       Set info
    [Template]    Get info paginated and compare
    ${INFO["backups"]}         0      0    # No pagination
    ${INFO["backups"][:1]}     1      0    # Limit to 1
    ${INFO["backups"][1:2]}    1      1    # Limit to 1 and offset by 1
    ${INFO["backups"][:5]}     5      0    # Limit to 5
    ${INFO["backups"]}         100    0    # Large limit
    ${INFO["backups"][0:0]}    0      100  # Offset to large

*** Keywords ***
Run ten backups
    FOR    ${index}    IN RANGE    10
        ${backup_name}=    Trigger backup    ${ADHOC_REPO}
        Wait until task is finished    ${BACKUP_NODE}    ${backup_name}    ${ADHOC_REPO}
    END

Get info paginated and compare
    [Documentation]    Gets the info of the test repository and checks that the returned backups are of length
    [Arguments]    ${expected}    ${limit}=0    ${offset}=0
    ${info}=              Get repository info      repository=${ADHOC_REPO}    limit=${limit}    offset=${offset}
    Backup dates match    ${expected}              ${info["backups"]}

Set info
    ${INFO}=     Get repository info      repository=${ADHOC_REPO}
    Set suite variable    ${INFO}
