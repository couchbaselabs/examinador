***Settings***
Documentation      These tests check that common utils functions work correctly.
Force tags         Libraries
Library            Process
Library            OperatingSystem
Library            Collections
Library            ../libraries/common_utils.py    ${SOURCE}
Library            ../libraries/cbexpimp_utils.py    ${BIN_PATH}    None
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${ARCHIVE}
Library            ../libraries/utils.py
Resource           ../resources/cbexpimp.resource
Resource           ../resources/cbm.resource

Suite setup        Run keywords    Delete bucket cli
...                AND    Create CB bucket if it does not exist cli
...                AND    Wait for indexer to be active
Suite Teardown     Run keywords    Collect backup logs and remove archive

***Variables***
${BIN_PATH}         ${SOURCE}${/}install${/}bin
${SAMPLE_DIR}       ${SOURCE}${/}install${/}samples
${ARCHIVE}          ${TEMP_DIR}${/}data${/}backups
${cluster_docs}
${backup_docs}

***Test Cases***
Test retrieve docs from cluster node
    [Tags]    Libraries    Retrieve
    [Documentation]    This tests that documents can be retrieved from a local cluster node using the
    ...                retrieve_docs_from_cluster_node() function.
    Run import JSON    ${SAMPLE_DIR}${/}travel-sample.zip    format_in=sample
    Sleep    5
    ${cluster_docs}=    Retrieve docs from cluster node
    Set Global Variable    ${cluster_docs}
    ${num_of_docs}=    Get Length    ${cluster_docs}
    Should Be Equal as integers    ${num_of_docs}    63288

Test retrieve docs from backup
    [Tags]    Libraries    Retrieve
    [Documentation]    This tests that documents can be retrieved from a backup using the retrieve_docs_from_backup()
    ...                function.
    Set index memory quota
    Configure backup    repo=test
    Run backup          repo=test
    ${backup_data_dir}=    Get data directory path of only backup    ${ARCHIVE}${/}test
    ${backup_docs}=    Retrieve docs from backup    ${backup_data_dir}
    Set Global Variable    ${backup_docs}
    ${num_of_docs}=    Get Length    ${backup_docs}
    Should Be Equal as integers    ${num_of_docs}    63288

Test validate docs
    [Tags]    Libraries    Validate
    [Documentation]    This tests that documents retrieved from a backup and the documents retrieved from a local
    ...                cluster can validate each other.
    Validate docs    ${backup_docs}    ${cluster_docs}    only_validate_data=True
    Log To Console    ${\n}Cluster docs successfully validated Backup docs
    Validate docs    ${cluster_docs}    ${backup_docs}    only_validate_data=True
    Log To Console    Backup docs successfully validated Cluster docs
