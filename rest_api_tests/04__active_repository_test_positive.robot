*** Settings ***
Documentation
...     Backup service repository REST API positive tests. The HOST is set in the init file but can be
...     overriden via the command line to point to any arbitraty node that runs the backup service.
Force Tags      repository    positive
Library         OperatingSystem
Library         Collections
Library         REST        ${BACKUP_HOST}
Library         ../libraries/utils.py
Resource        ../resources/rest.resource
Resource        ../resources/couchbase.resource
Resource        ../resources/common.resource
Suite setup        Create client and repository dir    add_active_repository
Suite Teardown     Remove Directory    ${TEMP_DIR}${/}add_active_repository    recursive=True

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1
${CB_NODE}        http://localhost:9001
${USER}           Administrator
${PASSWORD}       asdasd

*** Test Cases ***
Get empty respositories
    [Documentation]    At the start there should be no respositories
    [Tags]    get
    [Template]    Get empty ${state} respositories
    active
    imported
    archived

Add active repository and confirm
    [Tags]    get post
    [Documentation]
    ...    This test will create a simple plan added and then create an repository with that plan then it will check
    ...    that the repository has been created and tasks are scheduled as expected and that the cbbackupmgr repo was
    ...    created.
    Run and log and check request    /plan/add_active_repository    POST    200
    ...                              {"tasks":[{"name":"t1","task_type":"BACKUP","schedule":{"job_type":"BACKUP","frequency":10,"period":"HOURS"}}]}
    ...                              headers=${BASIC_AUTH}
    Run and log and check request    /cluster/self/repository/active/add_active_repository    POST    200
    ...                              {"archive":"${TEMP_DIR}${/}add_active_repository", "plan":"add_active_repository"}
    ...                              headers=${BASIC_AUTH}
    Sleep      500 ms   # Give enough time for the task to be scheduled
    ${resp}=   Get request                     backup_service       /cluster/self/repository/active/add_active_repository
    Status should be                           200                  ${resp}
    Log     ${resp.json()}    level=DEBUG
    Should be equal                            ${resp.json()["plan_name"]}                   add_active_repository
    Should be approx x from now                ${resp.json()["scheduled"]["t1"]["next_run"]}    10h
    Directory should exist                     ${resp.json()["archive"]}${/}${resp.json()["repo"]}

Pause and resume repository before next supposed task run
    [Tags]    post
    [Documentation]
    ...    This test relies on the previous test "Add active repository and confirm" test to have passed if not it will
    ...    fail as well. This test will pause the add_active_repository and confirm that the tasks get descheduled and
    ...    then it will  resume the task and confirm that the task is scheduled at its original time again.
    # Get original value of the repository
    ${original}=        Get request    backup_service       /cluster/self/repository/active/add_active_repository
    Status should be    200           ${original}
    # Pause the repository
    Run and log and check request    /cluster/self/repository/active/add_active_repository/pause    POST    200
    ...                              {}    headers=${BASIC_AUTH}
    # Give it a bit to deschedule the tasks
    Sleep    500ms
    # Retrieve repository and confirm state is paused and that no tasks are scheduled to run
    ${paused}=          Get request    backup_service    /cluster/self/repository/active/add_active_repository
    Status should be    200                                    ${paused}
    Should be equal     ${paused.json()["state"]}              paused
    Dictionary should not contain key    ${paused.json()}      scheduled
    # Resume task
    Run and log and check request    /cluster/self/repository/active/add_active_repository/resume    POST    200
    ...                              {}    headers=${BASIC_AUTH}
    # Give it a bit to schedule tasks
    Sleep    500ms
    # Retrieve the newly resumed repository
    ${resumed}=         Get request    backup_service    /cluster/self/repository/active/add_active_repository
    Status should be    200                                    ${resumed}
    Should be equal     ${resumed.json()["state"]}              active
    Should be equal     ${resumed.json()["scheduled"]["t1"]["next_run"]}    ${original.json()["scheduled"]["t1"]["next_run"]}

Archive active repository
    [Tags]    post
    [Documentation]
    ...    Archive an active repository and then delete it. It will use the the same repository that was created in previous
    ...    tests. It will also check that when the archived repository is deleting *without* forcing the deletion of the
    ...    cbbackupmgr repository, the repository is still there.
    Run and log and check request    /cluster/self/repository/active/add_active_repository/archive    POST    200
    ...                              {"id":"archived-id"}    headers=${BASIC_AUTH}
    ${archived}=    Get request    backup_service    /cluster/self/repository/archived/archived-id
    Status should be    200    ${archived}
    ${original}=    Get request    backup_service    /cluster/self/repository/active/add_active_repository
    Status should be    404    ${original}
    Run and log and check request    /cluster/self/repository/archived/archived-id    DELETE    200
    ...                              headers=${BASIC_AUTH}
    ${not_found}=    Get request    backup_service    /cluster/self/repository/archived/archived-id
    Status should be    404        ${not_found}
    # Delete does not delete the data so ensure it still exists
    Directory should exist        ${archived.json()["archive"]}${/}${archived.json()["repo"]}

Add bucket level repository
    [Tags]     post
    [Setup]    Create CB bucket if it does not exist    default
    [Teardown]    Remove directory    ${TEMP_DIR}${/}bucket_repository    recursive=True
    [Documentation]    This test will create an repository that should only backup the default bucket. This test will
    ...   create a bucket 'default', if it is not already present in the system.
    Create Directory    ${TEMP_DIR}${/}bucket_repository
    Run and log and check request    /cluster/self/repository/active/bucket-repository    POST    200
    ...                              {"plan":"empty", "archive":"${TEMP_DIR}${/}bucket_repository", "bucket_name":"default"}
    ...                              headers=${BASIC_AUTH}
    Run and log and check request    /cluster/self/repository/active/bucket-repository    GET    200
    ...                              headers=${BASIC_AUTH}
    String    $.bucket.name    default

*** Keywords ***
Get empty ${state} respositories
    [Documentation]    Retrieves the respositories in the state ${state} and checks that it gets and empty array
    Run and log and check request    /cluster/self/repository/${state}    GET    200    headers=${BASIC_AUTH}
    Array      response body                      maxItems=0
