*** Settings ***
Documentation    Backup serivce configuartion REST API negative tests.
Force tags       config    negative
Library          Collections
Library          RequestsLibrary
Resource         ../resources/common.resource
Suite Setup      Create REST session    Administrator    asdasd

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1

*** Test Cases ***
Try to get config with out authentification
    [Tags]    get
    Create session     no-auth-session    ${BACKUP_HOST}
    ${req}=     Set Variable    /config
    Run and log and check request on session    ${req}    GET    401    session=no-auth-session
    ...                                           log_response=True

Try to get config with wrong credentials
    [Tags]    get
    ${auth}=           Create List             bad-user                bad-password
    Create session     invalid-auth-session    ${BACKUP_HOST}          auth=${auth}
    ${req}=    Set Variable    /config
    Run and log and check request on session    ${req}    GET    401    session=invalid-auth-session
    ...                                         log_response=True

Try to update to invalid values
    [Tags]    post
    [Documentation]
    ...    The backup service configuration values must follow the rules below:
    ...    5 <= history_rotation_size <= 200
    ...    Any values that do not fall in that range or are not integers should fail.
    [Template]    Update config with invalid values
    "alpha"     # Try a string value
    -1          # Try a value out of the unsigned integer range
    5.1         # Floating point values should not be allowed
    90000       # Value larger than we support/allow
    {"a":1}     # Value is an unexpected JSON object

Try to patch without sending values
    [Tags]    patch
    [Documentation]     Try to do a patch operation on the configuration with an empty body
    ${before}=    Get config
    ${req}=    Set Variable    /config
    ${resp}=    Run and log request on session    ${req}    POST    payload={}     session=backup_service
    ...                                           log_response=True
    Expect bad request response and no config change    ${resp}    ${before}

Try to patch with invalid values
    [Tags]    post
    [Template]    Patch config with invalid values
    "alpha"     # Try a string value
    -1          # Try a value out of the unsigned integer range
    5.1         # Floating point values should not be allowed
    90000       # Value larger than we support/allow
    {"a":1}     # Value is an unexpected JSON object

*** Keywords ***
Create REST session
    [Arguments]        ${user}    ${password}
    [Documentation]    Creates a client that can be used to communicate to the client instead of creating one per test.
    ${auth}=           Create List             ${user}                 ${password}
    Create session     backup_service          ${BACKUP_HOST}          auth=${auth}

Get config
    [Documentation]    Retrieve the current service configuration.
    ${req}=    Set Variable    /config
    ${resp}=    Run and log and check request on session    ${req}    GET    200    session=backup_service
    ...                                                     log_response=True
    [Return]    ${resp.json()}

Expect bad request response and no config change
    [Arguments]    ${resp}    ${before}
    Status should be    400    ${resp}
    ${after}=           Get config
    Dictionaries should be equal     ${after}    ${before}    The configuration should have not changed

Update config with invalid values
    [Arguments]    ${history_rotation_size}
    [Documentation]
    ...         Sends a POST request with the given values which should be invalid. It expects the service to return
    ...         with status 404 qand the configuration value to stay the same before and after the POST request.
    ${before}=    Get config
    ${req}=    Set Variable    /config
    ${pd}=    Set Variable    {"history_rotation_size":${history_rotation_size}}
    ${resp}=    Run and log request on session    ${req}    POST    payload=${pd}     session=backup_service
    ...                                           log_response=True
    Expect bad request response and no config change    ${resp}    ${before}

Patch config with invalid values
    [Arguments]    ${history_rotation_size}
    [Documentation]
    ...         Sends a PATCH request with the given values which should be invalid. It expects the service to return
    ...         with status 400 and the configuration value to stay the same before and after the PATCH request.
    ${before}=    Get config
    ${req}=    Set Variable    /config
    ${pd}=    Set Variable    {"history_rotation_size":${history_rotation_size}}
    ${resp}=    Run and log request on session    ${req}    PATCH    payload=${pd}     session=backup_service
    ...                                           log_response=True
    Expect bad request response and no config change    ${resp}    ${before}
