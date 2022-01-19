*** Settings ***
Library            RequestsLibrary
Library            Process
Library            OperatingSystem
Library            ../libraries/cbexpimp_utils.py     ${BIN_PATH}    ${TEMP_DATA_DIR}
Resource           ../resources/couchbase.resource

*** Variables ***
${BIN_PATH}         ${SOURCE}${/}install${/}bin
${TEMP_DATA_DIR}    ${TEMP_DIR}${/}data${/}export
${WORKSPACE}        %{PWD}

*** Keywords ***
Run import JSON and wait until persisted
    [Arguments]         ${import_path}    ${host}=http://localhost:9000    ${bucket}=default
    ...                 ${user}=Administrator    ${password}=asdasd    ${format_out}=list    ${items}=2048
    ...                 ${timeout_value}=120    &{kwargs}
    [Documentation]     This function will run cbimport json and wait for docs to be persisted to disk.
    ${previous_items}=    Get item count    bucket=${bucket}
    Run import json    import_path=${import_path}    host=${host}    bucket=${bucket}    user=${user}
    ...                password=${password}    format_out=${format_out}    timeout_value=${timeout_value}    &{kwargs}
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Run import CSV and wait until persisted
    [Arguments]         ${import_path}    ${host}=http://localhost:9000    ${bucket}=default
    ...                 ${user}=Administrator    ${password}=asdasd    ${key_gen}=g=key::%num%    ${items}=2048
    ...                 ${timeout_value}=120    &{kwargs}
    [Documentation]     This function will run cbimport csv and wait for docs to be persisted to disk.
    ${previous_items}=    Get item count    bucket=${bucket}
    Run import csv    import_path=${import_path}    host=${host}    bucket=${bucket}    user=${user}
    ...               password=${password}    key_gen=${key_gen}    timeout_value=${timeout_value}    &{kwargs}
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Run docloader and wait until persisted
    [Arguments]         ${import_path}    ${host}=http://localhost:9000    ${bucket}=default
    ...                 ${user}=Administrator    ${password}=asdasd    ${mem_quota}=100    ${items}=7303
    ...                 ${timeout_value}=120    &{kwargs}
    [Documentation]     This function will run cbdocloader and wait for docs to be persisted to disk.
    ${previous_items}=    Get item count    bucket=${bucket}
    Run docloader    import_path=${import_path}    host=${host}    bucket=${bucket}    user=${user}
    ...              password=${password}    mem_quota=${mem_quota}    timeout_value=${timeout_value}    &{kwargs}
    Wait for items to be persisted to disk    ${previous_items}    ${items}    bucket=${bucket}

Check sample import results
    [Arguments]         ${host}=http://localhost:9000    ${bucket}=default
    ...                 ${user}=Administrator    ${password}=asdasd    ${items}=7303    ${indexes}=1
    ...                 ${expected_num_design_docs}=1    ${expected_num_views}=2
    ...                 ${timeout_value}=60    &{kwargs}
    [Documentation]     This function will check that a sample import was successful.
    ${result}=    Get current item number    bucket=${bucket}    user=${user}    password=${password}
    Should be equal as integers    ${result}    ${items}
    ${result}=    Get number of indexes collection aware    bucket=${bucket}    host=${host}    user=${user}
    ...                                                     password=${password}
    Should be equal as integers    ${result}    ${indexes}
    Check all indexes have been built collection aware    bucket=${bucket}    host=${host}    user=${user}
    ...                                                   password=${password}
    Check views    bucket=${bucket}    host=${host}    user=${user}    password=${password}
    ...            expected_num_design_docs=${expected_num_design_docs}    expected_num_views=${expected_num_views}

Install sample buckets
    [Arguments]    ${payload}    ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator
    ...            ${password}=asdasd
    [Documentation]    This function will install specified sample buckets using REST API.
    ${req}=    Set Variable    /sampleBuckets/install
    Run and log and check request    ${req}    POST    202    payload=${payload}    host=${host}    user=${user}
    ...                              password=${password}
