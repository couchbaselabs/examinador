***Settings***
Documentation      Test backwards compatibility with backup archives created with old versions of cbbackupmgr.
...                This suite verifies that info, examine, and restore operations can be performed
...                on old archives.
Force tags         S3    BackwardsCompatibility
Library            OperatingSystem
Library            Collections
Library            Process
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${CLOUD_ARCHIVE}    obj_region=${REGION}
...                obj_access_key_id=${ACCESS_KEY_ID}    obj_secret_access_key=${SECRET_ACCESS_KEY}
...                obj_endpoint=${CLOUD_ENDPOINT}
Library            ../libraries/sdk_utils.py
Library            ../libraries/cloud_backwards_compatibility.py
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource
Resource           ../resources/aws.resource

Suite setup        Run keywords
...                    Start minio    AND
...                    Wait for minio to start    AND
...                    Download legacy archives from S3
Suite Teardown     Run keywords
...                    Stop minio    AND
...                    Cleanup all test buckets    AND
...                    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True    AND
...                    Remove Directory    ${LOCAL_LEGACY_ARCHIVES}    recursive=True


***Variables***
${BIN_PATH}                   ${SOURCE}${/}install${/}bin
${CLOUD_ENDPOINT}             http://localhost:4566
${ACCESS_KEY_ID}              test1234
${SECRET_ACCESS_KEY}          test1234
${REGION}                     us-east-1
${CLOUD_BUCKET}               s3://aws-buck
${LOCAL_DIR}                  ${TEMP_DIR}${/}staging
${ARCHIVE_NAME}               archive
${CLOUD_ARCHIVE}              ${CLOUD_BUCKET}${/}${ARCHIVE_NAME}
${LOCAL_ARCHIVE}              ${LOCAL_DIR}${/}${ARCHIVE_NAME}
${LOCAL_LEGACY_ARCHIVES}      ${TEMP_DIR}${/}legacy-archives

${REMOTE_S3_BUCKET}           s3://cbm-integration-tests
${TARBALL_PATH}               backwards_compatibility
${TARBALL_NAME}               all-versions.tar.gz


***Keywords***
Download legacy archives from S3
    [Documentation]    Download all legacy backup archives from the remote S3 bucket.
    ...                Downloads an archive containing all version directories (v6.6, v7.0, v7.2, v7.6, v8.0)
    ...                and extracts it to the local legacy archives directory.
    ...                This is run once at suite setup to avoid downloading for each test.
    Create Directory    ${LOCAL_LEGACY_ARCHIVES}
    ${local_tar_path}=    Set Variable    ${TEMP_DIR}${/}${TARBALL_NAME}
    ${download_cmd}=    Create List    aws    s3    cp
    ...                 ${REMOTE_S3_BUCKET}${/}${TARBALL_PATH}${/}${TARBALL_NAME}
    ...                 ${local_tar_path}
    ...                 --no-sign-request
    Run and log and check process    ${download_cmd}    shell=True
    ${extract_cmd}=    Create List    tar    -xzf    ${local_tar_path}    -C    ${LOCAL_LEGACY_ARCHIVES}
    Run and log and check process    ${extract_cmd}    shell=True
    Remove File    ${local_tar_path}

Cleanup all test buckets
    [Documentation]    Delete all Couchbase buckets including default and any buckets defined in TEST_VERSIONS.
    Delete bucket cli
    ${versions}=    Get test versions
    FOR    ${version}    IN    @{versions}
        ${buckets}=    Get all buckets for version    ${version}
        FOR    ${bucket}    IN    @{buckets}
            Delete bucket cli    bucket=${bucket}
        END
    END

Setup test for version
    [Arguments]    ${version}
    [Documentation]    Setup a test for a specific legacy version.
    ...                Cleans up previous state and uploads the version's archive to minio.
    ...                Deletes all buckets (including default) and creates only the buckets needed for this version.
    Cleanup all test buckets
    Remove AWS S3 bucket
    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True
    ${buckets}=    Get all buckets for version    ${version}
    FOR    ${bucket}    IN    @{buckets}
        Create CB bucket if it does not exist cli    bucket=${bucket}    ramQuota=100
    END
    Create AWS S3 bucket if it does not exist cli
    Upload legacy archive to minio    ${version}

Upload legacy archive to minio
    [Arguments]    ${version}
    [Documentation]    Upload the legacy archive for the specified version to minio.
    ${command}=    Create List    aws    s3    sync
    ...            ${LOCAL_LEGACY_ARCHIVES}${/}${version}
    ...            ${CLOUD_BUCKET}${/}${ARCHIVE_NAME}
    ...            --endpoint-url\=${CLOUD_ENDPOINT}
    Run and log and check process    ${command}    shell=True

Get bucket index from backups
    [Arguments]    ${data}    ${bucket}=default    ${backup_idx}=0
    [Documentation]    Returns the index of the desired bucket in the specified backup.
    FOR    ${i}    ${buck}    IN ENUMERATE    @{data}[backups][${backup_idx}][buckets]
        Return From Keyword If    "${buck}[name]" == "${bucket}"    ${i}
    END
    Fail    Bucket ${bucket} not found in backup ${backup_idx}

Wait for all buckets to be persisted
    [Arguments]    ${expected_bucket_totals}
    [Documentation]    Wait for all buckets to be persisted based on the expected_bucket_totals dictionary.
    FOR    ${bucket}    ${expected_total}    IN    &{expected_bucket_totals}
        Wait for items to be persisted to disk    ${0}    ${expected_total}    bucket=${bucket}
    END

Verify bucket counts by prefix
    [Arguments]    ${version}    ${repo}    ${expected_bucket_totals}    ${backup_idx}=${-1}
    [Documentation]    Verify document counts by key prefix for all buckets.
    ...                Each bucket may have documents with different prefixes from different backups.
    ...                This keyword counts documents for each prefix and verifies the total.
    FOR    ${bucket}    ${expected_total}    IN    &{expected_bucket_totals}
        # Get all prefix->count mappings for this bucket
        ${expected_prefix_counts}=    Get prefix counts for bucket    ${version}    ${repo}    ${bucket}    ${backup_idx}
        # Count documents for each prefix and verify
        ${total_count}=    Set Variable    ${0}
        FOR    ${prefix}    ${expected_count}    IN    &{expected_prefix_counts}
            ${count}=    Count docs by key prefix    ${prefix}    bucket=${bucket}
            Should Be Equal As Integers    ${count}    ${expected_count}    msg=Prefix '${prefix}' in bucket '${bucket}' has wrong count
            ${total_count}=    Evaluate    ${total_count} + ${count}
        END
        Should Be Equal As Integers    ${total_count}    ${expected_total}    msg=Bucket '${bucket}' total count mismatch
    END

For Each Version And Repo
    [Arguments]    ${keyword}    @{args}
    [Documentation]    Iterate over all test versions and their repos, running the specified keyword
    ...                for each combination. The keyword receives version and repo as first two arguments,
    ...                followed by any additional args passed to this keyword.
    ${versions}=    Get test versions
    FOR    ${version}    IN    @{versions}
        ${expected_repos}=    Get version repos    ${version}
        FOR    ${repo}    IN    @{expected_repos}
            Setup test for version    ${version}
            Run Keyword    ${keyword}    ${version}    ${repo}    @{args}
        END
    END

Test info command for version and repo
    [Arguments]    ${version}    ${repo}
    Log    Testing info command for version: ${version}, repo: ${repo}    console=yes
    ${expected_backups}=    Get repo backups    ${version}    ${repo}

    ${result}=    Get cloud info as json    repo=${repo}
    Should Be Equal    ${result}[name]    ${repo}

    ${expected_num_backups}=    Get Length    ${expected_backups}
    Length Should Be    ${result}[backups]    ${expected_num_backups}
    FOR    ${backup_idx}    IN RANGE    ${expected_num_backups}
        ${expected_backup}=    Get From List    ${expected_backups}    ${backup_idx}
        Should Be Equal    ${result}[backups][${backup_idx}][type]    ${expected_backup}[type]
        FOR    ${bucket}    ${expected_bucket_data}    IN    &{expected_backup}[buckets]
            ${bucket_idx}=    Get bucket index from backups    ${result}    bucket=${bucket}    backup_idx=${backup_idx}
            Should Be Equal As Integers    ${result}[backups][${backup_idx}][buckets][${bucket_idx}][mutations]    ${expected_bucket_data}[mutations]
        END
    END

Test examine command for version and repo
    [Arguments]    ${version}    ${repo}
    Log    Testing examine command for version: ${version}, repo: ${repo}    console=yes
    ${result}=    Get cloud info as json    repo=${repo}
    ${expected_examine_key}=    Get examine key for version    ${version}    ${repo}
    ${expected_examine_bucket}=    Get examine bucket for version    ${version}    ${repo}

    ${doc}    ${output}=    Run cloud examine    key=${expected_examine_key}    repo=${repo}    collection_string=${expected_examine_bucket}
    Should Not Be Empty    ${output}

    ${found}=    Set Variable    ${FALSE}
    FOR    ${event}    IN    @{output}
        IF    ${event}[event_type] == 1
            Should Be Equal    ${event}[document][key]    ${expected_examine_key}
            Should Be Equal    ${event}[backup]    ${result}[backups][0][date]
            ${found}=    Set Variable    ${TRUE}
            Exit For Loop
        END
    END
    Should Be True    ${found}    msg=Document '${expected_examine_key}' not found in backup

Test restore first backup for version and repo
    [Arguments]    ${version}    ${repo}
    Log    Testing restore first backup for version: ${version}, repo: ${repo}    console=yes
    ${result}=    Get cloud info as json    repo=${repo}
    ${first_backup}=    Set Variable    ${result}[backups][0][date]
    ${expected_bucket_totals}=    Get backup bucket totals    ${version}    ${repo}    ${0}
    ${expected_buckets}=    Get all buckets for version    ${version}

    Run cloud restore    repo=${repo}    start=${first_backup}    end=${first_backup}

    Wait for all buckets to be persisted    ${expected_bucket_totals}
    Verify bucket counts by prefix    ${version}    ${repo}    ${expected_bucket_totals}    backup_idx=${0}

Test restore all backups for version and repo
    [Arguments]    ${version}    ${repo}
    Log    Testing restore all backups for version: ${version}, repo: ${repo}    console=yes
    ${expected_bucket_totals}=    Get final bucket totals    ${version}    ${repo}
    ${expected_buckets}=    Get all buckets for version    ${version}

    Run cloud restore    repo=${repo}

    Wait for all buckets to be persisted    ${expected_bucket_totals}
    Verify bucket counts by prefix    ${version}    ${repo}    ${expected_bucket_totals}

Test resume restore for version and repo
    [Arguments]    ${version}    ${repo}
    Log    Testing resume restore for version: ${version}, repo: ${repo}    console=yes
    ${expected_bucket_totals}=    Get final bucket totals    ${version}    ${repo}
    ${expected_buckets}=    Get all buckets for version    ${version}

    Run and terminate cloud restore    repo=${repo}    sleep_time=1
    Run cloud restore    repo=${repo}    resume=None

    Wait for all buckets to be persisted    ${expected_bucket_totals}
    Verify bucket counts by prefix    ${version}    ${repo}    ${expected_bucket_totals}

Test create backup for version and repo
    [Arguments]    ${version}    ${repo}
    Log    Testing create backup in legacy repo for version: ${version}, repo: ${repo}    console=yes
    ${expected_backups}=    Get repo backups    ${version}    ${repo}
    ${expected_num_backups}=    Get Length    ${expected_backups}
    ${expected_bucket_totals}=    Get final bucket totals    ${version}    ${repo}
    ${expected_buckets}=    Get all buckets for version    ${version}
    ${first_bucket}=    Get From List    ${expected_buckets}    0

    Run cloud restore    repo=${repo}
    Wait for all buckets to be persisted    ${expected_bucket_totals}

    Verify bucket counts by prefix    ${version}    ${repo}    ${expected_bucket_totals}
    Load documents into bucket using cbworkloadgen    items=100    bucket=${first_bucket}    key-pref=new

    Create cloud backup    repo=${repo}

    ${result}=    Get cloud info as json    repo=${repo}
    ${expected_total_backups}=    Evaluate    ${expected_num_backups} + 1
    Length Should Be    ${result}[backups]    ${expected_total_backups}
    ${new_backup_idx}=    Set Variable    ${expected_num_backups}
    ${bucket_idx}=    Get bucket index from backups    ${result}    bucket=${first_bucket}    backup_idx=${new_backup_idx}
    Should Be True    ${result}[backups][${new_backup_idx}][buckets][${bucket_idx}][mutations] >= 100

***Test Cases***
Test legacy info command
    [Documentation]    Verify info command returns correct backup information for legacy archives.
    [Tags]    Info
    For Each Version And Repo    Test info command for version and repo

Test legacy examine command
    [Documentation]    Verify examine command can retrieve documents from legacy archives.
    [Tags]    Examine
    For Each Version And Repo    Test examine command for version and repo

Test legacy restore first backup only
    [Documentation]    Verify restore can restore only the first (FULL) backup from legacy archives.
    [Tags]    Restore
    For Each Version And Repo    Test restore first backup for version and repo

Test legacy restore all backups
    [Documentation]    Verify restore can restore all backups from legacy archives.
    [Tags]    Restore
    For Each Version And Repo    Test restore all backups for version and repo

Test legacy resume interrupted restore
    [Documentation]    Verify restore can be resumed after interruption on legacy archives.
    [Tags]    Restore    Resume
    For Each Version And Repo    Test resume restore for version and repo

Test create new backup in legacy repo
    [Documentation]    Verify a new backup can be created in an existing legacy repository.
    [Tags]    Backup
    For Each Version And Repo    Test create backup for version and repo
