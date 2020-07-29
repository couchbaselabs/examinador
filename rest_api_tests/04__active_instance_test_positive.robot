*** Settings ***
Documentation
...     Backup service instance REST API positive tests. The HOST is set in the init file but can be
...     overriden via the command line to point to any arbitraty node that runs the backup service.
Force Tags      instance    positive
Library         OperatingSystem
Library         Collections
Library         REST        ${BACKUP_HOST}
Library         ../libraries/utils.py
Resource        ../resources/rest.resource
Suite setup        Create client and instance dir
Suite Teardown     Remove Directory    ${TEMP_DIR}${/}add_active_instance    recursive=True

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

Add active instance and confirm
    [Tags]    get post
    [Documentation]
    ...    This test will create a simple profile added and then create an instance with that profile then it will check
    ...    that the instance has been created and tasks are scheduled as expected and that the cbbackupmgr repo was
    ...    created.
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
    Directory should exist                     ${resp.json()["archive"]}${/}${resp.json()["repo"]}

Pause and resume instance before next supposed task run
    [Tags]    post
    [Documentation]
    ...    This test relies on the previous test "Add active instance and confirm" test to have passed if not it will
    ...    fail as well. This test will pause the add_active_instance and confirm that the tasks get descheduled and
    ...    then it will  resume the task and confirm that the task is scheduled at its original time again.
    # Get original value of the instance
    ${original}=        Get request    backup_service       /cluster/self/instance/active/add_active_instance
    Status should be    200           ${original}
    # Pause the instance
    POST       /cluster/self/instance/active/add_active_instance/pause    {}    headers=${BASIC_AUTH}
    Integer    response status    200
    # Give it a bit to deschedule the tasks
    Sleep    500ms
    # Retrieve instance and confirm state is paused and that no tasks are scheduled to run
    ${paused}=          Get request    backup_service    /cluster/self/instance/active/add_active_instance
    Status should be    200                                    ${paused}
    Should be equal     ${paused.json()["state"]}              paused
    Dictionary should not contain key    ${paused.json()}      scheduled
    # Resume task
    POST       /cluster/self/instance/active/add_active_instance/resume    {}    headers=${BASIC_AUTH}
    Integer    response status    200
    # Give it a bit to schedule tasks
    Sleep    500ms
    # Retrieve the newly resumed instance
    ${resumed}=         Get request    backup_service    /cluster/self/instance/active/add_active_instance
    Status should be    200                                    ${resumed}
    Should be equal     ${resumed.json()["state"]}              active
    Should be equal     ${resumed.json()["scheduled"]["t1"]["next_run"]}    ${original.json()["scheduled"]["t1"]["next_run"]}

Archive active instance
    [Tags]    post
    [Documentation]
    ...    Archive an active instance and then delete it. It will use the the same instance that was created in previous
    ...    tests. It will also check that when the archived instance is deleting *without* forcing the deletion of the
    ...    cbbackupmgr repository, the repository is still there.
    POST    /cluster/self/instance/active/add_active_instance/archive    {"id":"archived-id"}    headers=${BASIC_AUTH}
    Integer    response status    200
    ${archived}=    Get request    backup_service    /cluster/self/instance/archived/archived-id
    Status should be    200    ${archived}
    ${original}=    Get request    backup_service    /cluster/self/instance/active/add_active_instance
    Status should be    404    ${original}
    DELETE     /cluster/self/instance/archived/archived-id    headers=${BASIC_AUTH}
    Integer    response status     200
    ${not_found}=    Get request    backup_service    /cluster/self/instance/archived/archived-id
    Status should be    404        ${not_found}
    # Delete does not delete the data so ensure it still exists
    Directory should exist        ${archived.json()["archive"]}${/}${archived.json()["repo"]}

*** Keywords ***
Get empty ${state} instances
    [Documentation]    Retrieves the instances in the state ${state} and checks that it gets and empty array
    GET        /cluster/self/instance/${state}    headers=${BASIC_AUTH}
    Integer    response status                    200
    Array      response body                      maxItems=0

Create client and instance dir
    [Documentation]
    ...    It creates the rest client as well as initializes the basic auth headers. It also creates the temporary
    ...    directory to use as an archive for this tests.
    Create REST session and auth
    Create Directory    ${TEMP_DIR}${/}add_active_instance
