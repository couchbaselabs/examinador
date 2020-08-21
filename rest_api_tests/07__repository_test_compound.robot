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
    [Documentation]    Do info with different paginations and confirm the results are as expected.
    [Setup]       Set info
    [Template]    Get info paginated and compare
    ${INFO["backups"]}         0      0    # No pagination
    ${INFO["backups"][:1]}     1      0    # Limit to 1
    ${INFO["backups"][1:2]}    1      1    # Limit to 1 and offset by 1
    ${INFO["backups"][:5]}     5      0    # Limit to 5
    ${INFO["backups"]}         100    0    # Large limit
    ${INFO["backups"][0:0]}    0      100  # Offset to large

Test history pagination
    [Tags]    positive
    [Documentation]    Get the history with different pagination options and confirm it works.
    [Setup]    Set history
    [Template]    Get task history and compare
    ${HISTORY}         0      0    # No pagination
    ${HISTORY[:1]}     1      0    # Limit to 1
    ${HISTORY[1:2]}    1      1    # Limit to 1 and offset by 1
    ${HISTORY[:5]}     5      0    # Limit to 5
    ${HISTORY}         100    0    # Large limit
    ${HISTORY[0:0]}    0      100  # Offset to large

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
    List should be same by key    ${expected}      ${info["backups"]}           date

Set info
    ${INFO}=     Get repository info      repository=${ADHOC_REPO}
    Set suite variable    ${INFO}

Set history
    ${HISTORY}=    Get task history    ${ADHOC_REPO}
    Set suite variable    ${HISTORY}

Get task history and compare
    [Documentation]    Gets the task history with the given pagination parameters and compare it to the expected
    ...                results.
    [Arguments]    ${expected}    ${limit}=0    ${offset}=0
    ${history}=    Get task history    ${ADHOC_REPO}    limit=${limit}    offset=${offset}
    List should be same by key         ${expected}      ${history}        task_name
