*** Settings ***
Library    RequestsLibrary
Library    OperatingSystem
Library    ../libraries/rest_utils.py


*** Variables ***
${DEFAULT_TASKS}  [{"name":"task-1","task_type":"BACKUP","full_backup":true,"schedule":{"job_type":"BACKUP","frequency":3,"period":"DAYS"}}]


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
    ${req}=    Set Variable    /cluster/self/repository/${state}/${repository}/taskHistory
    ${resp}=    Run and log and check request on session    ${req}    GET    200    session=backup_service
    ...                                           params=${params}    log_response=True
    Return from keyword    ${resp.json()}

Confirm task is last and successfull
    [Arguments]        ${history}                    ${backup_name}
    Should be equal    ${history[0]["task_name"]}    ${backup_name}
    Should be equal    ${history[0]["status"]}       done

Get repository info
    [Arguments]    ${repository}    ${state}=active    ${limit}=0    ${offset}=0
    ${params}=             Create Dictionary                limit=${limit}    offset=${offset}
    ${req}=    Set Variable    /cluster/self/repository/${state}/${repository}/info
    ${resp}=    Run and log and check request on session    ${req}    GET    200    session=backup_service
    ...                                           params=${params}    log_response=True
    Return from keyword    ${resp.json()}

Create repository for triggering adhoc tasks
    [Documentation]    This will create an empty plan and used it as a base for an repository with name "${name}" and
    ...    archive "${archive}".
    [Arguments]    ${plan}=trigger-task-plan    ${name}=trigger-task-repository    ${archive}=trigger_archive
    Create directory    ${TEST_DIR}${/}${archive}
    Run and log and check request    /plan/${plan}    POST    200    {"tasks": ${DEFAULT_TASKS}}    headers=${BASIC_AUTH}
    Run and log and check request    /cluster/self/repository/active/${name}    POST    200
    ...                              {"archive":"${TEST_DIR}${/}${archive}", "plan":"${plan}"}    headers=${BASIC_AUTH}

Trigger backup
    [Arguments]         ${repo}    ${state}=active    ${full}=false
    ${req}=    Set Variable    /cluster/self/repository/${state}/${repo}/backup
    ${pd}=    Set Variable    {"full_backup":${full}}
    ${resp}=    Run and log and check request on session    ${req}    POST    200    payload=${pd}     user=${user}
    ...         password=${password}    session=backup_service    log_response=True
    Return from keyword    ${resp.json()["task_name"]}
