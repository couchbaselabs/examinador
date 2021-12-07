***Settings***
Documentation      These tests check specific miscellaneous features and deprecated tools.
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
...                AND    Create CB bucket if it does not exist cli    ramQuota=200

***Variables***
${BIN_PATH}         ${SOURCE}${/}install${/}bin
${SAMPLE_DIR}       ${SOURCE}${/}install${/}samples
${TEMP_DATA_DIR}    ${TEMP_DIR}${/}data${/}export

***Test Cases***
Test sample import using docloader with existing bucket
    [Tags]             Docloader    Sample
    [Documentation]    This tests that sample data can be loaded into a Couchbase cluster using docloader
    ...                (currently deprecated).
    Run docloader    ${SAMPLE_DIR}${/}beer-sample.zip
    Check sample import results

Test sample import using docloader without existing bucket
    [Tags]             Docloader    Sample
    [Documentation]    This tests that sample data can be loaded into a Couchbase cluster using docloader (currently
    ...                deprecated) without the required bucket existing in a cluster (currently deprecated).
    Delete bucket if it does exist cli
    Run docloader    ${SAMPLE_DIR}${/}beer-sample.zip
    Check sample import results

Test REST API install
    [Tags]             REST API    Sample    Beer
    [Documentation]    This tests if a sample bucket can be installed using a REST API endpoint.
    Delete bucket if it does exist cli
    ${payload}    Set Variable    ["beer-sample"]
    Install sample buckets    ${payload}
    Sleep    10
    Check sample import results    bucket=beer-sample