***Settings***
Documentation      These test that more complex backup and restore operations can be performed.
Force tags         Tier2
Library            Process
Library            OperatingSystem
Library            Collections
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${ARCHIVE}
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource

Suite setup        Delete bucket cli
Suite Teardown     Collect backup logs and remove archive

***Variables***
${BIN_PATH}        %{HOME}${/}test-source${/}install${/}bin
${ARCHIVE}         ${TEMP_DIR}${/}data${/}backups

***Test Cases***
Test multiple document type backup
    [Tags]    P0    Backup
    [Documentation]    Test multiple document types can be backed up
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen
    Load Binary documents into bucket using cbworkloadgen               key-pref=pymd
    Load documents with xattr into bucket using cbworkloadgen           key-pref=pyme
    Load Binary documents with xattr into bucket using cbworkloadgen    key-pref=pymf
    Configure backup                  repo=simple
    Run backup                        repo=simple
    ${result}=    Get info as json    repo=simple
    ${number_of_backups}=         Get Length       ${result}[backups]
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}simple${/}${result}[backups][${number_of_backups-1}][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Check cbworkloadgen rift contents    ${data}    expected_len_binary=2048    expected_len_json=2048
    ...                    expected_len_binary_xattr=2048    expected_len_json_xattr=2048    size=1024

Test purge backup
    [Tags]    P0    Backup
    [Documentation]    Test that is one backup is terminated mid process then another backup is run with the --purge
    ...                flag then the unfinished backup is deleted so only the new backup remains.
    Flush bucket REST
    Remove Directory    ${ARCHIVE}    recursive=True
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen
    Configure backup                  repo=simple
    Run and terminate backup          repo=simple
    ${result}=    Get info as json    repo=simple
    Run backup                        repo=simple    purge=None
    ${result}=    Get info as json    repo=simple
    Length should be               ${result}[backups]      1
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}simple${/}${result}[backups][0][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Check cbworkloadgen rift contents    ${data}    expected_len_json=2048    size=1024

Test resume backup
    [Tags]    P0    Backup
    [Documentation]    Test that if one backup is terminated mid process then another backup is run with the --resume
    ...                flag then the backup restats from where the previous backup had got to.
    Flush bucket REST
    Remove Directory    ${ARCHIVE}    recursive=True
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen
    Configure backup                  repo=simple
    Run and terminate backup          repo=simple
    ${result1}=    Get info as json    repo=simple
    Run backup                        repo=simple    resume=None
    ${result2}=    Get info as json    repo=simple
    Length should be               ${result2}[backups]         1
    Should be equal    ${result1}[backups][0][date]    ${result2}[backups][0][date]
    ${bucket_uuid}=    Get bucket uuid
    ${dir}=    catenate    SEPARATOR=
    ...    ${ARCHIVE}${/}simple${/}${result2}[backups][0][date]
    ...    ${/}default-${bucket_uuid}${/}data
    ${data}=    Get cbriftdump data     dir=${dir}
    Check cbworkloadgen rift contents    ${data}    expected_len_json=2048    size=1024
