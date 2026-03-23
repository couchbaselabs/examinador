***Settings***
Documentation      Test backwards compatibility with backup archives created with old versions of cbbackupmgr.
...                This suite verifies that info, examine, and restore operations can be performed
...                on old archives.
Force tags         BackwardsCompatibility
Library            OperatingSystem
Library            Collections
Library            Process
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${ARCHIVE}
Library            ../libraries/sdk_utils.py
Library            ../libraries/local_backwards_compatibility.py
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource

Suite setup        Download legacy archives from S3
Suite Teardown     Run keywords
...                    Remove Directory    ${LOCAL_LEGACY_ARCHIVES}    recursive=True    AND
...                    Remove Directory    ${ARCHIVE}    recursive=True


***Variables***
${BIN_PATH}                   ${SOURCE}${/}install${/}bin
${ARCHIVE}                    ${TEMP_DIR}${/}backups
${LOCAL_LEGACY_ARCHIVES}      ${TEMP_DIR}${/}legacy-archives
${REMOTE_S3_BUCKET}           s3://cbm-integration-tests
${TARBALL_PATH}               backwards_compatibility
${TARBALL_NAME}               all-versions-local.tar.gz


***Keywords***
Download legacy archives from S3
    [Documentation]    Download all legacy backup archives from the remote S3 bucket.
    ...                Downloads an archive containing version directories (e.g., v6.5.2)
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

Setup test for version
    [Arguments]    ${version}
    [Documentation]    Setup a test for a specific legacy version.
    ...                Cleans up previous state and copies the version's archive to the backup directory.
    Remove Directory    ${ARCHIVE}    recursive=True
    ${buckets}=    Get all buckets for version    ${version}
    FOR    ${bucket}    IN    @{buckets}
        Delete all buckets cli
    END
    FOR    ${bucket}    IN    @{buckets}
        Create CB bucket if it does not exist cli    bucket=${bucket}    ramQuota=100
    END
    Copy legacy archive to backup dir    ${version}

Copy legacy archive to backup dir
    [Arguments]    ${version}
    [Documentation]    Copy the legacy archive for the specified version to the backup directory.
    ...                The tarball extracts to version directories containing the archive structure (repos).
    ${command}=    Create List    cp    -r
    ...            ${LOCAL_LEGACY_ARCHIVES}${/}${version}${/}.
    ...            ${ARCHIVE}
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

For Each Version And Complete Repo
    [Arguments]    ${keyword}    @{args}
    [Documentation]    Iterate over all test versions and their complete repos, running the specified keyword
    ...                for each combination. Only repos with complete=True are included.
    ...                The keyword receives version and repo as first two arguments,
    ...                followed by any additional args passed to this keyword.
    ${versions}=    Get test versions
    FOR    ${version}    IN    @{versions}
        ${expected_repos}=    Get version repos by complete status    ${version}    complete=${TRUE}
        FOR    ${repo}    IN    @{expected_repos}
            Setup test for version    ${version}
            Run Keyword    ${keyword}    ${version}    ${repo}    @{args}
        END
    END

For Each Version And Incomplete Repo
    [Arguments]    ${keyword}    @{args}
    [Documentation]    Iterate over all test versions and their incomplete repos, running the specified keyword
    ...                for each combination. Only repos with complete=False are included.
    ...                The keyword receives version and repo as first two arguments,
    ...                followed by any additional args passed to this keyword.
    ${versions}=    Get test versions
    FOR    ${version}    IN    @{versions}
        ${expected_repos}=    Get version repos by complete status    ${version}    complete=${FALSE}
        FOR    ${repo}    IN    @{expected_repos}
            Setup test for version    ${version}
            Run Keyword    ${keyword}    ${version}    ${repo}    @{args}
        END
    END

Test info command for version and repo
    [Arguments]    ${version}    ${repo}
    Log    Testing info command for version: ${version}, repo: ${repo}    console=yes
    ${expected_backups}=    Get repo backups    ${version}    ${repo}

    ${result}=    Get info as json    repo=${repo}
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
    ${result}=    Get info as json    repo=${repo}
    ${expected_examine_key}=    Get examine key for version    ${version}    ${repo}
    ${expected_examine_bucket}=    Get examine bucket for version    ${version}    ${repo}

    ${doc}    ${output}=    Run examine    key=${expected_examine_key}    repo=${repo}    collection_string=${expected_examine_bucket}    json=None
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
    ${result}=    Get info as json    repo=${repo}
    ${first_backup}=    Set Variable    ${result}[backups][0][date]
    ${expected_bucket_totals}=    Get backup bucket totals    ${version}    ${repo}    ${0}
    ${expected_buckets}=    Get all buckets for version    ${version}

    Restore docs    repo=${repo}    start=${first_backup}    end=${first_backup}

    Wait for all buckets to be persisted    ${expected_bucket_totals}
    Verify bucket counts by prefix    ${version}    ${repo}    ${expected_bucket_totals}    backup_idx=${0}

Test restore all backups for version and repo
    [Arguments]    ${version}    ${repo}
    Log    Testing restore all backups for version: ${version}, repo: ${repo}    console=yes
    ${expected_bucket_totals}=    Get final bucket totals    ${version}    ${repo}
    ${expected_buckets}=    Get all buckets for version    ${version}

    Restore docs    repo=${repo}

    Wait for all buckets to be persisted    ${expected_bucket_totals}
    Verify bucket counts by prefix    ${version}    ${repo}    ${expected_bucket_totals}

Test resume restore for version and repo
    [Arguments]    ${version}    ${repo}
    Log    Testing resume restore for version: ${version}, repo: ${repo}    console=yes
    ${expected_bucket_totals}=    Get final bucket totals    ${version}    ${repo}
    ${expected_buckets}=    Get all buckets for version    ${version}

    Run and terminate restore    repo=${repo}    sleep_time=1
    Restore docs    repo=${repo}    resume=None

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

    Restore docs    repo=${repo}
    Wait for all buckets to be persisted    ${expected_bucket_totals}

    Verify bucket counts by prefix    ${version}    ${repo}    ${expected_bucket_totals}
    Load documents into bucket using cbworkloadgen    items=100    bucket=${first_bucket}    key-pref=new

    Run backup    repo=${repo}

    ${result}=    Get info as json    repo=${repo}
    ${expected_total_backups}=    Evaluate    ${expected_num_backups} + 1
    Length Should Be    ${result}[backups]    ${expected_total_backups}
    ${new_backup_idx}=    Set Variable    ${expected_num_backups}
    ${bucket_idx}=    Get bucket index from backups    ${result}    bucket=${first_bucket}    backup_idx=${new_backup_idx}
    Should Be True    ${result}[backups][${new_backup_idx}][buckets][${bucket_idx}][mutations] >= 100

Test info command for incomplete backup
    [Arguments]    ${version}    ${repo}
    Log    Testing info command for incomplete backup: version: ${version}, repo: ${repo}    console=yes
    ${expected_backups}=    Get repo backups    ${version}    ${repo}

    ${result}=    Get info as json    repo=${repo}
    Should Be Equal    ${result}[name]    ${repo}

    ${expected_num_backups}=    Get Length    ${expected_backups}
    Length Should Be    ${result}[backups]    ${expected_num_backups}
    FOR    ${backup_idx}    IN RANGE    ${expected_num_backups}
        ${expected_backup}=    Get From List    ${expected_backups}    ${backup_idx}
        Should Be Equal    ${result}[backups][${backup_idx}][type]    ${expected_backup}[type]
        ${expected_complete}=    Set Variable If    "complete" in ${expected_backup}    ${expected_backup}[complete]    ${TRUE}
        Should Be Equal    ${result}[backups][${backup_idx}][complete]    ${expected_complete}    msg=Backup ${backup_idx} complete status mismatch
    END

***Test Cases***
Test legacy repo info command
    [Documentation]    Verify info command returns correct backup information for legacy archives.
    [Tags]    Info
    For Each Version And Complete Repo    Test info command for version and repo

Test legacy repo info command for incomplete backup
    [Documentation]    Verify info command returns correct backup information for legacy archives with incomplete backups.
    [Tags]    Info    Incomplete
    For Each Version And Incomplete Repo    Test info command for incomplete backup

Test legacy repo examine command
    [Documentation]    Verify examine command can retrieve documents from legacy archives.
    [Tags]    Examine
    For Each Version And Complete Repo    Test examine command for version and repo

Test legacy repo restore first backup only
    [Documentation]    Verify restore can restore only the first (FULL) backup from legacy archives.
    [Tags]    Restore
    For Each Version And Complete Repo    Test restore first backup for version and repo

Test legacy repo restore all backups
    [Documentation]    Verify restore can restore all backups from legacy archives.
    [Tags]    Restore
    For Each Version And Complete Repo    Test restore all backups for version and repo

Test legacy repo resume interrupted restore
    [Documentation]    Verify restore can be resumed after interruption on legacy archives.
    [Tags]    Restore    Resume
    For Each Version And Complete Repo    Test resume restore for version and repo

Test create new backup in legacy repo
    [Documentation]    Verify a new backup can be created in an existing legacy repository.
    [Tags]    Backup
    For Each Version And Complete Repo    Test create backup for version and repo
