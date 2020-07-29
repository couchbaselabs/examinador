*** Settings ***
Documentation
...     Backup service instance REST API positive tests. The HOST is set in the init file but can be
...     overriden via the command line to point to any arbitraty node that runs the backup service.
Force Tags      instance    positive
Library         OperatingSystem
Library         REST        ${BACKUP_HOST}
Library         ../libraries/utils.py
Resource        ../resources/rest.resource
Suite setup     Create REST session and auth

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1

*** Test Cases ***
Get empty instances
    [Documentation]    At the start there should be no instances
    [Tags]    get
    [Template]    Get empty ${state} instances
    active
    imported
    archived

Add active instance
    [Documentation]
    ...    This test will create a simple profile added and then create an instance with that profile then it will check
    ...    that the instance has been created and tasks are scheduled as expected.
    [Setup]        Create Directory    ${TEMP_DIR}${/}add_active_instance
    [Teardown]     Remove Directory    ${TEMP_DIR}${/}add_active_instance    recursive=True
    POST       /profile/add_active_instance    {"tasks":[{"name":"t1","task_type":"BACKUP","schedule":{"job_type":"BACKUP","frequency":10,"period":"HOURS"}}]}    headers=${BASIC_AUTH}
    Integer    response status                 200
    POST       /cluster/self/instance/active/add_active_instance    {"archive":"${TEMP_DIR}${/}add_active_instance", "profile":"add_active_instance"}    headers=${BASIC_AUTH}
    Integer    response status                 200
    Sleep      500 ms   # Give enough time for the task to be scheduled
    ${resp}=   Get request                     backup_service       /cluster/self/instance/active/add_active_instance
    Status should be                           200                  ${resp}
    Log     ${resp.json()}    level=DEBUG
    Should be equal                            ${resp.json()["profile_name"]}                   add_active_instance
    Should be approx x from now                ${resp.json()["scheduled"]["t1"]["next_run"]}    10h

*** Keywords ***
Get empty ${state} instances
    [Documentation]    Retrieves the instances in the state ${state} and checks that it gets and empty array
    GET        /cluster/self/instance/${state}    headers=${BASIC_AUTH}
    Integer    response status                    200
    Array      response body                      maxItems=0
