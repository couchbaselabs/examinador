*** Settings ***
Library    RequestsLibrary
Library    OperatingSystem
Library    ../libraries/rest_utils.py

*** Keywords ***
Set basic auth
    [Arguments]        ${username}=Administrator    ${password}=asdasd
    [Documentation]    Sets a suite variable BASIC_AUTH with the encoded basic auth to use in request headers.
    ${auth}=              Get basic auth        ${username}    ${password}
    Set suite variable    ${BASIC_AUTH}         {"authorization":"${auth}"}

Create REST session
    [Arguments]        ${user}    ${password}
    [Documentation]    Creates a client that can be used to communicate to the client instead of creating one per test.
    ${auth}=           Create List             ${user}                 ${password}
    Create session     backup_service          ${BACKUP_HOST}          auth=${auth}

Create REST session and auth
    [Arguments]        ${username}=Administrator    ${password}=asdasd
    Set basic auth         ${username}    ${password}
    Create REST session    ${username}    ${password}

Create client and repository dir
    [Arguments]    ${dir_name}
    [Documentation]
    ...    It creates the rest client as well as initializes the basic auth headers. It also creates the temporary
    ...    directory to use as an archive for this tests.
    Create REST session and auth
    Create Directory    ${TEMP_DIR}${/}${dir_name}

Get task history
    [Arguments]   ${repository}    ${state}=active    ${limit}=0    ${offset}=0
    [Documentation]    Gets the task history for the requested repository.
    ${params}=          Create Dictionary                limit=${limit}    offset=${offset}
    ${resp}=            Get request      backup_service   /cluster/self/repository/${state}/${repository}/taskHistory    params=${params}
    Status should be    200              ${resp}
    Log                 ${resp.json()}   DEBUG
    Return from keyword                  ${resp.json()}

Confirm task is last and successfull
    [Arguments]        ${history}                    ${backup_name}
    Should be equal    ${history[0]["task_name"]}    ${backup_name}
    Should be equal    ${history[0]["status"]}       done

Get repository info
    [Arguments]    ${repository}    ${state}=active    ${limit}=0    ${offset}=0
    ${params}=             Create Dictionary                limit=${limit}    offset=${offset}
    ${resp}=               Get request    backup_service    /cluster/self/repository/${state}/${repository}/info    params=${params}
    Status should be       200                                     ${resp}
    Log                    ${resp.json()}                          DEBUG
    Return from keyword    ${resp.json()}

Create repository for triggering adhoc tasks
    [Documentation]    This will create an empty plan and used it as a base for an repository with name "${name}" and
    ...    archive "${archive}".
    [Arguments]    ${plan}=trigger-task-plan    ${name}=trigger-task-repository    ${archive}=trigger_archive
    Create directory    ${TEST_DIR}${/}${archive}
    POST                /plan/${plan}    {}    headers=${BASIC_AUTH}
    Integer             response status        200
    POST                /cluster/self/repository/active/${name}    {"archive":"${TEST_DIR}${/}${archive}", "plan":"${plan}"}    headers=${BASIC_AUTH}
    Integer             response status        200

Trigger backup
    [Arguments]         ${repo}    ${state}=active    ${full}=false
    ${trigger}=         Post request    backup_service    /cluster/self/repository/${state}/${repo}/backup    {"full_backup":${full}}
    Status should be    200                  ${trigger}
    Log                 ${trigger.json()}    DEBUG
    Return from keyword    ${trigger.json()["task_name"]}
