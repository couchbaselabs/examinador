*** Settings ***
Library    RequestsLibrary
Library    Process
Library    OperatingSystem
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${S3_ARCHIVE}

*** Variables ***
${BIN_PATH}              %{HOME}${/}source${/}install${/}bin
${S3_ARCHIVE}            s3://aws-buck/archive
${S3_ENDPOINT}           http://localhost:4566
${ACCESS_KEY_ID}         test
${SECRET_ACCESS_KEY}     test
${REGION}                us-east-1

*** Keywords ***
Create AWS S3 bucket if it does not exist cli
    [Arguments]    ${bucket}=aws-buck
    [Documentation]    Create an S3 bucket if it does not exist, using the aws-cli.
    ${resp}=    Run process    aws    s3api    head-bucket    --bucket    ${bucket}    --endpoint-url\=${S3_ENDPOINT}
    ...         shell=True
    Return from keyword if    ${resp.rc} == 0
    ${resp}=    Run process    aws    s3api    create-bucket    --bucket    ${bucket}    --endpoint-url\=${S3_ENDPOINT}
    ...         shell=True
    Log To Console    ${resp.stdout}     DEBUG
    Should be equal as integers    ${resp.rc}    0
    ${resp}=    Run process    aws    s3api    wait    bucket-exists    --bucket    ${bucket}
    ...         --endpoint-url\=${S3_ENDPOINT}    shell=True
    Should be equal as integers    ${resp.rc}    0

Remove AWS S3 bucket
    [Arguments]    ${bucket}=aws-buck
    [Documentation]    Remove an S3 bucket if it exists, using the aws-cli.
    ${resp}=    Run process    aws    s3api    head-bucket    --bucket    ${bucket}    --endpoint-url\=${S3_ENDPOINT}
    ...         shell=True
    Return from keyword if    ${resp.rc} != 0
    ${resp}=    Run process    aws    --endpoint-url\=${S3_ENDPOINT}    S3    rm    ${S3_ARCHIVE}    shell=True
    Log To Console    ${resp.stdout}     DEBUG
    ${resp}=    Run process    aws    --endpoint-url\=${S3_ENDPOINT}    S3    rb    S3://${bucket}    --force
    ...         shell=True
    Log To Console    ${resp.stdout}     DEBUG
    Should be equal as integers    ${resp.rc}    0
    ${resp}=    Run process    aws    s3api    wait    bucket-not-exists    --bucket    ${bucket}
    ...         --endpoint-url\=${S3_ENDPOINT}    shell=True
    Should be equal as integers    ${resp.rc}    0

Get cbriftdump data S3
    [Arguments]        ${dir}
    [Documentation]    Get the rift stores from the path specified by dir.
    ${result}=         Run Process    ${BIN_PATH}${/}cbriftdump    -d    ${dir}    --json
    ...                 --obj-region    ${REGION}    --obj-staging-dir    ${TEMP_DIR}${/}staging_rift
    ...                 --obj-access-key-id    ${ACCESS_KEY_ID}    --obj-secret-access-key    ${SECRET_ACCESS_KEY}
    ...                 --obj-endpoint    ${S3_ENDPOINT}    --S3-force-path-style
    ...                 stdout=${TEMPDIR}${/}stdout.txt     stderr=DEVNULL
    Should Be Equal As Integers    ${result.rc}    0
    ${result_list}=    Rift To List    ${result.stdout}
    Return from keyword    ${result_list}

Wait for localstack to start
    [Arguments]    ${bucket}=aws-buck    ${wait}=120
    [Documentation]    Remove an S3 bucket if it exists, using the aws-cli.
    FOR    ${i}    IN RANGE    ${wait}
        ${resp}=    Run process    aws    s3api    head-bucket    --bucket    ${bucket}    --endpoint-url\=${S3_ENDPOINT}
        ...         shell=True
        Return from keyword if    ${resp.rc} != 127
        Sleep    1
    END
    Fail    Failed to connect to Localstack in ${wait} seconds
