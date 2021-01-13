***Settings***
Documentation      These test that backup and restore operations that require multiple buckets can be performed.
Force tags         Tier1
Library            Process
Library            OperatingSystem
Library            Collections
Library            ../libraries/sdk_utils.py
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource

Suite setup        Run keywords    Delete bucket cli
...                AND    Delete bucket cli    bucket=new_bucket
Suite Teardown     Collect backup logs and remove archive

***Variables***
${ARCHIVE}         ${TEMP_DIR}${/}data${/}backups

***Test Cases***
Test include bucket backup
    [Tags]    P0    Backup
    [Documentation]    This tests that when the --include-data flag is used, only the data from the specified
    ...                bucket is backed up by creating two buckets and only including one with the flag and
    ...                checking only that bucket is backed up.
    Create CB bucket if it does not exist cli         bucket=buck1
    Load documents into bucket using cbworkloadgen    bucket=buck1
    Create CB bucket if it does not exist cli         bucket=buck2
    Load documents into bucket using cbworkloadgen    bucket=buck2
    Configure backup                  repo=include_buck2    include-data=buck2
    Run backup                        repo=include_buck2
    ${result}=    Get info as json    repo=include_buck2
    ${number_of_backups}=    Get Length    ${result}[backups]
    Length should be       ${result}[backups][${number_of_backups-1}][buckets]             1
    Should be equal        ${result}[backups][${number_of_backups-1}][buckets][0][name]    buck2
    ${bucket_uuid}=    Get bucket uuid    bucket=buck2
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}include_buck2${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}buck2-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Check cbworkloadgen rift contents    ${data}    expected_len_json=2048    size=1024

Test exclude bucket backup
    [Tags]    P0    Backup
    [Documentation]    This tests that when the --exclude-data flag is used, data from the specified bucket
    ...                is not backed up by creating two buckets and only including one with the flag and
    ...                checking only the other is backed up.
    Create CB bucket if it does not exist cli         bucket=buck1
    Load documents into bucket using cbworkloadgen    bucket=buck1
    Create CB bucket if it does not exist cli         bucket=buck2
    Load documents into bucket using cbworkloadgen    bucket=buck2
    Configure backup                  repo=exclude_buck2    exclude-data=buck2
    Run backup                        repo=exclude_buck2
    ${result}=    Get info as json    repo=exclude_buck2
    ${bucket_uuid}=    Get bucket uuid    bucket=buck1
    ${number_of_backups}=    Get Length    ${result}[backups]
    Length should be       ${result}[backups][${number_of_backups-1}][buckets]             1
    Should be equal        ${result}[backups][${number_of_backups-1}][buckets][0][name]    buck1
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}exclude_buck2${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}buck1-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Check cbworkloadgen rift contents    ${data}    expected_len_json=2048    size=1024

Test include scopes backup
    [Tags]    P1    Backup
    [Documentation]    This tests that when the --include-data flag is used on a bucket with multiple scopes,
    ...                only the data from the specified scope is backed up.
    Delete bucket cli     bucket=buck1
    Create CB bucket if it does not exist cli
    Create CB scope if it does not exist cli              scope=scope1
    Create collection if it does not exist cli            scope=scope1
    Create CB scope if it does not exist cli              scope=scope2
    Create collection if it does not exist cli            scope=scope2
    Load documents into bucket using cbc                  scope=scope1    group=x
    Load documents into bucket using cbc                  scope=scope2    group=y
    Configure backup                  repo=simple-scp-inc     include-data=default.scope1
    Run backup                        repo=simple-scp-inc
    ${result}=    Get info as json    repo=simple-scp-inc
    ${number_of_backups}=         Get Length    ${result}[backups]
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}simple-scp-inc${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${result}=    Get cbriftdump data    dir=${dir}
    Check correct scope    ${result}    x

Test exclude scopes backup
    [Tags]    P1    Backup
    [Documentation]    This tests that when the --exclude-data flag is used on a bucket with multiple scopes,
    ...                only the data from the other scope is backed up.
    Delete bucket cli
    Create CB bucket if it does not exist cli
    Create CB scope if it does not exist cli              scope=scope1
    Create collection if it does not exist cli            scope=scope1
    Create CB scope if it does not exist cli              scope=scope2
    Create collection if it does not exist cli            scope=scope2
    Load documents into bucket using cbc                  scope=scope1    group=x
    Load documents into bucket using cbc                  scope=scope2    group=y
    Configure backup                  repo=simple-scp-exc     exclude-data=default.scope1
    Run backup                        repo=simple-scp-exc
    ${result}=    Get info as json    repo=simple-scp-exc
    ${number_of_backups}=         Get Length    ${result}[backups]
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}simple-scp-exc${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${result}=    Get cbriftdump data    dir=${dir}
    Check correct scope    ${result}    y

Test include collections backup
    [Tags]    P1    Backup
    [Documentation]    This tests that when the --include-data flag is used on a bucket with multiple collections,
    ...                only the data from the specified collection is backed up.
    Delete bucket cli
    Create CB bucket if it does not exist cli
    Create CB scope if it does not exist cli              scope=scope1
    Create collection if it does not exist cli            scope=scope1    collection=collection1
    Create collection if it does not exist cli            scope=scope1    collection=collection2
    Load documents into bucket using cbc                  key=s1c1    scope=scope1    collection=collection1    group=a
    Load documents into bucket using cbc                  key=s1c2    scope=scope1    collection=collection2    group=b
    ${resp}=    Get scopes info
    Log To Console    ${resp}     DEBUG
    Configure backup                  repo=simple-coll-inc    include-data=default.scope1.collection1
    Run backup                        repo=simple-coll-inc
    ${result}=    Get info as json    repo=simple-coll-inc
    ${number_of_backups}=         Get Length    ${result}[backups]
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}simple-coll-inc${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${result}=    Get cbriftdump data    dir=${dir}
    Log To Console    ${result}     DEBUG
    Check correct scope    ${result}    a

Test exclude collections backup
    [Tags]    P1    Backup
    [Documentation]    This tests that when the --exclude-data flag is used on a bucket with multiple collections,
    ...                only the data from the specified collection is backed up.
    Delete bucket cli
    Create CB bucket if it does not exist cli
    Create CB scope if it does not exist cli              scope=scope1
    Create collection if it does not exist cli            scope=scope1    collection=collection1
    Create collection if it does not exist cli            scope=scope1    collection=collection2
    Load documents into bucket using cbc                  key=s1c1    scope=scope1    collection=collection1    group=a
    Load documents into bucket using cbc                  key=s1c2    scope=scope1    collection=collection2    group=b
    Configure backup                  repo=simple-coll-exc    exclude-data=default.scope1.collection1
    Run backup                        repo=simple-coll-exc
    ${result}=    Get info as json    repo=simple-coll-exc
    ${number_of_backups}=         Get Length    ${result}[backups]
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}simple-coll-exc${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${result}=    Get cbriftdump data    dir=${dir}
    Check correct scope    ${result}    b

Test partial backup restored to other bucket
    [Tags]    P1    Restore
    [Documentation]    Tests backup of one bucket can be mapped to another bucket when restored with --map-data flag
    ...                when the backup being restored has multiple buckets.
    Delete bucket cli
    Create CB bucket if it does not exist cli    bucket=buck1
    Create CB bucket if it does not exist cli    bucket=buck2
    Load documents into bucket using cbworkloadgen     bucket=buck1
    Load documents into bucket using cbworkloadgen     bucket=buck2
    Configure backup     repo=simple
    Run backup           repo=simple
    Delete bucket cli    bucket=buck1
    Flush bucket REST    bucket=buck2
    Create CB bucket if it does not exist cli    bucket=new_bucket
    Run restore and wait until persisted    repo=simple     bucket=new_bucket    map-data=buck1=new_bucket
    ${result}=    Get doc info    bucket=new_bucket
    Check restored cbworkloadgen docs contents    ${result}    2048    1024
