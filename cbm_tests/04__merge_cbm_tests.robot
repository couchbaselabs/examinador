***Settings***
Documentation      These test that backups can be merged together successfully.
Force tags         Tier1
Library            Process
Library            OperatingSystem
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource

Suite setup        Run keywords    Delete bucket cli     bucket=buck1
...                AND    Delete bucket cli     bucket=buck2
Suite Teardown     Collect backup logs and remove archive


***Test Cases***
Test non-overlapping backups merge
    [Tags]    P0    Merge
    [Documentation]    This tests that backups without overlapping mutations can be merged
    Configure backup                  repo=simple
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen
    Run backup                        repo=simple
    Load documents into bucket using cbworkloadgen    key-pref=pymd
    Run backup                        repo=simple
    Load documents into bucket using cbworkloadgen    key-pref=pyme
    Run backup                        repo=simple
    Load documents into bucket using cbworkloadgen    key-pref=pymf
    Run backup                        repo=simple
    ${result}=    Get info as json    repo=simple
    ${number_of_backups}=    Get Length    ${result}[backups]
    Merge multiple backups            repo=simple    start=${result}[backups][${number_of_backups-3}][date]
    ...                               end=${result}[backups][${number_of_backups-1}][date]
    ${result}=    Get info as json    repo=simple
    ${number_of_backups}=         Get Length       ${result}[backups]
    Should Be Equal as integers    ${result}[backups][${number_of_backups-1}][buckets][0][mutations]    6144
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${TEMP_DIR}${/}data${/}backups${/}simple${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Check cbworkloadgen rift contents    ${data}    expected_len_json=6144    size=1024
    Check key not included in backup     ${data}    pymc

Test overlapping backups merge
    [Tags]    P0    Merge
    [Documentation]    This tests that backups with overlapping mutations can be merged
    Flush bucket REST
    Load documents into bucket using cbworkloadgen
    Load documents into bucket using cbworkloadgen    key-pref=pymd
    Run backup                        repo=simple
    Load documents into bucket using cbworkloadgen
    Load documents into bucket using cbworkloadgen    key-pref=pyme
    Run backup                        repo=simple
    Load documents into bucket using cbworkloadgen    key-pref=pymf
    Run backup                        repo=simple
    ${result}=    Get info as json    repo=simple
    ${number_of_backups}=    Get Length    ${result}[backups]
    Merge multiple backups            repo=simple    start=${result}[backups][${number_of_backups-3}][date]
    ...                               end=${result}[backups][${number_of_backups-1}][date]
    ${result}=    Get info as json    repo=simple
    ${number_of_backups}=         Get Length       ${result}[backups]
    Should Be Equal as integers    ${result}[backups][${number_of_backups-1}][buckets][0][mutations]    8192
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${TEMP_DIR}${/}data${/}backups${/}simple${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Check cbworkloadgen rift contents    ${data}    expected_len_json=8192    size=1024
