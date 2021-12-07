***Settings***
Documentation      These tests check that sample datasets can be imported using cbimport.
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

***Variables***
${BIN_PATH}         ${SOURCE}${/}install${/}bin
${SAMPLE_DIR}       ${SOURCE}${/}install${/}samples
${TEMP_DATA_DIR}    ${TEMP_DIR}${/}data${/}export

***Test Cases***
Test sample import beer-sample dataset with existing bucket
    [Tags]             Import    Sample    Beer
    [Documentation]    This tests that beer-sample data can be loaded into a Couchbase cluster using cbimport.
    Run import JSON    ${SAMPLE_DIR}${/}beer-sample.zip    format_in=sample
    Check sample import results    items=7303    indexes=1    expected_num_design_docs=1   expected_num_views=2

Test sample import beer-sample dataset without existing bucket
    [Tags]             Import    Sample    Beer
    [Documentation]    This tests that beer-sample data can be loaded into a Couchbase cluster using cbimport without
    ...                the required bucket existing in a cluster.
    Delete bucket if it does exist cli
    Run import JSON    ${SAMPLE_DIR}${/}beer-sample.zip    format_in=sample
    Check sample import results    items=7303    indexes=1    expected_num_design_docs=1   expected_num_views=2

Test sample import gamesim-sample dataset with existing bucket
    [Tags]             Import    Sample    Gamesim
    [Documentation]    This tests that gamesim-sample data can be loaded into a Couchbase cluster using cbimport.
    Enable flush
    Flush bucket REST
    Drop all indexes collection aware
    Drop all design docs
    Run import JSON    ${SAMPLE_DIR}${/}gamesim-sample.zip    format_in=sample
    Check sample import results    items=586    indexes=1    expected_num_design_docs=1   expected_num_views=2

Test sample import gamesim-sample dataset without existing bucket
    [Tags]             Import    Sample    Gamesim
    [Documentation]    This tests that gamesim-sample data can be loaded into a Couchbase cluster using cbimport without
    ...                the required bucket existing in a cluster.
    Delete bucket if it does exist cli
    Run import JSON    ${SAMPLE_DIR}${/}gamesim-sample.zip    format_in=sample
    Check sample import results    items=586    indexes=1    expected_num_design_docs=1    expected_num_views=2

Test sample import travel-sample dataset with existing bucket
    [Tags]             Import    Sample    Travel
    [Documentation]    This tests that travel-sample data can be loaded into a Couchbase cluster using cbimport.
    Enable flush
    Flush bucket REST
    Drop all indexes collection aware
    Drop all design docs
    Run import JSON    ${SAMPLE_DIR}${/}travel-sample.zip    format_in=sample
    Check sample import results    items=63288    indexes=23    expected_num_design_docs=0   expected_num_views=0

Test sample import travel-sample dataset without existing bucket
    [Tags]             Import    Sample    Travel
    [Documentation]    This tests that travel-sample data can be loaded into a Couchbase cluster using cbimport without
    ...                the required bucket existing in a cluster.
    Delete bucket if it does exist cli
    Run import JSON    ${SAMPLE_DIR}${/}travel-sample.zip    format_in=sample
    Check sample import results    items=63288    indexes=23    expected_num_design_docs=0    expected_num_views=0