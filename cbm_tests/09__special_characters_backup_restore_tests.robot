***Settings***
Documentation      These test that backups involving special characters can be performed.
Library            Process
Library            OperatingSystem
Library            Collections
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${ARCHIVE}
Library            ../libraries/sdk_utils.py
Library            ../libraries/utils.py
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource

Suite setup        Delete bucket cli
Suite Teardown     Collect backup logs and remove archive

***Variables***
${BIN_PATH}        ${SOURCE}${/}install${/}bin
${ARCHIVE}         ${TEMP_DIR}${/}data${/}backups

***Test Cases***
Test backup with values in other language
    [Tags]    Backup
    [Documentation]    This tests that documents containing non-latin characters can be backed up without the contents
    ...                of the document being altered.
    Create CB bucket if it does not exist cli
    ${previous_count}=    get item count    default
    Load docs sdk    group=이것은_필드입니다
    Wait for items to be persisted to disk    ${previous_count}    2048
    Configure backup    repo=other_lang_value_repo
    Run backup          repo=other_lang_value_repo
    ${result}=               Get info as json    repo=other_lang_value_repo
    ${bucket_index}=         Get bucket index    ${result}
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]          default
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]     2048
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][tombstones]    0
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}other_lang_value_repo${/}${result}[backups][-1][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Length should be    ${data}                        2048
    Should be equal     ${data}[1][value][group]       이것은_필드입니다
    Should be equal     ${data}[11][value][group]      이것은_필드입니다
    Should be equal     ${data}[111][value][group]     이것은_필드입니다
    Should be equal     ${data}[1111][value][group]    이것은_필드입니다

Test Restore value in other language
    [Tags]    Restore
    [Documentation]    This tests that documents containing non-latin characters can be restored without the contents
    ...                of the document being altered.
    Flush bucket REST
    Run restore and wait until persisted    repo=other_lang_value_repo
    ${result}=    Get doc info
    Length should be    ${result}                 2048
    Should be equal     ${result}[1][group]       이것은_필드입니다
    Should be equal     ${result}[11][group]      이것은_필드입니다
    Should be equal     ${result}[111][group]     이것은_필드입니다
    Should be equal     ${result}[1111][group]    이것은_필드입니다

Test backup of bucket with specical characters
    [Tags]    Backup
    [Documentation]    This tests that a backup can be performed with a bucket named with non-latin characters and then
    ...                checks the the number of documents are correct and the documents have the correct body and
    ...                metadata.
    Flush bucket REST
    Create CB bucket if it does not exist cli    bucket=buck%with-chars.
    Load documents into bucket using cbworkloadgen    bucket=buck%with-chars.
    Configure backup    repo=other_lang_bucket_repo
    Run backup          repo=other_lang_bucket_repo
    ${result}=               Get info as json    repo=other_lang_bucket_repo
    ${bucket_index}=         Get bucket index    ${result}    bucket=buck%with-chars.
    Should Be Equal                ${result}[backups][-1][buckets][${bucket_index}][name]          buck%with-chars.
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][mutations]     2048
    Should Be Equal as integers    ${result}[backups][-1][buckets][${bucket_index}][tombstones]    0
    ${bucket_uuid}=    Get bucket uuid    bucket=buck%with-chars.
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}other_lang_bucket_repo${/}${result}[backups][-1][date]
    ...    ${/}buck%with-chars.-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Verify cbworkloadgen documents    ${data}    expected_len_json=2048    size=1024
