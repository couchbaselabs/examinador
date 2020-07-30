*** Settings ***
Documentation
...     Backup service instance REST API negative tests. The HOST is set in the init file but can be
...     overriden via the command line to point to any arbitraty node that runs the backup service.
Force Tags      instance    positive
Library         OperatingSystem
Library         Collections
Library         REST        ${BACKUP_HOST}
Library         ../libraries/utils.py
Resource        ../resources/rest.resource
Suite setup        Create client and instance dir    negative_instance_dir
Suite Teardown     Remove Directory    ${TEMP_DIR}${/}negative_instance_dir    recursive=True

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1
${CB_NODE}        http://localhost:9001
${TEST_DIR}       ${TEMP_DIR}${/}negative_instance_dir

*** Test Cases ***
Add invalid instances
    [Tags]    post
    [Documentation]    Do a set of profile add requests that should be rejected by the server.
    [Template]         Add invalid instance
    *invalid*name             empty    ${TEST_DIR}
    no-profile                \        ${TEST_DIR}
    no-archive                empty
    bucket-does-not-exist     empty    ${TEST_DIR}    fake-bucket

Try and delete active instance
    [Tags]    delete
    [Documentation]    Deleting an active instance is not allowed.
    POST      /cluster/self/instance/active/negative_instance    {"archive":"${TEST_DIR}", "profile":"empty"}    headers=${BASIC_AUTH}
    Integer   response status    200
    DELETE    /cluster/self/instance/active/negative_instance    headers=${BASIC_AUTH}
    Integer   response status    400
    GET       /cluster/self/instance/active/negative_instance    headers=${BASIC_AUTH}
    Integer   response status    200

Try and add active instace with same name
    [Tags]    post
    [Documentation]    Try and add an instance with the same name as a previous one. This test relies on the test "try
    ...                and delete active instance" to succeed adding the instance "negative instance"
    Add invalid instance    negative_instance    empty    ${TEST_DIR}

*** Keywords ***
Add invalid instance
    [Arguments]    ${name}    ${profile}=\   ${archive}=\    ${bucket}=\    ${expected}=400
    [Documentation]    Tries and create an instance with the given arguments
    POST    /cluster/self/instance/active/${name}    {"archive":"${archive}","profile":"${profile}","bucket_name":"${bucket}"}    headers=${BASIC_AUTH}
    Integer    response status    ${expected}
