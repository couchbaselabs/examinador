*** Settings ***
Documentation    Test that all invalid profile realted actions via the REST API.
Force Tags       negative    profile
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
Try and add a profile with an invalid name
    [Tags]    post
    [Documentation]
    ...    Try to add profile wit a variaty of invalid names. Valid names are those that follow the pattern
    ...    [a-zA-Z0-9][a-zA-Z0-9_-]{1,49}.
    [Template]    Add profile with invalid name
    _reserved     # Profiles starting with _ are reserved for internal use
    *special*     # Special characters
    with space    # Profiles can't contain a space
    daily.random  # Profiles can't contain dots

Try to add profile that already exists
    [Tags]     post
    [Documentation]
    ...    Check that creating a profile with the same name is not allowed and that the original profile does not get
    ...    modified.
    POST       /profile/duplication    {}    headers=${BASIC_AUTH}
    Integer    response status         200
    POST       /profile/duplication    {"services": ["data"]}    headers=${BASIC_AUTH}
    Integer    response status         400
    ${resp}=   GET request             backup_service            /profile/duplication
    Status should be                   200                       ${resp}
    Dictionary like equals             ${resp.json()}            {"name":"duplication","services":null,"tasks":null}

Try to delete profile that does not exist
    [Tags]    delete
    DELETE    /profile/it-does-not-exist    headers=${BASIC_AUTH}
    Integer   response status               404

Try to add invalid profiles
    [Tags]    post
    [Template]    Send invalid profile
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

Try to add profile with to many tasks
    [Tags]       post
    ${tasks}=    Generate random task template    number=15
    Send invalid profile    to-many-tasks    ""    []    ${tasks}

Try and delete a profile that is being used
    [Tags]    delete
    [Documentation]    Trying to delete a profile that is in use should return an error. This test will create an
    ...                instance using the duplication profile and attempt to delete the profile. This should fail. After
    ...                it will remove the instance.
    [Setup]    Run Keywords        Create directory    ${TEMP_DIR}${/}delete_in_use    AND
    ...        POST      /cluster/self/instance/active/delete_in_use            {"archive":"${TEMP_DIR}${/}delete_in_use}", "profile": "duplication"}    headers=${BASIC_AUTH}
    [Teardown]    Run keywords     Remove directory    ${TEMP_DIR}${/}delete_in_use    recursive=True    AND
    ...           POST      /cluster/self/instance/active/delete_in_use/archive    {"id":"delete_in_use"}    headers=${BASIC_AUTH}    AND
    ...           DELETE    /cluster/self/instance/archived/delete_in_use          headers=${BASIC_AUTH}
    DELETE    /profile/duplication    headers=${BASIC_AUTH}
    Integer   response status         400
    GET       /profile/duplication    headers=${BASIC_AUTH}
    Integer   response status         200

*** Keywords ***
Add profile with invalid name
    [Arguments]    ${name}
    POST       /profile/${name}    {}    headers=${BASIC_AUTH}
    Integer    response status     400

Send invalid profile
    [Arguments]        ${name}    ${description}=None    ${services}=None    ${tasks}=None
    [Documentation]    Adds a new profile.
    POST               /profile/${name}    {"description":${description},"services":${services},"tasks":${tasks}}
    ...                headers=${BASIC_AUTH}
    Integer            response status     400
    ${resp}=           Get request         backup_service    /profile/${name}
    Status should be   404                 ${resp}
