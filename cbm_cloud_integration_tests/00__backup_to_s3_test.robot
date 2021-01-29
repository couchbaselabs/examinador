***Settings***
Documentation      These test that backup to cloud operations can be performed.
Force tags         S3
Library            OperatingSystem
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${S3_ARCHIVE}
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource
Resource           ../resources/aws.resource

Suite setup        Run keywords    Delete bucket cli
...                AND    Wait for localstack to start
...                AND    Create AWS S3 bucket if it does not exist cli
Suite Teardown     Run keywords    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True
...                AND    Remove Directory    ${TEMP_DIR}${/}data/backups    recursive=True
...                AND    Remove AWS S3 bucket

***Variables***
${BIN_PATH}              %{HOME}${/}test-source${/}install${/}bin
${S3_ARCHIVE}            s3://aws-buck/archive
${S3_ENDPOINT}           http://localhost:4566
${ACCESS_KEY_ID}         test
${SECRET_ACCESS_KEY}     test
${REGION}                us-east-1


***Test Cases***
Test backup to S3
    [Tags]    Backup    in_progress
    [Documentation]    This tests that documents can be backed up to S3 and checks that the documents remain unchanged
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen    items=2048
    Configure backup    repo=S3_backup    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                 obj-region=${REGION}
    ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Run backup          repo=S3_backup    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                 obj-region=${REGION}
    ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result}=    Get info as json    repo=S3_backup    archive=${S3_ARCHIVE}
    ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${bucket_index}=         Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]
    ...                            default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]
    ...                            2048
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][tombstones]
    ...                            0
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${S3_ARCHIVE}${/}S3_backup${/}${result}[backups][-1][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data S3     dir=${dir}
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024

Test S3 examine
    [Tags]    Examine    in_progress
    [Documentation]    This tests that the Examine command can be used to return a specified document from S3
    ${result}=    Get info as json    repo=S3_backup    archive=${S3_ARCHIVE}
    ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${bucket_index}=         Get bucket index    ${result}
    ${doc}=    Run examine    repo=S3_backup    key=pymc1    obj-region=${REGION}    json=None
    ...                obj-staging-dir=${TEMP_DIR}${/}staging    archive=${S3_ARCHIVE}
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None    collection-string=default
    Should be equal    ${doc}[0][key]    pymc1
    Should be equal    ${doc}[0][backup]    ${result}[backups][-1][date]
    Verify cbworkloadgen documents    ${doc}    expected_len_json=1    size=1024

Test Restore from S3
    [Tags]    Restore    in_progress
    [Documentation]    Tests a backup can be restored from S3 and checks the restored documents remain unchanged
    Flush bucket REST
    Run restore and wait until persisted    repo=S3_backup    items=10    timeout_value=300
    ...                 obj-staging-dir=${TEMP_DIR}${/}staging    obj-region=${REGION}
    ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result}=    Get doc info
    Check restored cbworkloadgen docs contents    ${result}    10    1024

Test resume backup to S3
    [Tags]    Backup    in_progress
    [Documentation]    Test that if one backup to S3 is terminated mid process and then another backup to S3 is run with
    ...                the --resume flag then the backup restarts from where the previous backup had got to
    Flush bucket REST
    Load documents into bucket using cbworkloadgen     items=10
    Configure backup    repo=S3_resume_backup    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                 obj-region=${REGION}
    ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Run and terminate backup    repo=S3_resume_backup    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                 obj-region=${REGION}
    ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result1}=    Get info as json    repo=S3_resume_backup    archive=${S3_ARCHIVE}
    ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Run backup          repo=S3_resume_backup    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                 resume=None    obj-region=${REGION}
    ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result2}=    Get info as json    repo=S3_resume_backup    archive=${S3_ARCHIVE}
    ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Length should be               ${result2}[backups]         1
    Should be equal    ${result1}[backups][0][date]    ${result2}[backups][0][date]
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${S3_ARCHIVE}${/}S3_resume_backup${/}${result2}[backups][0][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data S3     dir=${dir}
    Verify cbworkloadgen documents    ${data}    expected_len_json=10   size=1024

Test Incremental backup
    [Tags]    Backup    in_progress
    [Documentation]    This tests that a subsequent backup to S3 is incremental by checking the number of mutations
    ...                in the second backup is the same as the number of new documents added
    Flush bucket REST
    Load documents into bucket using cbworkloadgen    key-pref=pymd    items=10
    Run backup      repo=S3_backup    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...             obj-region=${REGION}
    ...             obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...             obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Load documents into bucket using cbworkloadgen    key-pref=pyme    items=10
    Run backup      repo=S3_backup    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...             obj-region=${REGION}
    ...             obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...             obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result}=               Get info as json    repo=S3_backup    archive=${S3_ARCHIVE}
    ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${number_of_backups}=    Get Length    ${result}[backups]
    ${bucket_index}=         Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]          default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]     10
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][tombstones]    0
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${S3_ARCHIVE}${/}S3_backup${/}${result}[backups][-1][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data S3     dir=${dir}
    Verify cbworkloadgen documents    ${data}    expected_len_json=10    size=1024
    Check key not included in backup     ${data}    pymc
    Check key not included in backup     ${data}    pymd

Test all incremental backups restored
    [Tags]    Restore    in_progress
    [Documentation]    Tests all incremental backups can be restored from S3 by flushing bucket then restoring it and
    ...                showing it contains the correct number of documents in the correct format
    Load documents into bucket using cbworkloadgen    key-pref=pymf    items=10
    Run backup    repo=S3_backup    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...             obj-region=${REGION}
    ...             obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...             obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Flush bucket REST
    Run restore and wait until persisted    repo=S3_backup    items=30    timeout_value=300
    ...                 obj-staging-dir=${TEMP_DIR}${/}staging    obj-region=${REGION}
    ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result}=    Get doc info
    Check restored cbworkloadgen docs contents    ${result}    30    1024

Test S3 info per repo
    [Tags]    Info    in_progress
    [Documentation]    Configure multiple repos in S3 then use info command to confirm you get an empty entry per repo.
    FOR    ${i}    IN RANGE    10
        Configure backup    repo=info_backup_${i}    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
        ...                 obj-region=${REGION}
        ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
        ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
        ${result}=     Get info as json    repo=info_backup_${i}    archive=${S3_ARCHIVE}
        ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
        ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
        ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
        Should be Equal    ${result}[name]    info_backup_${i}
        Should Be Empty    ${result}[backups]
    END

Test S3 remove empty repo
    [Tags]    Remove    in_progress
    [Documentation]    This tests that the Remove command can be used to remove an empty repo from S3
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen    items=10
    Configure backup    repo=to_remove_repo    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                 obj-region=${REGION}
    ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result}=     Get info as json    repo=to_remove_repo    archive=${S3_ARCHIVE}
    ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Should be Equal    ${result}[name]    to_remove_repo
    Should Be Empty    ${result}[backups]
    Remove repo        repo=to_remove_repo    archive=${S3_ARCHIVE}
    ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result}=         Run Process     ${BIN_PATH}${/}cbbackupmgr    info    --archive     ${S3_ARCHIVE}
    ...                -r    to_remove_repo
    ...                --json    --obj-region    ${REGION}    --obj-staging-dir    ${TEMP_DIR}${/}staging
    ...                --obj-access-key-id    ${ACCESS_KEY_ID}    --obj-secret-access-key    ${SECRET_ACCESS_KEY}
    ...                --obj-endpoint    ${S3_ENDPOINT}    --S3-force-path-style
    Should Be Equal As Integers    ${result.rc}    1

Test S3 remove non-empty repo
    [Tags]    Remove    in_progress
    [Documentation]    This tests that the Remove command can be used to remove a repo along with its contents from S3
    ...                after a backup has been performed
    Create CB bucket if it does not exist cli
    Flush bucket REST
    Load documents into bucket using cbworkloadgen    items=10
    Configure backup    repo=to_remove_repo_with_backup    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                 obj-region=${REGION}
    ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Run backup      repo=to_remove_repo_with_backup    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...             obj-region=${REGION}
    ...             obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...             obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result}=     Get info as json    repo=to_remove_repo_with_backup    archive=${S3_ARCHIVE}
    ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${bucket_index}=         Get bucket index    ${result}
    Should be Equal                ${result}[name]       to_remove_repo_with_backup
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]         default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]    10
    Remove repo        repo=to_remove_repo_with_backup    archive=${S3_ARCHIVE}
    ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result}=         Run Process     ${BIN_PATH}${/}cbbackupmgr    info    --archive     ${S3_ARCHIVE}
    ...                -r    to_remove_repo_with_backup
    ...                --json    --obj-region    ${REGION}    --obj-staging-dir    ${TEMP_DIR}${/}staging
    ...                --obj-access-key-id    ${ACCESS_KEY_ID}    --obj-secret-access-key    ${SECRET_ACCESS_KEY}
    ...                --obj-endpoint    ${S3_ENDPOINT}    --S3-force-path-style
    Should Be Equal As Integers    ${result.rc}    1

Test advanced info per S3 repo
    [Tags]    Info     in_progress
    [Documentation]    Configure an S3 repos then do multiple backups and confirm the correct info is given for each
    ...                backup for each bucket.
    Delete bucket cli
    Create CB bucket if it does not exist cli         bucket=buck1
    Create CB bucket if it does not exist cli         bucket=buck2
    Load documents into bucket using cbworkloadgen    bucket=buck1    items=10
    Load documents into bucket using cbworkloadgen    bucket=buck2    items=10
    Configure backup    repo=advanced_info_per_repo    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                 obj-region=${REGION}
    ...                 obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                 obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Run backup      repo=advanced_info_per_repo    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...             obj-region=${REGION}
    ...             obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...             obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Load documents into bucket using cbworkloadgen    bucket=buck1    items=10
    Load documents into bucket using cbworkloadgen    bucket=buck2    items=10
    Run backup      repo=advanced_info_per_repo    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...             obj-region=${REGION}
    ...             obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...             obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Run backup      repo=advanced_info_per_repo    timeout_value=300    obj-staging-dir=${TEMP_DIR}${/}staging
    ...             obj-region=${REGION}
    ...             obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...             obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    ${result}=    Get info as json    repo=advanced_info_per_repo    archive=${S3_ARCHIVE}
    ...                obj-region=${REGION}    obj-staging-dir=${TEMP_DIR}${/}staging
    ...                obj-access-key-id=${ACCESS_KEY_ID}    obj-secret-access-key=${SECRET_ACCESS_KEY}
    ...                obj-endpoint=${S3_ENDPOINT}    S3-force-path-style=None
    Length should be               ${result}[backups]                                    3
    Should Be Equal as integers    ${result}[backups][0][buckets][0][mutations]          2048
    Should Be Equal as integers    ${result}[backups][0][buckets][1][mutations]          2048
    Should Be Equal as integers    ${result}[backups][1][buckets][0][mutations]          2048
    Should Be Equal as integers    ${result}[backups][1][buckets][1][mutations]          2048
    Should Be Equal as integers    ${result}[backups][2][buckets][0][mutations]          0
    Should Be Equal as integers    ${result}[backups][2][buckets][1][mutations]          0
    ${bucket_uuid}=    Get bucket uuid    bucket=buck1
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}advanced_info_per_repo${/}${result}[backups][0][date]
    ...    ${/}buck1-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data S3     dir=${dir}
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}advanced_info_per_repo${/}${result}[backups][1][date]
    ...    ${/}buck1-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data S3     dir=${dir}
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024
