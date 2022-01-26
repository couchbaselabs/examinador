*** Settings ***
Documentation
...     Backup service configuartion REST API positive tests. The HOST is set in the init file but can be
...     overriden via the command line to point to any arbitraty node that runs the backup service.
Force Tags     config    positive
Library        REST    ${BACKUP_HOST}
Library        ../libraries/rest_utils.py
Resource        ../resources/common.resource
Suite setup    Set basic auth    Administrator    asdasd

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1


*** Test Cases ***
Retrieve backup service configuration
    [Tags]             get
    [Documentation]
    ...    Retrieves the backup service configuration via the REST API and confirm that the default value is returned
    ...    for history_rotation_size.
    Run and log and check request    /config    GET    200    headers=${BASIC_AUTH}
    Object     response body                required=["history_rotation_size"]
    Integer    $.history_rotation_size      50

Update backup service configuartion to valid values
    [Tags]             post
    [Documentation]    Updates the rotation configuration in the rotation history to acceptable values.
    [Template]         Update backup service configuartion
    5    # The minimum size and period
    200  # Maximum size and period
    50   # Back to the default values


*** Keywords ***
Set basic auth
    [Arguments]        ${username}=Administrator    ${password}=asdasd
    [Documentation]    Sets a suite variable BASIC_AUTH with the encoded basic auth to use in request headers
    ${auth}=              Get basic auth        ${username}    ${password}
    Set suite variable    ${BASIC_AUTH}         {"authorization":"${auth}"}


Update backup service configuartion
    [Arguments]    ${history_rotation_size}
    [Documentation]    Updates the backup service configuration. The values must be valid
    Run and log and check request    /config    POST    200    {"history_rotation_size":${history_rotation_size}}
    ...                              headers=${BASIC_AUTH}
    Run and log and check request    /config    GET    200    headers=${BASIC_AUTH}
    Integer    $.history_rotation_size      ${history_rotation_size}
