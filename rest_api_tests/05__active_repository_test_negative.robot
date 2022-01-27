*** Settings ***
Documentation
...     Backup service repository REST API negative tests. The HOST is set in the init file but can be
...     overriden via the command line to point to any arbitraty node that runs the backup service.
Force Tags      repository    positive
Library         OperatingSystem
Library         Collections
Library         REST        ${BACKUP_HOST}
Library         ../libraries/utils.py
Resource        ../resources/rest.resource
Resource        ../resources/common.resource
Suite setup        Create client and repository dir    negative_repository_dir
Suite Teardown     Remove Directory    ${TEMP_DIR}${/}negative_repository_dir    recursive=True

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1
${CB_NODE}        http://localhost:9001
${TEST_DIR}       ${TEMP_DIR}${/}negative_repository_dir

*** Test Cases ***
Add invalid respositories
    [Tags]    post
    [Documentation]    Do a set of plan add requests that should be rejected by the server.
    [Template]         Add invalid repository
    *invalid*name             empty    ${TEST_DIR}
    no-plan                \        ${TEST_DIR}
    no-archive                empty
    bucket-does-not-exist     empty    ${TEST_DIR}    fake-bucket

Try and delete active repository
    [Tags]    delete
    [Documentation]    Deleting an active repository is not allowed.
    Run and log and check request    /cluster/self/repository/active/negative_repository    POST    200
    ...                              {"archive":"${TEST_DIR}", "plan":"one-task"}    headers=${BASIC_AUTH}
    Run and log and check request    /cluster/self/repository/active/negative_repository    DELETE    400
    ...                              headers=${BASIC_AUTH}
    Run and log and check request    /cluster/self/repository/active/negative_repository    GET    200
    ...                              headers=${BASIC_AUTH}

Try and add active instace with same name
    [Tags]    post
    [Documentation]    Try and add an repository with the same name as a previous one. This test relies on the test "try
    ...                and delete active repository" to succeed adding the repository "negative repository"
    Add invalid repository    negative_repository    empty    ${TEST_DIR}

*** Keywords ***
Add invalid repository
    [Arguments]    ${name}    ${plan}=\   ${archive}=\    ${bucket}=\    ${expected}=400
    [Documentation]    Tries and create an repository with the given arguments
    Run and log and check request    /cluster/self/repository/active/${name}    POST    ${expected}
    ...                              {"archive":"${archive}","plan":"${plan}","bucket_name":"${bucket}"}
    ...                              headers=${BASIC_AUTH}
