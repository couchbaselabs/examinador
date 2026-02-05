***Settings***
Documentation      Test info, examine, and restore operations from cloud backups.
Force tags         S3
Library            OperatingSystem
Library            Collections
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${CLOUD_ARCHIVE}    obj_region=${REGION}
...                obj_access_key_id=${ACCESS_KEY_ID}    obj_secret_access_key=${SECRET_ACCESS_KEY}
...                obj_endpoint=${CLOUD_ENDPOINT}
Library            ../libraries/sdk_utils.py
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource
Resource           ../resources/aws.resource

Suite setup        Run keywords
...                    Start minio    AND
...                    Wait for minio to start    AND
...                    Create CB bucket if it does not exist cli    AND
...                    Create AWS S3 bucket if it does not exist cli    AND
...                    Setup all cloud repos and backups
Suite Teardown     Run keywords
...                    Stop minio    AND
...                    Delete bucket cli    AND
...                    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True

Test Setup         Run Keywords
...                    Delete bucket cli    AND
...                    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True    AND
...                    Create CB bucket if it does not exist cli


***Variables***
${BIN_PATH}              ${SOURCE}${/}install${/}bin
${CLOUD_ENDPOINT}        http://localhost:4566
${ACCESS_KEY_ID}         test1234
${SECRET_ACCESS_KEY}     test1234
${REGION}                us-east-1
${CLOUD_BUCKET}          s3://aws-buck
${LOCAL_DIR}             ${TEMP_DIR}${/}staging
${ARCHIVE_NAME}          archive
${CLOUD_ARCHIVE}         ${CLOUD_BUCKET}${/}${ARCHIVE_NAME}
${LOCAL_ARCHIVE}         ${LOCAL_DIR}${/}${ARCHIVE_NAME}

${INITIAL_ITEMS}         2048
${INCREMENTAL_ITEMS_1}   100
${INCREMENTAL_ITEMS_2}   10
${TOTAL_ITEMS}           ${{${INITIAL_ITEMS} + ${INCREMENTAL_ITEMS_1} + ${INCREMENTAL_ITEMS_2}}}


***Keywords***
Setup all cloud repos and backups
    [Documentation]    Create all cloud repos and backups needed for the test suite.
    Load documents into bucket using cbworkloadgen    items=${INITIAL_ITEMS}
    Create cloud repo
    Create cloud backup
    Load documents into bucket using cbworkloadgen    key-pref=incr1    items=${INCREMENTAL_ITEMS_1}
    Create cloud backup
    Load documents into bucket using cbworkloadgen    key-pref=incr2    items=${INCREMENTAL_ITEMS_2}
    Create cloud backup
    FOR    ${i}    IN RANGE    3
        Create cloud repo    repo=empty_repo_${i}
    END


***Test Cases***
Test S3 info on empty repos
    [Tags]    Info
    [Documentation]    Verify info command returns empty backups list for repos with no backups.
    FOR    ${i}    IN RANGE    3
        ${result}=    Get cloud info as json    repo=empty_repo_${i}
        Should be Equal    ${result}[name]    empty_repo_${i}
        Should Be Empty    ${result}[backups]
    END

Test S3 info on repo with backups
    [Tags]    Info
    [Documentation]    Verify info command returns correct backup information for a repo with multiple backups.
    ${result}=    Get cloud info as json
    Should be Equal    ${result}[name]    cloud_repo
    Length should be    ${result}[backups]    3
    ${bucket_index}=    Get bucket index    ${result}
    Should Be Equal    ${result}[backups][0][type]    FULL
    Should Be Equal as integers    ${result}[backups][0][buckets][${bucket_index}][mutations]    ${INITIAL_ITEMS}
    Should Be Equal    ${result}[backups][1][type]    INCR
    Should Be Equal as integers    ${result}[backups][1][buckets][${bucket_index}][mutations]    ${INCREMENTAL_ITEMS_1}
    Should Be Equal    ${result}[backups][2][type]    INCR
    Should Be Equal as integers    ${result}[backups][2][buckets][${bucket_index}][mutations]    ${INCREMENTAL_ITEMS_2}

Test S3 info backup data with cbriftdump
    [Tags]    Info
    [Documentation]    Verify backup data can be read using cbriftdump and contains expected documents.
    ${result}=    Get cloud info as json
    ${data}=    Get cloud cbriftdump data    backup_name=${result}[backups][0][date]
    Verify cbworkloadgen documents    ${data}    expected_len_json=${INITIAL_ITEMS}    size=1024
    ${data}=    Get cloud cbriftdump data    backup_name=${result}[backups][1][date]
    Verify cbworkloadgen documents    ${data}    expected_len_json=${INCREMENTAL_ITEMS_1}    size=1024

Test S3 examine
    [Tags]    Examine
    [Documentation]    Verify examine command can retrieve a specific document from S3 backup.
    ${result}=    Get cloud info as json
    ${doc}    ${output}=    Run cloud examine    key=pymc1
    Should be equal    ${output}[0][document][key]    pymc1
    Should be equal    ${output}[0][backup]    ${result}[backups][0][date]
    Should be equal    ${output}[0][event_type]    ${1}
    Should be equal    ${output}[1][event_type]    ${6}
    Should be equal    ${output}[2][event_type]    ${6}
    Verify cbworkloadgen documents    ${doc}    expected_len_json=1    size=1024

Test S3 examine document from incremental backup
    [Tags]    Examine
    [Documentation]    Verify examine command can retrieve a document that only exists in an incremental backup.
    ${result}=    Get cloud info as json
    ${doc}    ${output}=    Run cloud examine    key=incr10
    Should be equal    ${output}[0][event_type]    ${7}
    Should be equal    ${output}[1][event_type]    ${1}
    Should be equal    ${output}[1][document][key]    incr10
    Should be equal    ${output}[1][backup]    ${result}[backups][1][date]
    Should be equal    ${output}[2][event_type]    ${6}
    Verify cbworkloadgen documents    ${doc}    expected_len_json=1    size=1024

Test Restore from S3
    [Tags]    Restore
    [Documentation]    Verify restore command restores all documents from all backups.
    Run cloud restore and wait until persisted    items=${TOTAL_ITEMS}
    ${result}=    Get doc info
    Check restored cbworkloadgen docs contents    ${result}    ${TOTAL_ITEMS}    1024

Test Restore from S3 verifies document integrity
    [Tags]    Restore
    [Documentation]    Verify restored documents from different backups have correct prefixes.
    Run cloud restore and wait until persisted    items=${TOTAL_ITEMS}
    ${result}=    Get doc info
    ${pymc_count}=    Set Variable    ${0}
    ${incr1_count}=    Set Variable    ${0}
    ${incr2_count}=    Set Variable    ${0}
    FOR    ${doc}    IN    @{result}
        ${name}=    Set Variable    ${doc}[name]
        IF    "${name}".startswith("pymc")
            ${pymc_count}=    Evaluate    ${pymc_count} + 1
        ELSE IF    "${name}".startswith("incr1")
            ${incr1_count}=    Evaluate    ${incr1_count} + 1
        ELSE IF    "${name}".startswith("incr2")
            ${incr2_count}=    Evaluate    ${incr2_count} + 1
        END
    END
    Should Be Equal As Integers    ${pymc_count}    ${INITIAL_ITEMS}
    Should Be Equal As Integers    ${incr1_count}    ${INCREMENTAL_ITEMS_1}
    Should Be Equal As Integers    ${incr2_count}    ${INCREMENTAL_ITEMS_2}
