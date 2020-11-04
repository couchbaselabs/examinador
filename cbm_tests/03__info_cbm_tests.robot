***Settings***
Documentation      These test that correct info can be returned about the backups.
Force tags         Tier1
Library            Process
Library            OperatingSystem
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource


Suite Teardown     Remove Directory    ${TEMP_DIR}${/}data${/}backups    recursive=True


***Test Cases***
Test simple info per repo
    [Tags]    P0    Info
    [Documentation]    Configure multiple repos then use info command to confirm you get an empty entry per repo.
    FOR    ${i}    IN RANGE    10
        Configure backup    repo=repo${i}
        ${result}=     Get info as json    repo=repo${i}
        Should be Equal    ${result}[name]    repo${i}
        Should Be Empty    ${result}[backups]
    END

Test advanced info per repo
    [Tags]    P0    Info
    [Documentation]    Configure multiple repos then use info command to confirm you get an empty entry per repo.
    Delete bucket cli
    Delete bucket cli                                 bucket=new_bucket
    Create CB bucket if it does not exist cli         bucket=buck1
    Create CB bucket if it does not exist cli         bucket=buck2
    Load documents into bucket using cbworkloadgen    bucket=buck1
    Load documents into bucket using cbworkloadgen    bucket=buck2
    Configure backup                                  repo=simple
    Run backup                                        repo=simple
    Load documents into bucket using cbworkloadgen    bucket=buck1
    Load documents into bucket using cbworkloadgen    bucket=buck2
    Run backup                                        repo=simple
    Run backup                                        repo=simple
    ${result}=    Get info as json                    repo=simple
    Length should be               ${result}[backups]                                    3
    Should Be Equal as integers    ${result}[backups][0][buckets][0][mutations]          2048
    Should Be Equal as integers    ${result}[backups][0][buckets][1][mutations]          2048
    Should Be Equal as integers    ${result}[backups][1][buckets][0][mutations]          2048
    Should Be Equal as integers    ${result}[backups][1][buckets][1][mutations]          2048
    Should Be Equal as integers    ${result}[backups][2][buckets][0][mutations]          0
    Should Be Equal as integers    ${result}[backups][2][buckets][1][mutations]          0
    ${bucket_uuid}=    Get bucket uuid    bucket=buck1
    ${dir}=    catenate    SEPARATOR=
    ...    ${TEMP_DIR}${/}data${/}backups${/}simple${/}${result}[backups][0][date]
    ...    ${/}buck1-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Check cbworkloadgen rift contents    ${data}    expected_len_json=2048    size=1024
    ${dir}=    catenate    SEPARATOR=
    ...    ${TEMP_DIR}${/}data${/}backups${/}simple${/}${result}[backups][1][date]
    ...    ${/}buck1-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Check cbworkloadgen rift contents    ${data}    expected_len_json=2048    size=1024
