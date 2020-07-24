*** Settings ***
Documentation
...     Backup service configuartion REST API positive tests. The HOST is set in the init file but can be
...     overriden via the command line to point to any arbitraty node that runs the backup service.
Force Tags     config    positive
Library        REST    ${BACKUP_HOST}
Library        ../libraries/rest_utils.py
Suite setup    Set basic auth    Administrator    asdasd

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1


*** Test Cases ***
Retrieve backup service configuration
    [Tags]             get
    [Documentation]
    ...    Retrieves the backup service configuration via the REST API and confirm that the default values are returned
    ...    for history_rotation_period and history_rotation_size.
    GET        /config                      headers=${BASIC_AUTH}
    Object     response body                required=["history_rotation_size", "history_rotation_period"]
    Integer    $.history_rotation_size      50
    Integer    $.history_rotation_period    30

Update backup service configuartion to valid values
    [Tags]             post
    [Documentation]    Updates the rotation configuration in the rotation history to acceptable values.
    [Template]         Update backup service configuartion
    1      5    # The minimum size and period
    365    200  # Maximum size and period
    30     50   # Back to the default values

Patch backup service rotation period
    [Tags]    patch
    [Documentation]   Partially updates the rotation configuration.
    GET                          /config    headers=${BASIC_AUTH}
    ${current_rotation_size}=    Output     $.history_rotation_size
    PATCH                        /config    {"history_rotation_period":300}    headers=${BASIC_AUTH}
    GET                          /config    headers=${BASIC_AUTH}
    Integer                      $.history_rotation_size      ${current_rotation_size}
    Integer                      $.history_rotation_period    300


*** Keywords ***
Set basic auth
    [Arguments]        ${username}=Administrator    ${password}=asdasd
    [Documentation]    Sets a suite variable BASIC_AUTH with the encoded basic auth to use in request headers
    ${auth}=              Get basic auth        ${username}    ${password}
    Set suite variable    ${BASIC_AUTH}         {"authorization":"${auth}"}


Update backup service configuartion
    [Arguments]    ${history_rotation_period}    ${history_rotation_size}
    [Documentation]    Updates the backup service configuration. The values must be valid
    POST    /config
    ...     {"history_rotation_size":${history_rotation_size}, "history_rotation_period":${history_rotation_period}}
    ...     headers=${BASIC_AUTH}
    Integer    response status              200
    GET        /config                      headers=${BASIC_AUTH}
    Integer    response status              200
    Integer    $.history_rotation_size      ${history_rotation_size}
    Integer    $.history_rotation_period    ${history_rotation_period}
