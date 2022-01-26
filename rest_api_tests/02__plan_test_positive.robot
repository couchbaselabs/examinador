*** Settings ***
Documentation    Test that are all allowed plan realted actions via the REST API work as intended.
Force Tags       positive    plan
Library          Collections
Library          REST    ${BACKUP_HOST}
Library          RequestsLibrary
Library         ../libraries/rest_utils.py
Library         ../libraries/utils.py
Resource        ../resources/rest.resource
Resource        ../resources/common.resource
Suite setup     Create REST session and auth

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1


*** Test Cases ***
Add an empty plan
    [Tags]   post
    [Documentation]    Attempt to add a plan with name 'empty' that has no tasks or description.
    Run and log and check request    /plan/empty    POST    200    {}    headers=${BASIC_AUTH}
    Run and log and check request    /plan/empty    GET    200    headers=${BASIC_AUTH}
    Object      response body       required=["name"]    properties={"name":{"type":"string","const":"empty"},"description":{"type":"null"},"tasks":{"type":"null"}}

Try add plan with short name
    [Tags]    post
    Add plan and confirm addition    aa     ""    []    []

Try add plan with alphanumeric name
    [Tags]    post
    Add plan and confirm addition    alpha-numeric_1     ""    []    []

Try add plan with long name and description
    [Tags]    post
    ${name}=           Generate random string    50
    ${description}=    Generate random string    120
    Add plan and confirm addition    ${name}     "${description}"    []    []

Try add plan that only affects data service
    [Tags]    post
    Add plan and confirm addition    only-data     ""    ["data"]    []

Try add plan that with one task
    [Tags]    post
    Add plan and confirm addition    one-tasks     ""    []    [{"name":"task-1","task_type":"BACKUP","full_backup":true,"schedule":{"job_type":"BACKUP","frequency":3,"period":"MINUTES"}}]

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

Try and delete plan
    [Tags]     delete
    Run and log and check request    /plan/only-data    DELETE    200    headers=${BASIC_AUTH}
    Run and log and check request    /plan/only-data    GET    404    headers=${BASIC_AUTH}

*** Keywords ***
Add plan and confirm addition
    [Arguments]        ${name}    ${description}=None    ${services}=None    ${tasks}=None
    [Documentation]    Adds a new plan.
    Run and log and check request    /plan/${name}    POST    200
    ...                              {"description":${description},"services":${services},"tasks":${tasks}}
    ...                              headers=${BASIC_AUTH}
    ${resp}=           Get request         backup_service    /plan/${name}
    Status should be   200                 ${resp}
    Dictionary like equals    ${resp.json()}    {"name":"${name}","description":${description},"services":${services},"tasks":${tasks}}    ['description']

Add task with period "${period}"
    Add plan and confirm addition    plan-${period}    ""    []    [{"name":"task-1","task_type":"BACKUP","full_backup":true,"schedule":{"job_type":"BACKUP","frequency":3,"period":"${period}"}}]
