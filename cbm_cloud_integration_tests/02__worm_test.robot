***Settings***
Documentation      Test that WORM backups can be performed.
Force tags         S3
Library            OperatingSystem
Library            DateTime
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${CLOUD_ARCHIVE}    obj_region=${REGION}
...                obj_access_key_id=${ACCESS_KEY_ID}    obj_secret_access_key=${SECRET_ACCESS_KEY}
...                obj_endpoint=${CLOUD_ENDPOINT}
Library            ../libraries/sdk_utils.py
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource
Resource           ../resources/aws.resource

Test Setup         Run Keywords
...                    Start minio    AND
...                    Wait for minio to start    AND
...                    Delete all buckets cli    AND
...                    Remove AWS S3 bucket    AND
...                    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True    AND
...                    Remove Directory    ${TEMP_DIR}${/}data/backups    recursive=True    AND
...                    Create CB bucket if it does not exist cli    AND
...                    Create AWS S3 bucket if it does not exist cli    object_lock=${TRUE}

Test Teardown     Run keywords
...                    Stop minio    AND
...                    Delete all buckets cli    AND
...                    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True    AND
...                    Remove Directory    ${TEMP_DIR}${/}data/backups    recursive=True


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


***Test Cases***
Test worm backup to S3
    [Tags]    Backup
    [Documentation]    This tests that documents can be backed up to S3 and checks that the documents remain unchanged
    ...                and that object lock retention is properly applied to all backed up objects.
    ${min_retention}=    Get Current Date    increment=100 days    result_format=%Y-%m-%dT%H:%M:%SZ
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    worm=100
    Create cloud backup

    ${result}=    Get cloud info as json
    ${bucket_index}=    Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]
    ...                            default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]
    ...                            2048
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][tombstones]
    ...                            0
    ${data}=    Get cloud cbriftdump data     backup_name=${result}[backups][-1][date]
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024
    Verify object lock retention    prefix=${ARCHIVE_NAME}/cloud_repo/${result}[backups][-1][date]
    ...                             min_retention_date=${min_retention}


Test resume worm backup to S3
    [Tags]    Backup
    [Documentation]    Test that if one backup to S3 is terminated mid process and then another backup to S3 is run with
    ...                the --resume flag then the backup restarts from where the previous backup had got to
    ${min_retention}=    Get Current Date    increment=100 days    result_format=%Y-%m-%dT%H:%M:%SZ
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    worm=100
    Run and terminate cloud backup

    ${result1}=    Get cloud info as json
    Create cloud backup        resume=None
    ${result2}=    Get cloud info as json
    Length should be               ${result2}[backups]         1
    Should be equal    ${result1}[backups][0][date]    ${result2}[backups][0][date]
    ${data}=    Get cloud cbriftdump data    backup_name=${result2}[backups][0][date]
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024
    Verify object lock retention    prefix=${ARCHIVE_NAME}/cloud_repo/${result1}[backups][-1][date]
    ...                             min_retention_date=${min_retention}
    Verify object lock retention    prefix=${ARCHIVE_NAME}/cloud_repo/${result2}[backups][-1][date]
    ...                             min_retention_date=${min_retention}

Test incremental backup
    [Tags]    Backup
    [Documentation]    This tests that a subsequent backup to S3 is incremental by checking the number of mutations
    ...                in the second backup is the same as the number of new documents added
    ${min_retention}=    Get Current Date    increment=100 days    result_format=%Y-%m-%dT%H:%M:%SZ
    Load documents into bucket using cbworkloadgen    key-pref=pref1    items=2048
    Create cloud repo    worm=100
    Create cloud backup

    ${result}=    Get cloud info as json
    Should Be Equal                ${result}[backups][-1][type]    FULL
    ${bucket_index}=         Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]          default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]     2048
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][tombstones]    0

    ${data}=    Get cloud cbriftdump data     backup_name=${result}[backups][-1][date]
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024
    Check key is included in backup     ${data}    pref1    2048
    Check key not included in backup      ${data}    pref2

    Load documents into bucket using cbworkloadgen    key-pref=pref2    items=222
    Create cloud backup

    ${result}=    Get cloud info as json
    Verify object lock retention    prefix=${ARCHIVE_NAME}/cloud_repo/${result}[backups][-1][date]
    ...                             min_retention_date=${min_retention}
    Should Be Equal                ${result}[backups][-1][type]    INCR
    ${bucket_index}=         Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]          default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]     222
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][tombstones]    0

    ${data}=    Get cloud cbriftdump data     backup_name=${result}[backups][-1][date]
    Verify cbworkloadgen documents    ${data}    expected_len_json=222    size=1024
    Check key not included in backup     ${data}    pref1
    Check key is included in backup      ${data}    pref2    222

    Create cloud backup

    ${result}=    Get cloud info as json
    Verify object lock retention    prefix=${ARCHIVE_NAME}/cloud_repo/${result}[backups][-1][date]
    ...                             min_retention_date=${min_retention}
    Should Be Equal                ${result}[backups][-1][type]    INCR
    ${data}=    Get cloud cbriftdump data     backup_name=${result}[backups][-1][date]
    Verify cbworkloadgen documents    ${data}    expected_len_json=0    size=1024

Test worm repo cannot be deleted
    [Tags]    Remove
    [Documentation]    This tests that a WORM repository cannot be deleted.
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    worm=100
    Create cloud backup

    ${result}=    Get cloud info as json
    ${bucket_index}=    Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]    default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]    2048

    Run Keyword And Expect Error    *    Run cloud remove

Test worm backup survives deletion of current object versions
    [Tags]    Backup    WORM
    [Documentation]    This tests that a WORM backup can still be read after the current versions of all
    ...                backup objects are deleted.
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    worm=100
    Create cloud backup

    ${result}=    Get cloud info as json
    ${bucket_index}=    Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]    default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]    2048

    Delete current version of cloud objects    prefix=${ARCHIVE_NAME}/cloud_repo
    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True

    ${result_after_delete}=    Get cloud info as json
    ${bucket_index_after}=    Get bucket index    ${result_after_delete}
    Should Be Equal                ${result_after_delete}[backups][-1][buckets][${bucket_index_after}][name]    default
    Should Be Equal as integers    ${result_after_delete}[backups][-1][buckets][${bucket_index_after}][mutations]    2048

Test worm backup can be restored after deletion of objects and bucket
    [Tags]    Backup    WORM    Restore
    [Documentation]    This tests that a WORM backup can still be restored after:
    ...                1. The current versions of all backup objects are deleted
    ...                2. The staging directory is deleted
    ...                3. The CB bucket is deleted
    ...                The WORM protection should preserve the backup data via object versioning.
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    worm=100
    Create cloud backup

    ${result}=    Get cloud info as json
    ${bucket_index}=    Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]    default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]    2048

    Delete current version of cloud objects    prefix=${ARCHIVE_NAME}/cloud_repo
    Remove Directory    ${LOCAL_DIR}    recursive=True

    Delete bucket cli
    Create CB bucket if it does not exist cli

    Run cloud restore and wait until persisted    items=2048

    ${restored_docs}=    Get doc info
    Check restored cbworkloadgen docs contents    ${restored_docs}    2048    1024

Test worm backup restore requires read-only flag after archive config deletion
    [Tags]    Backup    WORM    Restore
    [Documentation]    This tests that a WORM backup can only be restored with the --obj-read-only flag after:
    ...                1. The current versions of all backup objects are deleted
    ...                2. The staging directory is deleted
    ...                3. The CB bucket is deleted
    ...                Without --obj-read-only, restore should fail. With --obj-read-only, restore should succeed.
    ...                --obj-read-only is required because we cannot upload the logs without the log rotations
    ...                parameters stored in the archive-level config.
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    worm=100
    Create cloud backup

    ${result}=    Get cloud info as json
    ${bucket_index}=    Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]    default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]    2048

    Delete current version of cloud objects    prefix=${ARCHIVE_NAME}
    Remove Directory    ${LOCAL_DIR}    recursive=True

    Delete bucket cli
    Create CB bucket if it does not exist cli

    Run Keyword And Expect Error    *    Run cloud restore and wait until persisted    items=2048

    Run cloud restore and wait until persisted    items=2048    obj-read-only=None

    ${restored_docs}=    Get doc info
    Check restored cbworkloadgen docs contents    ${restored_docs}    2048    1024

Test interrupted worm backup can be purged
    [Tags]    Backup    WORM    Purge
    [Documentation]    This tests that an interrupted WORM backup can be purged by running a subsequent backup
    ...                with the --purge flag. The interrupted backup should be removed and only the new backup
    ...                should remain in the repository.
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    worm=100
    Run and terminate cloud backup

    ${result_before}=    Get cloud info as json
    Length Should Be    ${result_before}[backups]    1
    Should Be Equal    ${result_before}[backups][0][complete]    ${FALSE}

    Create cloud backup    purge=None

    ${result_after}=    Get cloud info as json
    Length Should Be    ${result_after}[backups]    1
    ${bucket_index}=    Get bucket index    ${result_after}
    Should Be Equal                ${result_after}[backups][0][buckets][${bucket_index}][name]    default
    Should Be Equal as integers    ${result_after}[backups][0][buckets][${bucket_index}][mutations]    2048
    ${data}=    Get cloud cbriftdump data    backup_name=${result_after}[backups][0][date]
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024

Test non-WORM backup deleted but WORM backup survives after file deletion
    [Tags]    Backup    WORM
    [Documentation]    This tests that when a non-WORM backup and a WORM backup exist in the same repository,
    ...                deleting all cloud files will remove the non-WORM backup but the WORM backup survives
    ...                due to object lock protection.
    ...                1. Create a non-WORM repo and backup
    ...                2. Enable WORM on the repo
    ...                3. Create a WORM-protected backup
    ...                4. Verify both backups are visible
    ...                5. Delete all cloud files
    ...                6. Verify only the WORM backup is visible
    Load documents into bucket using cbworkloadgen    key-pref=nonworm    items=1024
    Create cloud repo
    Create cloud backup

    ${result_before_worm}=    Get cloud info as json
    Length Should Be    ${result_before_worm}[backups]    1
    ${non_worm_backup_date}=    Set Variable    ${result_before_worm}[backups][0][date]

    Run worm    period=100

    Load documents into bucket using cbworkloadgen    key-pref=worm    items=1024
    Create cloud backup

    ${result_after_worm}=    Get cloud info as json
    Length Should Be    ${result_after_worm}[backups]    2
    ${worm_backup_date}=    Set Variable    ${result_after_worm}[backups][1][date]

    Delete current version of cloud objects    prefix=${ARCHIVE_NAME}/cloud_repo
    ...         obj_endpoint=${CLOUD_ENDPOINT}
    Remove Directory    ${LOCAL_DIR}    recursive=True

    ${result_after_delete}=    Get cloud info as json
    Length Should Be    ${result_after_delete}[backups]    1
    Should Be Equal    ${result_after_delete}[backups][0][date]    ${worm_backup_date}

Test worm backup can be restored after overwriting files with random data
    [Tags]    Backup    WORM    Restore
    [Documentation]    This tests that a WORM backup can still be restored after all backup files
    ...                are overwritten with random data. The WORM protection should preserve the
    ...                original backup data via object versioning, allowing successful restore.
    ...                1. Create a WORM backup with documents
    ...                2. Overwrite all backup files with random data
    ...                3. Delete the staging directory and CB bucket
    ...                4. Restore the backup using --obj-read-only flag
    ...                5. Verify restored documents match the original
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    worm=100
    Create cloud backup

    ${result}=    Get cloud info as json
    ${bucket_index}=    Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]    default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]    2048

    Overwrite cloud objects with random data    prefix=${ARCHIVE_NAME}/cloud_repo
    Remove Directory    ${LOCAL_DIR}    recursive=True

    Delete bucket cli
    Create CB bucket if it does not exist cli

    Run cloud restore and wait until persisted    items=2048    obj-read-only=None

    ${restored_docs}=    Get doc info
    Check restored cbworkloadgen docs contents    ${restored_docs}    2048    1024
