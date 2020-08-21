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
    POST       /plan/duplication    {}    headers=${BASIC_AUTH}
    Integer    response status         200
    POST       /plan/duplication    {"services": ["data"]}    headers=${BASIC_AUTH}
    Integer    response status         400
    ${resp}=   GET request             backup_service            /plan/duplication
    Status should be                   200                       ${resp}
    Dictionary like equals             ${resp.json()}            {"name":"duplication","services":null,"tasks":null}

Try to delete plan that does not exist
    [Tags]    delete
    DELETE    /plan/it-does-not-exist    headers=${BASIC_AUTH}
    Integer   response status               404

Try to add invalid plans
    [Tags]    post
    [Template]    Send invalid plan
    name1    0     []                      []       # Description is an integer and not a string
    name2    ""    ["full text search"]    []       # Service list is invalid
    name3    ""    ["data"]                [0,1,2]  # Task are integers instead of JSON objects
    name4    ""    []                      [{}]     # Empty task
    name5    ""    "data,cbas"             []       # Service is a string instead of a list/array
    # Invalid task without schedule
    name6    ""    []                      [{"name":"task-1","task_type":"BACKUP","full_backup":true}]
    # Invalid frequencies
    name7    ""    []                      [{"name":"task-1","task_type":"BACKUP","schedule":{"job_type":"BACKUP","frequency":0,"period":"HOURS"}}]
    name7    ""    []                      [{"name":"task-1","task_type":"BACKUP","schedule":{"job_type":"BACKUP","frequency":10000,"period":"HOURS"}}]
    # Invalid periods
    name8    ""    []                      [{"name":"task-1","task_type":"BACKUP","schedule":{"job_type":"BACKUP","frequency":10,"period":"hour"}}]
    name8    ""    []                      [{"name":"task-1","task_type":"BACKUP","schedule":{"job_type":"BACKUP","frequency":10,"period":"hour"}}]

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
    ...        POST      /cluster/self/repository/active/delete_in_use            {"archive":"${TEMP_DIR}${/}delete_in_use${/}archive}", "plan": "duplication"}    headers=${BASIC_AUTH}    AND
    ...        Integer   response status    200
    [Teardown]    Run keywords     Remove directory    ${TEMP_DIR}${/}delete_in_use    recursive=True    AND
    ...           POST      /cluster/self/repository/active/delete_in_use/archive    {"id":"delete_in_use"}    headers=${BASIC_AUTH}    AND
    ...           DELETE    /cluster/self/repository/archived/delete_in_use          headers=${BASIC_AUTH}
    DELETE    /plan/duplication    headers=${BASIC_AUTH}
    Integer   response status         400
    GET       /plan/duplication    headers=${BASIC_AUTH}
    Integer   response status         200

*** Keywords ***
Add plan with invalid name
    [Arguments]    ${name}
    POST       /plan/${name}    {}    headers=${BASIC_AUTH}
    Integer    response status     400

Send invalid plan
    [Arguments]        ${name}    ${description}=None    ${services}=None    ${tasks}=None
    [Documentation]    Adds a new plan.
    POST               /plan/${name}    {"description":${description},"services":${services},"tasks":${tasks}}
    ...                headers=${BASIC_AUTH}
    Integer            response status     400
    ${resp}=           Get request         backup_service    /plan/${name}
    Status should be   404                 ${resp}
