***Settings***
Documentation      Test that basic backup to cloud operations can be performed.
Force tags         S3
Library            OperatingSystem
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${CLOUD_ARCHIVE}    obj_region=${REGION}
...                obj_access_key_id=${ACCESS_KEY_ID}    obj_secret_access_key=${SECRET_ACCESS_KEY}
...                obj_endpoint=${CLOUD_ENDPOINT}
Library            ../libraries/sdk_utils.py
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource
Resource           ../resources/aws.resource

Suite setup        Run keywords
...                    Start minio    AND
...                    Wait for minio to start
Suite Teardown     Run keywords
...                    Stop minio    AND
...                    Delete bucket cli    AND
...                    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True    AND
...                    Remove Directory    ${TEMP_DIR}${/}data/backups    recursive=True

Test Setup         Run Keywords
...                    Delete bucket cli    AND
...                    Remove AWS S3 bucket    AND
...                    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True    AND
...                    Remove Directory    ${TEMP_DIR}${/}data/backups    recursive=True    AND
...                    Create CB bucket if it does not exist cli    AND
...                    Create AWS S3 bucket if it does not exist cli


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
Test backup to S3
    [Tags]    Backup
    [Documentation]    This tests that documents can be backed up to S3 and checks that the documents remain unchanged
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo
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

Test resume backup to S3
    [Tags]    Backup
    [Documentation]    Test that if one backup to S3 is terminated mid process and then another backup to S3 is run with
    ...                the --resume flag then the backup restarts from where the previous backup had got to
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    repo=S3_resume_backup
    Run and terminate cloud backup    repo=S3_resume_backup

    ${result1}=    Get cloud info as json    repo=S3_resume_backup
    Create cloud backup    repo=S3_resume_backup    resume=None
    ${result2}=    Get cloud info as json    repo=S3_resume_backup
    Length should be               ${result2}[backups]         1
    Should be equal    ${result1}[backups][0][date]    ${result2}[backups][0][date]

    ${data}=    Get cloud cbriftdump data    backup_name=${result2}[backups][0][date]    repo=S3_resume_backup
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024

Test incremental backup
    [Tags]    Backup
    [Documentation]    This tests that a subsequent backup to S3 is incremental by checking the number of mutations
    ...                in the second backup is the same as the number of new documents added
    Load documents into bucket using cbworkloadgen    key-pref=pref1    items=2048
    Create cloud repo
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
    Should Be Equal                ${result}[backups][-1][type]    INCR
    ${data}=    Get cloud cbriftdump data     backup_name=${result}[backups][-1][date]
    Verify cbworkloadgen documents    ${data}    expected_len_json=0    size=1024

Test S3 remove empty repo
    [Tags]    Remove
    [Documentation]    This tests that the Remove command can be used to remove an empty repo from S3
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    repo=to_remove_repo

    ${result}=    Get cloud info as json    repo=to_remove_repo
    Should be Equal    ${result}[name]    to_remove_repo
    Should Be Empty    ${result}[backups]

    Run cloud remove    repo=to_remove_repo

    Run Keyword And Expect Error    *    Get cloud info as json    repo=to_remove_repo

Test S3 remove non-empty repo
    [Tags]    Remove
    [Documentation]    This tests that the Remove command can be used to remove a repo along with its contents from S3
    ...                after a backup has been performed
    Load documents into bucket using cbworkloadgen    items=2048
    Create cloud repo    repo=to_remove_repo_with_backup
    Create cloud backup    repo=to_remove_repo_with_backup

    ${result}=    Get cloud info as json    repo=to_remove_repo_with_backup
    ${bucket_index}=    Get bucket index    ${result}
    Should be Equal                ${result}[name]                                                   to_remove_repo_with_backup
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]            default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]       2048

    Run cloud remove    repo=to_remove_repo_with_backup

    Run Keyword And Expect Error    *    Get cloud info as json    repo=to_remove_repo_with_backup

Test resume backup after staging directory deleted with multiple buckets
    [Tags]    Backup    Resume
    [Documentation]    Test that a cloud backup of a CB cluster with multiple buckets can be interrupted
    ...                and then the backup can be resumed successfully.
    Create CB bucket if it does not exist cli    bucket=bucket1    ramQuota=100
    Create CB bucket if it does not exist cli    bucket=bucket2    ramQuota=100
    Load documents into bucket using cbworkloadgen    items=2048    bucket=default    key-pref=default
    Load documents into bucket using cbworkloadgen    items=1024    bucket=bucket1    key-pref=bucket1
    Load documents into bucket using cbworkloadgen    items=512     bucket=bucket2    key-pref=bucket2

    Create cloud repo
    Run and terminate cloud backup

    ${result1}=    Get cloud info as json
    Length should be    ${result1}[backups]    1
    Should Be Equal    ${result1}[backups][0][complete]    ${FALSE}

    Create cloud backup    resume=None

    ${result2}=    Get cloud info as json
    Length should be    ${result2}[backups]    1
    Should be equal    ${result1}[backups][0][date]    ${result2}[backups][0][date]
    Should Be Equal    ${result2}[backups][0][complete]    ${TRUE}
    Length should be    ${result2}[backups][0][buckets]    3
    ${default_idx}=    Get bucket index    ${result2}    bucket=default
    ${bucket1_idx}=    Get bucket index    ${result2}    bucket=bucket1
    ${bucket2_idx}=    Get bucket index    ${result2}    bucket=bucket2
    Should Be Equal as integers    ${result2}[backups][0][buckets][${default_idx}][mutations]    2048
    Should Be Equal as integers    ${result2}[backups][0][buckets][${bucket1_idx}][mutations]    1024
    Should Be Equal as integers    ${result2}[backups][0][buckets][${bucket2_idx}][mutations]    512

    Delete bucket cli    bucket=bucket1
    Delete bucket cli    bucket=bucket2
