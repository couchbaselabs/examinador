***Settings***
Documentation      These test that simple backup and restore operations can be performed.
Force tags         Tier1
Library            Process
Library            OperatingSystem
Library            Collections
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${ARCHIVE}
Library            ../libraries/sdk_utils.py
Library            ../libraries/utils.py
Library            ../libraries/common_utils.py    ${SOURCE}
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource

Suite setup        Delete bucket cli
Suite Teardown     Run keywords    Collect backup logs and remove archive

***Variables***
${BIN_PATH}        ${SOURCE}${/}install${/}bin
${ARCHIVE}         ${TEMP_DIR}${/}data${/}backups

***Test Cases***
Test Simple backup
    [Tags]    P0    Backup
    [Documentation]    This tests that a backup can be performed and then checks the the number of documents are correct
    ...                and the documents have the correct body and metadata.
    Set index memory quota
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen
    Configure backup    repo=simple
    Run backup          repo=simple
    ${result}=               Get info as json    repo=simple
    ${number_of_backups}=    Get Length    ${result}[backups]
    ${bucket_index}=         Get bucket index    ${result}
    Should Be Equal                ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][name]
    ...                            default
    Should Be Equal as integers    ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][mutations]
    ...                            2048
    Should Be Equal as integers    ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][tombstones]
    ...                            0
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}simple${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024

Test Restore Backup
    [Tags]    P0    Restore
    [Documentation]    Tests a backup is restored by flushing bucket then restoring it and showing
    ...                it contains the correct number of documents in the correct format
    Flush bucket REST
    Run restore and wait until persisted    repo=simple
    ${result}=    Get doc info
    Check restored cbworkloadgen docs contents    ${result}    2048    1024

Test Backup Restore of Users
    [Tags]    P0    Backup  Restore  Users
    [Documentation]    Tests backup of a bucket is restored including the users
    Add user
    Configure backup                        repo=simple-with-users      users=True
    Run backup                              repo=simple-with-users
    Flush bucket REST
    Delete user
    Run restore and wait until persisted    repo=simple-with-users      users=True
    ${userInfo} =  Get user info
    ${userName} =  Evaluate  $userInfo.get("id")
    Should Be Equal  ${userName}  test-user
    ${roleCheckReturnCode} =  Check user role
    Should Be Equal as integers  ${roleCheckReturnCode}  0

Test bucket restored to other bucket
    [Tags]    P0    Restore
    [Documentation]    Tests backup of one backup can be mapped to another bucket when restored with --map-data flag.
    Create CB bucket if it does not exist cli    bucket=new_bucket
    Run restore and wait until persisted    repo=simple    bucket=new_bucket    map-data=default=new_bucket
    ${result}=    Get doc info    bucket=new_bucket
    Check restored cbworkloadgen docs contents    ${result}    2048    1024

Test Incremental backup
    [Tags]    P0    Backup
    [Documentation]    This tests that subsequent backup is incremental so only new mutations
    ...                are backed up by checking the number of mutations in the second backup
    ...                is the same and the number of new documents added
    Flush bucket REST
    Load documents into bucket using cbworkloadgen    key-pref=pymd
    Run backup      repo=simple
    Load documents into bucket using cbworkloadgen    key-pref=pyme
    Run backup      repo=simple
    ${result}=               Get info as json    repo=simple
    ${number_of_backups}=    Get Length    ${result}[backups]
    ${bucket_index}=         Get bucket index    ${result}
    Should Be Equal                ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][name]
    ...                            default
    Should Be Equal as integers    ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][mutations]
    ...                            2048
    Should Be Equal as integers    ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][tombstones]
    ...                            0
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}simple${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024
    Check key not included in backup     ${data}    pymc
    Check key not included in backup     ${data}    pymd

Test all incremental backups restored
    [Tags]    P0    Restore
    [Documentation]    Tests all incremental backups are restored by flushing bucket then restoring it and showing
    ...                it contains the correct number of documents in the correct format
    Load documents into bucket using cbworkloadgen    key-pref=pymf
    Run backup                        repo=simple
    Flush bucket REST
    Run restore and wait until persisted    repo=simple    items=6144
    ${result}=    Get doc info
    Check restored cbworkloadgen docs contents    ${result}    6144    1024

Test range of incremental backups restored
    [Tags]    P0    Restore
    [Documentation]    Tests all incremental backups are restored by flushing bucket then restoring it and showing
    ...                it contains the correct number of documents in the correct format
    Flush bucket REST
    Run restore and wait until persisted    repo=simple    start=3    end=4    items=4096
    ${result}=    Get doc info
    Check restored cbworkloadgen docs contents         ${result}    4096    1024
    Check key not included in restore    ${result}    pymc
    Check key not included in restore    ${result}    pymd

Test Force Full Backup
    [Tags]    P0    Backup
    [Documentation]    This tests that a full backup is performed if the --full-backup flag is
    ...                used by checking the number of items backed up is the number originally backed up
    Load documents into bucket using cbworkloadgen    key-pref=pymg
    Run backup      repo=simple    full-backup=None
    ${result}=               Get info as json    repo=simple
    ${number_of_backups}=    Get Length    ${result}[backups]
    ${bucket_index}=         Get bucket index    ${result}
    Should Be Equal                ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][name]
    ...                            default
    Should Be Equal as integers    ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][tombstones]
    ...                            0
    # The scope with uid 0 is the default scope
    Should Be Equal as integers    ${result}[backups][${number_of_backups-1}][buckets][${bucket_index}][scopes][0][mutations]
    ...                            6144
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}simple${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Verify cbworkloadgen documents    ${data}    expected_len_json=6144    size=1024

Test filter docs restored
    [Tags]    P1    Restore
    [Documentation]    This tests that when a backup is restored with the --filter-keys flag, only
    ...                documents with correct keys are restored.
    Remove Directory    ${ARCHIVE}    recursive=True
    Flush bucket REST
    Load documents into bucket using cbc bucket level
    Configure backup    repo=simple
    Run backup      repo=simple
    Flush bucket REST
    Run restore and wait until persisted     repo=simple    filter-keys=key[0-4]    items=5
    ${result}=    Get doc info
    Length should be    ${result}    5

Test filter values restored
    [Tags]    P1    Restore
    [Documentation]    This tests that when a backup is restored with the --filter-keys flag, only
    ...                documents with correct keys are restored.
    Flush bucket REST
    Run restore and wait until persisted     repo=simple
    ...                 filter-values=\\{\\"group\\":\\"example\\",\\"num\\":[0-4]\\}    items=5
    ${result}=    Get doc info
    Length should be    ${result}    5

Test auto-create bucket
    [Tags]    P1    Backup    Restore
    [Documentation]    This tests that a bucket that is backed-up and the deleted is auto-created
    ...                when the backup is restored.
    Create CB bucket if it does not exist cli         bucket=new_bucket
    Load documents into bucket using cbworkloadgen    bucket=new_bucket    key-pref=pymd
    Run backup             repo=simple
    Delete bucket cli      bucket=new_bucket
    Run restore and wait until persisted            repo=simple     bucket=new_bucket    auto-create-buckets=None    items=4096
    ${result}=    Get doc info    bucket=new_bucket
    Check restored cbworkloadgen docs contents    ${result}    4096    1024

Test disable bucket config
    [Tags]    P1    Restore    Info
    [Documentation]    This tests that info and restore work correctly when --disable-bucket-config
    ...                is used (MB-60393).
    Remove Directory    ${ARCHIVE}    recursive=True
    Configure backup    repo=flush_enabled    disable-bucket-config=None
    Enable flush
    Run backup    repo=flush_enabled
    Disable flush
    ${result}=                     Get info as json    repo=flush_enabled
    ${number_of_backups}=          Get Length    ${result}[backups]
    Should Be Equal as integers    ${number_of_backups}
    ...                            1
    ${bucket_index}=               Get bucket index    ${result}
    Should Be Equal                ${result}[backups][0][buckets][${bucket_index}][name]
    ...                            default
    Should Be Equal as integers    ${result}[backups][0][buckets][${bucket_index}][mutations]
    ...                            5
    Should Be Equal as integers    ${result}[backups][0][buckets][${bucket_index}][tombstones]
    ...                            0
    Restore docs    repo=flush_enabled    enable-bucket-config=None
    Check flush is disabled

Test disable data restore
    [Tags]    P1    Restore
    [Documentation]    This tests that when a backup is restored with the --disable-data flag, no
    ...                documents should be restored but the manifest should be.
    Create CB bucket if it does not exist cli             bucket=noDataBucket
    Create CB scope if it does not exist cli              bucket=noDataBucket  scope=scope
    Create collection if it does not exist cli            bucket=noDataBucket  scope=scope    collection=collection
    Load documents into bucket using cbc                  bucket=noDataBucket  key=s1c1    scope=scope    collection=collection    group=a
    Configure backup    repo=no_data
    Run backup          repo=no_data
    Flush bucket REST   bucket=noDataBucket
    Run restore and wait until persisted                  repo=no_data      disable-data=None   items=0
    @{after_docs}=      Get doc info                      bucket=noDataBucket
    Length should be    ${after_docs}    0
    ${result}=          Get scopes info                    bucket=noDataBucket  scope=scope
    Should Be True      """${result['scopes'][0]['collections'][0]['name']}""" == """collection"""
