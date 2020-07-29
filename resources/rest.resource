*** Settings ***
Library    RequestsLibrary
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

Create client and instance dir
    [Arguments]    ${dir_name}
    [Documentation]
    ...    It creates the rest client as well as initializes the basic auth headers. It also creates the temporary
    ...    directory to use as an archive for this tests.
    Create REST session and auth
    Create Directory    ${TEMP_DIR}${/}${dir_name}
