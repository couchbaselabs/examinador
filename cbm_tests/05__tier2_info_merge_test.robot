***Settings***
Documentation      These test that correct info can be returned about the backups.
Force tags         Tier2
Library            Process
Library            OperatingSystem
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource


Suite Teardown     Collect backup logs and remove archive

***Variables***
${ARCHIVE}         ${TEMP_DIR}${/}data${/}backups

***Test Cases***
Test info per depth
    [Tags]    P0    Info
    [Documentation]    Run a backup and then get info in user readable format with the --depth flag set to multiple
    ...                differnt values and check the correct amount of information is given for each.
    Delete bucket cli
    Create CB bucket if it does not exist cli         bucket=buck1
    Create CB bucket if it does not exist cli         bucket=buck2
    Load documents into bucket using cbc              bucket=buck1    scope=scope1    collection=coll1
    Load documents into bucket using cbc              bucket=buck2
    Configure backup                                  repo=info_depth
    Run backup                                        repo=info_depth
    Load documents into bucket using cbc              bucket=buck1    key=pymd    scope=scope1    collection=coll1
    Load documents into bucket using cbc              bucket=buck2    key=pymd
    Run backup                                        repo=info_depth
    Run backup                                        repo=info_depth
    ${result}=    Get info as user     repo=info_depth     depth=1
    Should contain        ${result}    Name
    Should not contain    ${result}    Cluster UUID
    Should not contain    ${result}    buck1
    ${result}=    Get info as user     repo=info_depth     depth=2
    Should contain        ${result}    Name
    Should contain        ${result}    Cluster UUID
    Should not contain    ${result}    buck1
    ${result}=    Get info as user     repo=info_depth     depth=3
    Should contain        ${result}    Name
    Should contain        ${result}    Cluster UUID
    Should contain        ${result}    buck1

Test backups across multiple days merge
    [Tags]    P0    Merge
    [Documentation]    This tests that backups taken across multiple days can be merged by altering the date of a
    ...                backup.
    Delete bucket cli                                 bucket=buck1
    Delete bucket cli                                 bucket=buck2
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen    key-pref=pymd
    Configure backup                                  repo=across_day_merge
    Run backup                                        repo=across_day_merge
    Load documents into bucket using cbworkloadgen    key-pref=pyme
    Run backup                                        repo=across_day_merge
    ${result}=    Get info as json                   repo=across_day_merge
    ${number_of_backups}=    Get Length    ${result}[backups]
    Should be equal as integers    ${number_of_backups}    2
    Change backup date    ${result}[backups][0][date]    ${ARCHIVE}${/}across_day_merge
    Merge multiple backups            repo=across_day_merge    start=oldest    end=latest
    ${result}=    Get info as json    repo=across_day_merge
    ${number_of_backups}=    Get Length    ${result}[backups]
    Should be equal as integers    ${number_of_backups}    1
    Should be equal as integers    ${result}[backups][0][buckets][0][mutations]    4096
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}across_day_merge${/}${result}[backups][0][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data    dir=${dir}
    Check cbworkloadgen rift contents    ${data}    expected_len_json=4096    size=1024
    Check key is included in backup      ${data}    pymd    2048
    Check key is included in backup      ${data}    pyme    2048
