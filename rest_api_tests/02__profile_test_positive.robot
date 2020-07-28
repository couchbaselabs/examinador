*** Settings ***
Documentation    Test that are all allowed profile realted actions via the REST API work as intended.
Force Tags       positive    profile
Library          Collections
Library          REST    ${BACKUP_HOST}
Library          RequestsLibrary
Library         ../libraries/rest_utils.py
Library         ../libraries/utils.py
Resource        ../resources/rest.resource
Suite setup     Create REST session and auth

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1


*** Test Cases ***
Add an empty profile
    [Tags]   post
    [Documentation]    Attempt to add a profile with name 'empty' that has no tasks or description.
    POST        /profile/empty      {}    headers=${BASIC_AUTH}
    Integer     response status     200
    GET         /profile/empty      headers=${BASIC_AUTH}
    Object      response body       required=["name"]    properties={"name":{"type":"string","const":"empty"},"description":{"type":"null"},"tasks":{"type":"null"}}

Try add profile with short name
    [Tags]    post
    Add profile and confirm addition    aa     ""    []    []

Try add profile with alphanumeric name
    [Tags]    post
    Add profile and confirm addition    alpha-numeric_1     ""    []    []

Try add profile with long name and description
    [Tags]    post
    ${name}=           Generate random string    50
    ${description}=    Generate random string    120
    Add profile and confirm addition    ${name}     "${description}"    []    []

Try add profile that only affects data service
    [Tags]    post
    Add profile and confirm addition    only-data     ""    ["data"]    []

Try add profile that with one task
    [Tags]    post
    Add profile and confirm addition    one-tasks     ""    []    [{"name":"task-1","task_type":"BACKUP","full_backup":true,"schedule":{"job_type":"BACKUP","frequency":3,"period":"MINUTES"}}]

Try add task with different periods
    [Tags]    post
    [Template]    Add task with period "${period}"
    MINUTES
    HOURS
    DAYS
    WEEKS
    MONDAY
    TUESDAY
    WEDNESDAY
    THURSDAY
    FRIDAY
    SATURDAY
    SUNDAY

Try and delete profile
    [Tags]     delete
    DELETE     /profile/only-data    headers=${BASIC_AUTH}
    Integer    response status       200
    GET        /profile/only-data
    Integer    response status       500

*** Keywords ***
Add profile and confirm addition
    [Arguments]        ${name}    ${description}=None    ${services}=None    ${tasks}=None
    [Documentation]    Adds a new profile.
    POST               /profile/${name}    {"description":${description},"services":${services},"tasks":${tasks}}
    ...                headers=${BASIC_AUTH}
    Integer            response status     200
    ${resp}=           Get request         backup_service    /profile/${name}
    Status should be   200                 ${resp}
    Dictionary like equals    ${resp.json()}    {"name":"${name}","description":${description},"services":${services},"tasks":${tasks}}    ['description']

Add task with period "${period}"
    Add profile and confirm addition    profile-${period}    ""    []    [{"name":"task-1","task_type":"BACKUP","full_backup":true,"schedule":{"job_type":"BACKUP","frequency":3,"period":"${period}"}}]
