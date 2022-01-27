*** Settings ***
Documentation    Test that all invalid plan realted actions via the REST API.
Force Tags       negative    plan
Library          Collections
Library          OperatingSystem
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
Try and add a plan with an invalid name
    [Tags]    post
    [Documentation]
    ...    Try to add plan wit a variaty of invalid names. Valid names are those that follow the pattern
    ...    [a-zA-Z0-9][a-zA-Z0-9_-]{1,49}.
    [Template]    Add plan with invalid name
    _reserved     # Plans starting with _ are reserved for internal use
    *special*     # Special characters
    with space    # Plans can't contain a space
    daily.random  # Plans can't contain dots

Try to add plan that already exists
    [Tags]     post
    [Documentation]
    ...    Check that creating a plan with the same name is not allowed and that the original plan does not get
    ...    modified.
    Run and log and check request    /plan/duplication    POST    200    {"tasks": ${DEFAULT_TASKS}}                          headers=${BASIC_AUTH}
    Run and log and check request    /plan/duplication    POST    400    {"services": ["data"], "tasks": ${DEFAULT_TASKS}}    headers=${BASIC_AUTH}
    ${resp}=   GET request             backup_service            /plan/duplication
    Status should be                   200                       ${resp}
    Dictionary like equals             ${resp.json()}            {"name":"duplication","services":null,"tasks":${DEFAULT_TASKS}}

Try to delete plan that does not exist
    [Tags]    delete
    Run and log and check request    /plan/it-does-not-exist    DELETE    404    headers=${BASIC_AUTH}

Try to add invalid plans
    [Tags]    post
    [Template]    Send invalid plan
    name1    0     []                      ${DEFAULT_TASKS}  # Description is an integer and not a string
    name2    ""    ["full text search"]    ${DEFAULT_TASKS}  # Service list is invalid
    name3    ""    ["data"]                [0,1,2]           # Task are integers instead of JSON objects
    name4    ""    []                      [{}]              # Empty task
    name5    ""    []                      []                # No tasks
    name6    ""    "data,cbas"             ${DEFAULT_TASKS}  # Service is a string instead of a list/array
    # Invalid task without schedule
    name7    ""    []                      [{"name":"task-1","task_type":"BACKUP","full_backup":true}]
    # Invalid frequencies
    name8    ""    []                      [{"name":"task-1","task_type":"BACKUP","schedule":{"job_type":"BACKUP","frequency":0,"period":"HOURS"}}]
    name8    ""    []                      [{"name":"task-1","task_type":"BACKUP","schedule":{"job_type":"BACKUP","frequency":10000,"period":"HOURS"}}]
    # Invalid periods
    name9    ""    []                      [{"name":"task-1","task_type":"BACKUP","schedule":{"job_type":"BACKUP","frequency":10,"period":"hour"}}]
    name9    ""    []                      [{"name":"task-1","task_type":"BACKUP","schedule":{"job_type":"BACKUP","frequency":10,"period":"hour"}}]

Try to add plan with to many tasks
    [Tags]       post
    ${tasks}=    Generate random task template    number=15
    Send invalid plan    to-many-tasks    ""    []    ${tasks}

Try and delete a plan that is being used
    [Tags]    delete
    [Documentation]    Trying to delete a plan that is in use should return an error. This test will create an
    ...                repository using the duplication plan and attempt to delete the plan. This should fail. After
    ...                it will remove the repository.
    [Setup]    Run Keywords        Create directory    ${TEMP_DIR}${/}delete_in_use    AND
    ...        Run and log and check request    /cluster/self/repository/active/delete_in_use    POST    200
    ...        {"archive":"${TEMP_DIR}${/}delete_in_use${/}archive}", "plan": "duplication"}    headers=${BASIC_AUTH}
    [Teardown]    Run keywords     Remove directory    ${TEMP_DIR}${/}delete_in_use    recursive=True    AND
    ...           Run and log request    /cluster/self/repository/active/delete_in_use/archive    POST
    ...           {"id":"delete_in_use"}    headers=${BASIC_AUTH}    AND
    ...           Run and log request    /cluster/self/repository/archived/delete_in_use    DELETE
    ...                                  headers=${BASIC_AUTH}
    Run and log and check request    /plan/duplication    DELETE    400    headers=${BASIC_AUTH}
    Run and log and check request    /plan/duplication    GET    200    headers=${BASIC_AUTH}

*** Keywords ***
Add plan with invalid name
    [Arguments]    ${name}
    Run and log and check request    /plan/${name}    POST    400    {"tasks":${DEFAULT_TASKS}}    headers=${BASIC_AUTH}

Send invalid plan
    [Arguments]        ${name}    ${description}=None    ${services}=None    ${tasks}=None
    [Documentation]    Adds a new plan.
    Run and log and check request    /plan/${name}    POST    400
    ...                              {"description":${description},"services":${services},"tasks":${tasks}}
    ...                              headers=${BASIC_AUTH}
    ${resp}=           Get request         backup_service    /plan/${name}
    Status should be   404                 ${resp}
