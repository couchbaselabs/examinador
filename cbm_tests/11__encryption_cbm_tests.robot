***Settings***
Documentation      This test suite tests that backup encryption works correctly
Force Tags         Encryption  Backup
Library            Process
Library            OperatingSystem
Library            Collections
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${ARCHIVE}
Library            ../libraries/sdk_utils.py
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource
Resource           ../resources/aws.resource

Suite setup        Run keywords    Delete bucket cli    bucket=default
...                AND    Delete bucket cli    bucket=encryptbucket
...                AND    Start minio
...                AND    Wait for minio to start
Suite Teardown     Run keywords    Remove Directory    ${TEMP_DIR}${/}data${/}backups    recursive=True
...                AND    Stop minio
Test Setup         Run keywords    Delete bucket cli    bucket=default
...                AND    Delete bucket cli    bucket=encryptbucket
Test Teardown      Run keywords    Delete bucket cli    bucket=default
...                AND    Delete bucket cli    bucket=encryptbucket
...                AND    Delete bucket cli    bucket=bucket1

***Variables***
${BIN_PATH}                      ${SOURCE}${/}install${/}bin
${ARCHIVE}                       ${TEMP_DIR}${/}data${/}backups
${PASSPHRASE}                    test-encryption-passphrase
${MORPHEUS_ENCRYPTED_ARCHIVE}    s3://cbm-integration-tests/morpheus-encrypted-archive.tar.gz
${CLOUD_ENDPOINT}                http://localhost:4566
${ACCESS_KEY_ID}                 test1234
${SECRET_ACCESS_KEY}             test1234
${REGION}                        us-east-1
${CLOUD_BUCKET}                  s3://aws-buck
${ARCHIVE_NAME}                  archive
${CLOUD_ARCHIVE}                 ${CLOUD_BUCKET}${/}${ARCHIVE_NAME}

***Test Cases***
Test encrypted backup does not contain plaintext bucket scope collection names
    [Tags]    P0    Encryption    Backup
    [Documentation]    Creates an encrypted backup using --passphrase and verifies that bucket,
    ...                scope, and collection names do not appear as plaintext in any backup file.
    Create CB bucket if it does not exist cli      bucket=encryptbucket
    Create CB scope if it does not exist cli       bucket=encryptbucket    scope=encryptscope
    Create collection if it does not exist cli     bucket=encryptbucket    scope=encryptscope
    ...                                            collection=encryptcoll
    Load documents into bucket using cbc           bucket=encryptbucket    scope=encryptscope
    ...                                            collection=encryptcoll
    Configure backup    repo=encrypted    passphrase=${PASSPHRASE}    encrypted=None
    Run backup          repo=encrypted    passphrase=${PASSPHRASE}
    ${result}=               Get info as json    repo=encrypted    passphrase=${PASSPHRASE}
    ${number_of_backups}=    Get Length    ${result}[backups]
    ${bucket_index}=         Get bucket index    ${result}    bucket=encryptbucket
    Should Be Equal                ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][name]
    ...                            encryptbucket
    ${backup_date}=    Set Variable    ${result}[backups][${number_of_backups-1}][date]
    ${backup_dir}=    Catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}encrypted${/}${backup_date}
    @{identifiers}=    Create List    encryptbucket    encryptscope    encryptcoll
    Scan backup files for plaintext identifiers    ${backup_dir}    ${identifiers}

Test restore encrypted backup
    [Tags]    P0    Encryption    Restore
    [Documentation]    Creates an encrypted backup using --passphrase, flushes the bucket,
    ...                restores it, and verifies documents are recovered successfully.
    Create CB bucket if it does not exist cli      bucket=encryptbucket
    Create CB scope if it does not exist cli       bucket=encryptbucket    scope=encryptscope
    Create collection if it does not exist cli     bucket=encryptbucket    scope=encryptscope
    ...                                            collection=encryptcoll
    Load documents into bucket using cbc           bucket=encryptbucket    scope=encryptscope
    ...                                            collection=encryptcoll
    Configure backup    repo=encrypted_restore    passphrase=${PASSPHRASE}    encrypted=None
    Run backup          repo=encrypted_restore    passphrase=${PASSPHRASE}
    Flush bucket REST    bucket=encryptbucket
    Run restore and wait until persisted    repo=encrypted_restore    bucket=encryptbucket
    ...                                     items=10    passphrase=${PASSPHRASE}

Test restore encrypted morpheus repo
    [Tags]    P0    Encryption    Restore    S3
    [Documentation]    Downloads a zipped encrypted morpheus archive from S3, extracts it, runs info to verify
    ...                2000 documents in bucket1, runs restore and verifies document recovery.
    ${tarball}=    Set Variable    ${TEMPDIR}${/}test_repo.tar.gz
    ${download_cmd}=    Create List    aws    s3    cp    ${MORPHEUS_ENCRYPTED_ARCHIVE}    ${tarball}
    ...                 --no-sign-request
    Run and log and check process    ${download_cmd}    shell=True
    ${extract_cmd}=    Create List    tar    -xzf    ${tarball}    -C    ${ARCHIVE}
    Run and log and check process    ${extract_cmd}    shell=True
    Remove File    ${tarball}
    ${result}=               Get info as json    repo=test_repo    passphrase=${PASSPHRASE}
    ${number_of_backups}=    Get Length    ${result}[backups]
    ${bucket_index}=         Get bucket index    ${result}    bucket=bucket1
    Should Be Equal                ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][name]
    ...                            bucket1
    Should Be Equal As Integers    ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][mutations]
    ...                            2000
    Run restore and wait until persisted    repo=test_repo    bucket=bucket1    items=2000
    ...                                    passphrase=${PASSPHRASE}    auto-create-buckets=None
    [Teardown]    Run keywords    Delete bucket cli    bucket=bucket1
    ...           AND    Remove Directory    ${ARCHIVE}${/}test_repo    recursive=True

Test encrypted backup to cloud then info and restore
    [Tags]    P0    Encryption    Backup    Restore    S3
    [Documentation]    Creates a cloud repo with encryption, runs backup to S3, verifies info output,
    ...                restores and checks documents are recovered successfully.
    Create AWS S3 bucket if it does not exist cli
    Create CB bucket if it does not exist cli      bucket=encryptbucket
    Load documents into bucket using cbworkloadgen    items=1024    bucket=encryptbucket
    Create cloud repo    repo=encrypted_cloud    passphrase=${PASSPHRASE}    encrypted=None
    Create cloud backup    repo=encrypted_cloud    passphrase=${PASSPHRASE}
    ${result}=    Get cloud info as json    repo=encrypted_cloud    passphrase=${PASSPHRASE}
    ${number_of_backups}=    Get Length    ${result}[backups]
    ${bucket_index}=    Get bucket index    ${result}    bucket=encryptbucket
    Should Be Equal    ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][name]
    ...                encryptbucket
    Should Be Equal As Integers    ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][mutations]
    ...                1024
    Flush bucket REST    bucket=encryptbucket
    Run cloud restore and wait until persisted    repo=encrypted_cloud    bucket=encryptbucket
    ...    items=1024    passphrase=${PASSPHRASE}
    [Teardown]    Run keywords    Delete bucket cli    bucket=encryptbucket
    ...           AND    Run cloud remove    repo=encrypted_cloud    passphrase=${PASSPHRASE}
    ...           AND    Remove AWS S3 bucket
    ...           AND    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True

Test encrypted cloud backup does not contain plaintext bucket scope collection names
    [Tags]    P0    Encryption    Backup    S3
    [Documentation]    Creates an encrypted cloud backup and then downloads the archive from S3 to
    ...                verify that bucket, scope, and collection names do not appear as plaintext.
    Create AWS S3 bucket if it does not exist cli
    Create CB bucket if it does not exist cli      bucket=encryptbucket
    Create CB scope if it does not exist cli       bucket=encryptbucket    scope=encryptscope
    Create collection if it does not exist cli     bucket=encryptbucket    scope=encryptscope
    ...                                            collection=encryptcoll
    Load documents into bucket using cbc           bucket=encryptbucket    scope=encryptscope
    ...                                            collection=encryptcoll
    Create cloud repo    repo=encrypted_cloud_scan    passphrase=${PASSPHRASE}    encrypted=None
    Create cloud backup    repo=encrypted_cloud_scan    passphrase=${PASSPHRASE}
    ${result}=    Get cloud info as json    repo=encrypted_cloud_scan    passphrase=${PASSPHRASE}
    ${number_of_backups}=    Get Length    ${result}[backups]
    ${bucket_index}=    Get bucket index    ${result}    bucket=encryptbucket
    Should Be Equal    ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][name]
    ...                encryptbucket
    ${backup_date}=    Set Variable    ${result}[backups][${number_of_backups-1}][date]
    ${local_dir}=    Set Variable    ${TEMPDIR}${/}cloud_backup_scan
    Set Test Variable    ${LOCAL_DIR}    ${local_dir}
    ${download_cmd}=    Create List    aws    s3    sync
    ...    ${CLOUD_BUCKET}${/}${ARCHIVE_NAME}${/}encrypted_cloud_scan${/}${backup_date}
    ...    ${local_dir}${/}encrypted_cloud_scan${/}${backup_date}
    ...    --endpoint-url\=${CLOUD_ENDPOINT}
    Run and log and check process    ${download_cmd}    shell=True
    @{identifiers}=    Create List    encryptbucket    encryptscope    encryptcoll
    Scan backup files for plaintext identifiers
    ...    ${local_dir}${/}encrypted_cloud_scan${/}${backup_date}    ${identifiers}
    [Teardown]    Run keywords    Delete bucket cli    bucket=encryptbucket
    ...           AND    Run cloud remove    repo=encrypted_cloud_scan    passphrase=${PASSPHRASE}
    ...           AND    Remove AWS S3 bucket
    ...           AND    Remove Directory    ${LOCAL_DIR}    recursive=True
    ...           AND    Remove Directory    ${TEMP_DIR}${/}staging    recursive=True
