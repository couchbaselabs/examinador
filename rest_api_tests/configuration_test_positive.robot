*** Settings ***
Documentation
...     Here lay the tests for the backup service configuartion REST API. The HOST is set in the init file but can be
...     overriden vai the command line to point to any arbitraty node that runs the backup service.
Force Tags       config
Library          RequestsLibrary
Library          REST    ${BACKUP_HOST}
Library          ../libraries/rest_utils.py
Suite setup     Set basic auth

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1


*** Test Cases ***
Retrieve backup service configuration
    [Tags]             get
    [Documentation]
    ...    Retrieves the backup service configuration via the REST API and confirm that the default values are returned
    ...    for history_rotation_period and history_rotation_size
    GET        /config                      headers=${BASIC_AUTH}
    Object     response body                required=["history_rotation_size", "history_rotation_period"]
    Integer    $.history_rotation_size      50
    Integer    $.history_rotation_period    30

Update backup service configuartion
    [Tags]             post
    [Documentation]    Updates the rotation configuration in the rotation history
    POST    /config    {"history_rotation_size":10, "history_rotation_period":70}    headers=${BASIC_AUTH}
    GET     /config    headers=${BASIC_AUTH}
    Integer    $.history_rotation_size      10
    Integer    $.history_rotation_period    70

Patch backup service rotation period
    [Tags]    patch
    [Documentation]   Partially updates the rotation configuration
    GET                          /config    headers=${BASIC_AUTH}
    ${current_rotation_size}=    Output     $.history_rotation_size
    PATCH                        /config    {"history_rotation_period":300}    headers=${BASIC_AUTH}
    GET                          /config    headers=${BASIC_AUTH}
    Integer                      $.history_rotation_size      ${current_rotation_size}
    Integer                      $.history_rotation_period    300

*** Keywords ***
Set basic auth
    ${auth}=              Get basic auth    Administrator    asdasd
    Set suite variable    ${BASIC_AUTH}         {"authorization":"${auth}"}
