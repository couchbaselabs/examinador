***Settings***
Documentation      These test that Examine operations can be performed.
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
Test simple examine
    [Tags]    Examine
    [Documentation]    This tests that the Examine command can be used to return a specified document
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen
    Configure backup    repo=examine_repo
    Run backup          repo=examine_repo
    ${result}=    Get info as json    repo=examine_repo
    ${doc}    ${output}=    Run examine    repo=examine_repo    key=pymc1    json=None
    Log To Console     ${output}[0]                   DEBUG
    Should be equal    ${output}[0][document][key]    pymc1
    Should be equal    ${output}[0][backup]           ${result}[backups][-1][date]
    Verify cbworkloadgen documents    ${doc}    expected_len_json=1    size=1024

Test examine other lanaguage
    [Tags]    Examine
    [Documentation]    This tests that the Examine command can be used to return a document that includes non-latin
    ...                characters in its name
    Flush bucket REST
    Load documents into bucket using cbworkloadgen    key-pref=例テスト
    Configure backup    repo=examine_lang_repo
    Run backup          repo=examine_lang_repo
    ${result}=    Get info as json    repo=examine_lang_repo
    ${doc}    ${output}=    Run examine    repo=examine_lang_repo    key=例テスト1    json=None
    Log To Console     ${output}[0]                   DEBUG
    Should be equal    ${output}[0][document][key]    例テスト1
    Should be equal    ${output}[0][backup]           ${result}[backups][-1][date]
    Verify cbworkloadgen documents    ${doc}    expected_len_json=1    size=1024

Test range examine
    [Tags]    Examine
    [Documentation]    This tests that the Examine command can be used with start and end flags and only find documents
    ...                that were backed up within that range of backups
    Flush bucket REST
    Load documents into bucket using cbworkloadgen
    Configure backup    repo=examine_range_repo
    Run backup          repo=examine_range_repo
    Load documents into bucket using cbworkloadgen    key-pref=pymd
    Run backup          repo=examine_range_repo
    ${result_1}=    Get info as json    repo=examine_repo
    Load documents into bucket using cbworkloadgen    key-pref=pyme
    Run backup          repo=examine_range_repo
    ${result_2}=    Get info as json    repo=examine_repo
    ${doc}    ${output}=    Run examine    repo=examine_range_repo    key=pymc1    start=2    end=3    json=None
    Log To Console                       ${output}[0]                   DEBUG
    Should be equal as integers          ${output}[0][event_type]       7
    Dictionary should not contain key    ${output}                      document
    ${doc}    ${output}=    Run examine    repo=examine_range_repo    key=pymd1    start=2    end=3    json=None
    Log To Console                       ${output}[0]                   DEBUG
    Should be equal                      ${output}[0][document][key]    pymd1
    Should be equal as integers          ${output}[1][event_type]       6
    Verify cbworkloadgen documents    ${doc}    expected_len_json=1    size=1024
    ${doc}    ${output}=    Run examine    repo=examine_range_repo    key=pyme1    start=2    end=3    json=None
    Log To Console                       ${output}[0]                   DEBUG
    Should be equal as integers          ${output}[0][event_type]       7
    Should be equal                      ${output}[1][document][key]    pyme1
    Verify cbworkloadgen documents    ${doc}    expected_len_json=1    size=1024

Test examine with hex value
    [Tags]    Examine
    [Documentation]    This tests that the Examine command can be used to return a specified document
    Flush bucket REST
    Load documents into bucket using cbc bucket level    items=2048
    Configure backup    repo=examine_hex_value_repo
    Run backup          repo=examine_hex_value_repo
    ${result}=    Get info as json    repo=examine_hex_value_repo
    ${doc}    ${output}=    Run examine    repo=examine_hex_value_repo    key=key1    json=None    hex-value=None
    ${hex_value}=    hex encode    {"group":"example","num":1}
    Should be equal    ${output}[0][document][key]      key1
    Should be equal    ${output}[0][document][value]    ${hex_value}

Test examine with xattrs
    [Tags]    Examine
    [Documentation]    This tests that the Examine command can be used with the --no-xattrs flag and not return any
    ...                extended attributes with the document
    Flush bucket REST
    Load documents with xattr into bucket using cbworkloadgen
    Configure backup    repo=examine_xattrs_repo
    Run backup          repo=examine_xattrs_repo
    ${result}=    Get info as json    repo=examine_xattrs_repo
    ${doc}=    Run examine    repo=examine_xattrs_repo    key=pymc1
    Should contain        ${doc}    pymc1
    Should contain        ${doc}    ${result}[backups][-1][date]
    Should contain        ${doc}    field1
    ${doc}=    Run examine    repo=examine_xattrs_repo    key=pymc1    no-xattrs=None
    Should contain        ${doc}    pymc1
    Should contain        ${doc}    ${result}[backups][-1][date]
    Should not contain    ${doc}    field1

Test examine with metadata
    [Tags]    Examine
    [Documentation]    This tests that the Examine command can be used with the --no-meta flag and not return any
    ...                metadata with the document
    Flush bucket REST
    Load documents into bucket using cbworkloadgen
    Configure backup    repo=examine_meta_repo
    Run backup          repo=examine_meta_repo
    ${result}=    Get info as json    repo=examine_meta_repo
    ${doc}=    Run examine    repo=examine_meta_repo    key=pymc1
    Log To Console        ${doc}    DEBUG
    Should contain        ${doc}    pymc1
    Should contain        ${doc}    ${result}[backups][-1][date]
    Should contain        ${doc}    CAS
    ${doc}=    Run examine    repo=examine_meta_repo    key=pymc1    no-meta=None
    Log To Console        ${doc}    DEBUG
    Should contain        ${doc}    pymc1
    Should contain        ${doc}    ${result}[backups][-1][date]
    Should not contain    ${doc}    CAS

Test examine no value
    [Tags]    Examine
    [Documentation]    This tests that the Examine command can be used with the --no-value flag and not return a the
    ...                value of the document
    Flush bucket REST
    Load documents with xattr into bucket using cbworkloadgen
    Configure backup    repo=examine_no_value_repo
    Run backup          repo=examine_no_value_repo
    ${result}=    Get info as json    repo=examine_no_value_repo
    ${doc}=    Run examine    repo=examine_no_value_repo    key=pymc1
    Should contain         ${doc}    pymc1
    Should contain         ${doc}    ${result}[backups][-1][date]
    Should contain         ${doc}    body
    ${doc}=    Run examine    repo=examine_no_value_repo    key=pymc1    no-value=None
    Should contain        ${doc}    pymc1
    Should contain        ${doc}    ${result}[backups][-1][date]
    Should Not Contain    ${doc}    body
