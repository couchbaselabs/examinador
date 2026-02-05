*** Settings ***
Library     RequestsLibrary
Library     Process
Library     OperatingSystem
Library     Collections
Library     ../libraries/setup_utils.py
Resource    ../resources/couchbase.resource
Resource    ../resources/common.resource
Resource    ../resources/cbm.resource

***Variables***
${MINIO_DIR}             ${TEMP_DIR}${/}minio_data

*** Keywords ***
Create AWS S3 bucket if it does not exist cli
    [Arguments]    ${bucket}=aws-buck    ${object_lock}=${FALSE}
    [Documentation]    Create an S3 bucket if it does not exist, using the aws-cli.
    ...                If object_lock is True, creates the bucket with object lock enabled.
    ${command}=    Create List    aws    s3api    head-bucket    --bucket    ${bucket}
    ...    --endpoint-url\=${CLOUD_ENDPOINT}
    ${result}=    Run and log process    ${command}    shell=True
    Return from keyword if    ${result.rc} == 0
    ${command}=    Create List    aws    s3api    create-bucket    --bucket    ${bucket}
    ...            --endpoint-url\=${CLOUD_ENDPOINT}
    IF    ${object_lock}
        Append To List    ${command}    --object-lock-enabled-for-bucket
    END
    Run and log and check process    ${command}    shell=True
    ${command}=    Create List    aws    s3api    wait    bucket-exists    --bucket    ${bucket}
    ...            --endpoint-url\=${CLOUD_ENDPOINT}
    Run and log and check process    ${command}    shell=True

Remove AWS S3 bucket
    [Arguments]    ${bucket}=aws-buck
    [Documentation]    Remove an S3 bucket if it exists, using the aws-cli.
    ${command}=    Create List    aws    s3api    head-bucket    --bucket    ${bucket}
    ...    --endpoint-url\=${CLOUD_ENDPOINT}
    ${result}=    Run and log process    ${command}    shell=True
    Return from keyword if    ${result.rc} != 0
    ${command}=    Create List    aws    --endpoint-url\=${CLOUD_ENDPOINT}    s3    rm    ${CLOUD_ARCHIVE}
    Run and log and check process    ${command}    shell=True
    ${command}=    Create List    aws    --endpoint-url\=${CLOUD_ENDPOINT}    s3    rb    s3://${bucket}    --force
    Run and log and check process    ${command}    shell=True
    ${command}=    Create List    aws    s3api    wait    bucket-not-exists    --bucket    ${bucket}
    ...            --endpoint-url\=${CLOUD_ENDPOINT}
    Run and log and check process    ${command}    shell=True

Get cloud cbriftdump data
    [Arguments]        ${backup_name}    ${bucket_name}=default    ${cloud_bucket}=${CLOUD_BUCKET}    ${archive_name}=${ARCHIVE_NAME}
    ...                ${repo}=cloud_repo    ${local_dir}=${TEMP_DIR}${/}staging
    ...                ${obj_region}=${REGION}    ${obj_access_key_id}=${ACCESS_KEY_ID}    ${obj_secret_access_key}=${SECRET_ACCESS_KEY}
    ...                ${obj_endpoint}=${CLOUD_ENDPOINT}
    [Documentation]    Get the rift stores from the path specified by dir.
    ${bucket_uuid}=    Get bucket uuid from plan    backup_name=${backup_name}    bucket_name=${bucket_name}
    ...                cloud_bucket=${cloud_bucket}    archive_name=${archive_name}    repo=${repo}
    ...                obj_region=${obj_region}    obj_access_key_id=${obj_access_key_id}
    ...                obj_secret_access_key=${obj_secret_access_key}    obj_endpoint=${obj_endpoint}
    ${command}=    Create List    ${BIN_PATH}${/}cbriftdump    -d
    ...            ${cloud_bucket}${/}${archive_name}${/}${repo}${/}${backup_name}${/}${bucket_name}-${bucket_uuid}${/}data    --json
    ...            --obj-region    ${obj_region}    --obj-staging-dir    ${local_dir}${/}staging_rift
    ...            --obj-access-key-id    ${obj_access_key_id}    --obj-secret-access-key    ${obj_secret_access_key}
    ...            --obj-endpoint    ${obj_endpoint}    --s3-force-path-style
    ${result}=    Run and log and check process    ${command}    stdout=${TEMPDIR}${/}stdout.txt    stderr=DEVNULL
    ${result_list}=    Rift To List    ${result.stdout}
    Return from keyword    ${result_list}

Wait for minio to start
    [Arguments]    ${bucket}=aws-buck    ${wait}=120
    [Documentation]    Remove an S3 bucket if it exists, using the aws-cli.
    FOR    ${i}    IN RANGE    ${wait}
        ${result}=    Run Process    aws    s3api    head-bucket    --bucket    ${bucket}
        ...            --endpoint-url\=${CLOUD_ENDPOINT}
        Log    ${result.stdout}
        Return from keyword if    ${result.rc} != 127
        Sleep    1
    END
    Fail    Failed to connect to minio in ${wait} seconds

Start minio
    [Documentation]    Start minio
    Set Environment Variable    MINIO_ROOT_USER    test1234
    Set Environment Variable    MINIO_ROOT_PASSWORD    test1234
    Remove Directory    ${MINIO_DIR}    recursive=True
    Start Process    minio     server    ${MINIO_DIR}   --address    :4566    alias=minio    stdout=DEVNULL    stderr=DEVNULL
    Set Environment Variable    AWS_ACCESS_KEY_ID    test1234
    Set Environment Variable    AWS_SECRET_ACCESS_KEY    test1234
    Set Environment Variable    AWS_DEFAULT_REGION    us-east-1

Stop minio
    [Documentation]      Stop minio
    Log                  Stopping minio
    Terminate process    minio    kill=true
    Remove Directory    ${MINIO_DIR}    recursive=True

Create cloud backup
    [Arguments]        ${cloud_bucket}=${CLOUD_BUCKET}    ${archive_name}=${ARCHIVE_NAME}    ${repo}=cloud_repo
    ...                ${timeout_value}=300    ${local_dir}=${TEMP_DIR}${/}staging    ${obj_region}=${REGION}
    ...                ${obj_access_key_id}=${ACCESS_KEY_ID}    ${obj_secret_access_key}=${SECRET_ACCESS_KEY}
    ...                ${obj_endpoint}=${CLOUD_ENDPOINT}    ${s3_force_path_style}=None    &{kwargs}
    [Documentation]    Create a cloud backup.
    Run backup         archive=${cloud_bucket}${/}${archive_name}    repo=${repo}    timeout_value=${timeout_value}
    ...                obj-staging-dir=${local_dir}${/}${archive_name}    obj-region=${obj_region}
    ...                obj-access-key-id=${obj_access_key_id}    obj-secret-access-key=${obj_secret_access_key}
    ...                obj-endpoint=${obj_endpoint}    s3-force-path-style=${s3_force_path_style}    &{kwargs}

Create cloud repo
    [Arguments]        ${cloud_bucket}=${CLOUD_BUCKET}    ${archive_name}=${ARCHIVE_NAME}    ${repo}=cloud_repo
    ...                ${timeout_value}=300    ${local_dir}=${TEMP_DIR}${/}staging    ${obj_region}=${REGION}
    ...                ${obj_access_key_id}=${ACCESS_KEY_ID}    ${obj_secret_access_key}=${SECRET_ACCESS_KEY}
    ...                ${obj_endpoint}=${CLOUD_ENDPOINT}    ${s3_force_path_style}=None    &{kwargs}
    [Documentation]     Create a cloud repo.
    Configure backup   archive=${cloud_bucket}${/}${archive_name}    repo=${repo}    timeout_value=${timeout_value}
    ...                obj-staging-dir=${local_dir}${/}${archive_name}    obj-region=${obj_region}
    ...                obj-access-key-id=${obj_access_key_id}    obj-secret-access-key=${obj_secret_access_key}
    ...                obj-endpoint=${obj_endpoint}    s3-force-path-style=${s3_force_path_style}    &{kwargs}

Get cloud info as json
    [Arguments]        ${cloud_bucket}=${CLOUD_BUCKET}    ${archive_name}=${ARCHIVE_NAME}    ${repo}=cloud_repo
    ...                ${timeout_value}=300    ${local_dir}=${TEMP_DIR}${/}staging    ${obj_region}=${REGION}
    ...                ${obj_access_key_id}=${ACCESS_KEY_ID}    ${obj_secret_access_key}=${SECRET_ACCESS_KEY}
    ...                ${obj_endpoint}=${CLOUD_ENDPOINT}    ${s3_force_path_style}=None    &{kwargs}
    [Documentation]    Get cloud info as json.
    ${result}=         Get info as json   archive=${cloud_bucket}${/}${archive_name}    repo=${repo}
    ...                timeout_value=${timeout_value}    obj-staging-dir=${local_dir}${/}${archive_name}
    ...                obj-region=${obj_region}    obj-access-key-id=${obj_access_key_id}
    ...                obj-secret-access-key=${obj_secret_access_key}    obj-endpoint=${obj_endpoint}
    ...                s3-force-path-style=${s3_force_path_style}    &{kwargs}
    Return from keyword    ${result}

Run cloud remove
    [Arguments]        ${cloud_bucket}=${CLOUD_BUCKET}    ${archive_name}=${ARCHIVE_NAME}    ${repo}=cloud_repo
    ...                ${timeout_value}=300    ${local_dir}=${TEMP_DIR}${/}staging    ${obj_region}=${REGION}
    ...                ${obj_access_key_id}=${ACCESS_KEY_ID}    ${obj_secret_access_key}=${SECRET_ACCESS_KEY}
    ...                ${obj_endpoint}=${CLOUD_ENDPOINT}    ${s3_force_path_style}=None    &{kwargs}
    [Documentation]    Run remove on a cloud backup repository.
    Run remove         archive=${cloud_bucket}${/}${archive_name}    repo=${repo}    timeout_value=${timeout_value}
    ...                obj-staging-dir=${local_dir}${/}${archive_name}    obj-region=${obj_region}
    ...                obj-access-key-id=${obj_access_key_id}    obj-secret-access-key=${obj_secret_access_key}
    ...                obj-endpoint=${obj_endpoint}    s3-force-path-style=${s3_force_path_style}    &{kwargs}

Run and terminate cloud backup
    [Arguments]        ${cloud_bucket}=${CLOUD_BUCKET}    ${archive_name}=${ARCHIVE_NAME}    ${repo}=cloud_repo
    ...                ${local_dir}=${TEMP_DIR}${/}staging    ${obj_region}=${REGION}
    ...                ${obj_access_key_id}=${ACCESS_KEY_ID}    ${obj_secret_access_key}=${SECRET_ACCESS_KEY}
    ...                ${obj_endpoint}=${CLOUD_ENDPOINT}    ${s3_force_path_style}=None    &{kwargs}
    [Documentation]    Run and terminate a cloud backup (for resume testing).
    Run and terminate backup    archive=${cloud_bucket}${/}${archive_name}    repo=${repo}
    ...                obj-staging-dir=${local_dir}${/}${archive_name}    obj-region=${obj_region}
    ...                obj-access-key-id=${obj_access_key_id}    obj-secret-access-key=${obj_secret_access_key}
    ...                obj-endpoint=${obj_endpoint}    s3-force-path-style=${s3_force_path_style}    &{kwargs}

Run cloud examine
    [Arguments]        ${key}    ${cloud_bucket}=${CLOUD_BUCKET}    ${archive_name}=${ARCHIVE_NAME}    ${repo}=cloud_repo
    ...                ${timeout_value}=120    ${local_dir}=${TEMP_DIR}${/}staging    ${obj_region}=${REGION}
    ...                ${obj_access_key_id}=${ACCESS_KEY_ID}    ${obj_secret_access_key}=${SECRET_ACCESS_KEY}
    ...                ${obj_endpoint}=${CLOUD_ENDPOINT}    ${s3_force_path_style}=None    &{kwargs}
    [Documentation]    Run examine on a cloud backup repository.
    ${doc}    ${output}=    Run examine    key=${key}    archive=${cloud_bucket}${/}${archive_name}    repo=${repo}
    ...                timeout_value=${timeout_value}    obj-staging-dir=${local_dir}${/}${archive_name}
    ...                obj-region=${obj_region}    obj-access-key-id=${obj_access_key_id}
    ...                obj-secret-access-key=${obj_secret_access_key}    obj-endpoint=${obj_endpoint}
    ...                s3-force-path-style=${s3_force_path_style}    json=None    &{kwargs}
    Return from keyword    ${doc}    ${output}

Run cloud restore and wait until persisted
    [Arguments]        ${cloud_bucket}=${CLOUD_BUCKET}    ${archive_name}=${ARCHIVE_NAME}    ${repo}=cloud_repo
    ...                ${bucket}=default    ${host}=http://localhost:9000    ${user}=Administrator
    ...                ${password}=asdasd    ${timeout_value}=300    ${items}=2048
    ...                ${local_dir}=${TEMP_DIR}${/}staging    ${obj_region}=${REGION}
    ...                ${obj_access_key_id}=${ACCESS_KEY_ID}    ${obj_secret_access_key}=${SECRET_ACCESS_KEY}
    ...                ${obj_endpoint}=${CLOUD_ENDPOINT}    ${s3_force_path_style}=None
    ...                ${users}=False    &{kwargs}
    [Documentation]    Run restore on a cloud backup repository and wait until persisted.
    Run restore and wait until persisted    repo=${repo}    archive=${cloud_bucket}${/}${archive_name}
    ...                bucket=${bucket}    host=${host}    user=${user}    password=${password}
    ...                timeout_value=${timeout_value}    items=${items}    users=${users}
    ...                obj-staging-dir=${local_dir}${/}${archive_name}    obj-region=${obj_region}
    ...                obj-access-key-id=${obj_access_key_id}    obj-secret-access-key=${obj_secret_access_key}
    ...                obj-endpoint=${obj_endpoint}    s3-force-path-style=${s3_force_path_style}    &{kwargs}

Run cloud restore
    [Arguments]        ${cloud_bucket}=${CLOUD_BUCKET}    ${archive_name}=${ARCHIVE_NAME}    ${repo}=cloud_repo
    ...                ${local_dir}=${TEMP_DIR}${/}staging    ${obj_region}=${REGION}
    ...                ${obj_access_key_id}=${ACCESS_KEY_ID}    ${obj_secret_access_key}=${SECRET_ACCESS_KEY}
    ...                ${obj_endpoint}=${CLOUD_ENDPOINT}    ${s3_force_path_style}=None
    ...                ${include_data}=${EMPTY}    &{kwargs}
    [Documentation]    Run cloud restore without waiting for items to be persisted.
    Restore docs    archive=${cloud_bucket}${/}${archive_name}    repo=${repo}
    ...             obj-staging-dir=${local_dir}${/}${archive_name}    obj-region=${obj_region}
    ...             obj-access-key-id=${obj_access_key_id}    obj-secret-access-key=${obj_secret_access_key}
    ...             obj-endpoint=${obj_endpoint}    s3-force-path-style=${s3_force_path_style}    &{kwargs}

Run and terminate cloud restore
    [Arguments]        ${cloud_bucket}=${CLOUD_BUCKET}    ${archive_name}=${ARCHIVE_NAME}    ${repo}=cloud_repo
    ...                ${local_dir}=${TEMP_DIR}${/}staging    ${obj_region}=${REGION}
    ...                ${obj_access_key_id}=${ACCESS_KEY_ID}    ${obj_secret_access_key}=${SECRET_ACCESS_KEY}
    ...                ${obj_endpoint}=${CLOUD_ENDPOINT}    ${s3_force_path_style}=None
    ...                ${sleep_time}=1    &{kwargs}
    [Documentation]    Run and terminate a cloud restore (for resume testing).
    Run and terminate restore    archive=${cloud_bucket}${/}${archive_name}    repo=${repo}
    ...                obj-staging-dir=${local_dir}${/}${archive_name}    obj-region=${obj_region}
    ...                obj-access-key-id=${obj_access_key_id}    obj-secret-access-key=${obj_secret_access_key}
    ...                obj-endpoint=${obj_endpoint}    s3-force-path-style=${s3_force_path_style}
    ...                sleep_time=${sleep_time}    &{kwargs}