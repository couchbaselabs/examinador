***Settings***
Documentation      These tests check that simple data can be exported from and imported to a Couchbase server.
Force tags         Cluster
Library            Process
Library            OperatingSystem
Library            Collections
Library            ../libraries/sdk_utils.py
Library            ../libraries/cbexpimp_utils.py    ${BIN_PATH}    ${TEMP_DATA_DIR}
Resource           ../resources/couchbase.resource
Resource           ../resources/cbexpimp.resource

Suite setup        Run keywords    Delete bucket cli
...                AND    Wait for indexer to be active
...                AND    Create CB bucket if it does not exist cli
...                AND    Load documents into bucket using cbc bucket level    items=${ITEMS}
...                AND    Create directory    ${TEMP_DATA_DIR}
Suite Teardown     Remove Directory    ${TEMP_DATA_DIR}    recursive=True

***Variables***
${BIN_PATH}         ${SOURCE}${/}install${/}bin
${TEMP_DATA_DIR}    ${TEMP_DIR}${/}cbtests_expimp_data
${ITEMS}            2048

***Test Cases***
Test simple data export in json format
    [Tags]             Export    JSON
    [Documentation]    This tests that cbexport can export data from a Couchabse cluster in JSON format.
    ${file_name}=    Set Variable    simple_export_data.json
    Run export json    ${file_name}
    Check exported json data contents    ${file_name}    ${ITEMS}    example

Test simple data import in json lines format
    [Tags]             Import    JSON    Lines
    [Documentation]    This tests that cbimport can import data to a Couchbase cluster in JSON (lines) format.
    Flush bucket REST
    ${file_name}=    Generate simple data    ${TEMP_DATA_DIR}    JSON_LINES
    Run import JSON    ${TEMP_DATA_DIR}${/}${file_name}    format_in=lines    generate-key=%num%
    ${result}=    Get doc info
    Check imported data contents    ${result}    ${ITEMS}    example

Test simple data import in json list format
    [Tags]             Import    JSON    List
    [Documentation]    This tests that cbimport can import data to a Couchbase cluster in JSON (list) format.
    Flush bucket REST
    ${file_name}=    Generate simple data    ${TEMP_DATA_DIR}    JSON_LIST
    Run import JSON    ${TEMP_DATA_DIR}${/}${file_name}    format_in=list    generate-key=%num%
    ${result}=    Get doc info
    Check imported data contents    ${result}    ${ITEMS}    example

Test simple data import in csv format
    [Tags]             Import    CSV
    [Documentation]    This tests that cbimport can import data to a Couchbase cluster in CSV format.
    Flush bucket REST
    ${file_name}=    Generate simple data    ${TEMP_DATA_DIR}    CSV
    Run import CSV    ${TEMP_DATA_DIR}${/}${file_name}    infer-types=None
    ${result}=    Get doc info
    Check imported data contents    ${result}    ${ITEMS}    example

Test simple data import in tsv format
    [Tags]             Import    TSV
    [Documentation]    This tests that cbimport can import data to a Couchbase cluster in TSV format.
    Flush bucket REST
    ${file_name}=    Generate simple data    ${TEMP_DATA_DIR}    TSV
    Run import CSV    ${TEMP_DATA_DIR}${/}${file_name}    infer-types=None    field-separator=\t
    ${result}=    Get doc info
    Check imported data contents    ${result}    ${ITEMS}    example

Test simple data import binary
    [Tags]             Import    Binary
    [Documentation]    This tests that cbimport will not import binary data to a Couchbase cluster.
    Flush bucket REST
    ${file_name}=    Generate simple data    ${TEMP_DATA_DIR}    BINARY
    Run import JSON    ${TEMP_DATA_DIR}${/}${file_name}    generate-key=%num%    check_subcommand_exitcode=False
    ${result}=    Get doc info
    Check imported data contents    ${result}    0    example

Test mixed json and binary data
    [Tags]             Import    JSON    Binary
    [Documentation]    This tests that cbimport will not import binary data to a Couchbase cluster.
    Flush bucket REST
    ${file_name}=    Generate simple data    ${TEMP_DATA_DIR}    MIXED
    Run import JSON    ${TEMP_DATA_DIR}${/}${file_name}    format_in=lines    generate-key=%num%
    ...                check_subcommand_exitcode=False
    ${result}=    Get doc info
    Check imported data contents    ${result}    1900    example
