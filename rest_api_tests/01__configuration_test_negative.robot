*** Settings ***
Documentation    Backup serivce configuartion REST API negative tests.
Force tags       config    negative
Library          Collections
Library          RequestsLibrary
Suite Setup      Create REST session    Administrator    asdasd

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1

*** Test Cases ***
Try to get config with out authentification
    [Tags]    get
    Create session     no-auth-session    ${BACKUP_HOST}
    ${resp}=           Get request        no-auth-session    /config
    Status should be   401                ${resp}

Try to get config with wrong credentials
    [Tags]    get
    ${auth}=           Create List             bad-user                bad-password
    Create session     invalid-auth-session    ${BACKUP_HOST}          auth=${auth}
    ${resp}=           Get request             invalid-auth-session    /config
    Status should be   401                     ${resp}

Try to update to invalid values
    [Tags]    post
    [Documentation]
    ...    The backup service configuration values must follow the rules below:
    ...    1 <= history_rotation_period <= 365 and 5 <= history_rotation_size <= 200
    ...    Any values that do not fall in that range or are not integers should fail.
    [Template]    Update config with invalid values
    "alpha"    "omega"    # Try strings
    -1          5         # One of the values is out of the integer range
    5.1         100.5     # Floats should not be allowed
    3           90000     # Second value is outside the range


*** Keywords ***
Create REST session
    [Arguments]        ${user}    ${password}
    [Documentation]    Creates a client that can be used to communicate to the client instead of creating one per test.
    ${auth}=           Create List             ${user}                 ${password}
    Create session     backup_service          ${BACKUP_HOST}          auth=${auth}

Get config
    [Documentation]    Retrieve the current service configuration.
    ${resp}=     GET request    backup_service    /config
    Status should be           200               ${resp}
    [Return]    ${resp.json()}

Update config with invalid values
    [Arguments]    ${history_rotation_period}    ${history_rotation_size}
    [Documentation]
    ...         Sends a POST request with the given values which should be invalid. It expects the service to return
    ...         with status 404 and the configuration value to stay the same before and after the POST request.
    ${before}=    Get config
    ${resp}=      POST request    backup_service    /config
    ...     {"history_rotation_period":${history_rotation_period},"history_rotation_size":${history_rotation_size}}
    Status should be    400    ${resp}
    ${after}=           Get config
    Dictionaries should be equal     ${after}    ${before}    The configuration should have not changed
