*** Settings ***
Documentation
...     Backup service instance REST API negative tests. The HOST is set in the init file but can be
...     overriden via the command line to point to any arbitraty node that runs the backup service.
Force Tags      instance    positive
Library         OperatingSystem
Library         Collections
Library         REST        ${BACKUP_HOST}
Library         ../libraries/utils.py
Resource        ../resources/rest.resource
Suite setup        Create client and instance dir    negative_instance_dir
Suite Teardown     Remove Directory    ${TEMP_DIR}${/}negative_instance_dir    recursive=True

*** Variables  ***
${BACKUP_HOST}    http://localhost:7101/api/v1
${CB_NODE}        http://localhost:9001

*** Test Cases ***
Add instance without a profile
    POST    /cluster/self/instance/active/negative_add_instance    {"archive":"${TEMP_DIR}${/}negative_instance_dir"}    headers=${BASIC_AUTH}
    Integer    response status    400


*** Keywords ***
Add invalid instance
    [Arguments]    ${name}    ${profile}    ${archive}    ${bucket}    ${expected}=400
    [Documentation]    Tries and create an instance with the given arguments
    POST    /cluster/self/instance/active/${name}    {"archive":"${archive}","profile":"${profile}","bucket_name":"${bucket}"}    headers=${BASIC_AUTH}
    Integer    response status   ${expected}
