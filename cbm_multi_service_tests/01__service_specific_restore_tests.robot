***Settings***
Documentation      These test that data from each Couchbase service can be restored.
Force tags         Cluster
Library            Process
Library            OperatingSystem
Library            Collections
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${ARCHIVE}
Library            ../libraries/sdk_utils.py
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource
Resource           ../resources/eventing.resource

Suite setup        Run keywords    Delete bucket cli
...                AND    Create CB bucket if it does not exist cli
...                AND    Load data to all services
Suite Teardown     Collect backup logs and remove archive


***Variables***
${BIN_PATH}        ${SOURCE}${/}install${/}bin
${ARCHIVE}         ${TEMP_DIR}${/}data${/}backups

***Test Cases***
Test data restore
    [Tags]             Tier1    P2    Restore
    [Documentation]    This tests that when the --disable-(service) flag is used for all services but Data, only data
    ...                about the Data service is restored.
    Configure backup     repo=restore_multi
    Run backup           repo=restore_multi
    Flush bucket REST
    Drop all indexes
    Delete all eventing data
    Check indexes    service=data
    Run restore and wait until persisted    repo=restore_multi     disable-gsi-indexes=None    disable-ft-indexes=None
    ...                  disable-ft-alias=None    disable-analytics=None    disable-eventing=None
    ${result}=    Get doc info
    Check restored cbc docs contents    ${result}    2048    example
    Check indexes    service=data
    ${all_eventing_func_correct_status}=    Confirm existence status of all eventing functions    should_exist=False
    Should be equal    ${all_eventing_func_correct_status}    True

Test index restore
    [Tags]             Tier1    P2    Restore
    [Documentation]    This tests that when the --disable-(service) flag is used for all services but Index, only data
    ...                about the Index service is restored.
    Flush bucket REST
    Drop all indexes
    Run restore and wait until persisted    repo=restore_multi     items=0    disable-data=None
    ...                          disable-ft-indexes=None
    ...                          disable-ft-alias=None    disable-analytics=None    disable-eventing=None
    ${result}=    Get current item number
    Should be equal as integers    ${result}    0
    Check indexes
    ${all_eventing_func_correct_status}=    Confirm existence status of all eventing functions    should_exist=False
    Should be equal    ${all_eventing_func_correct_status}    True

Test fts restore
    [Tags]             Tier1    P2    Restore
    [Documentation]    This tests that when the --disable-(service) flag is used for all services but Full-Text Search,
    ...                only data about the Full-Text Search service is restored.
    Flush bucket REST
    Drop all indexes
    Run restore and wait until persisted    repo=restore_multi     items=0    disable-data=None
    ...                          disable-gsi-indexes=None    disable-analytics=None    disable-eventing=None
    ${result}=    Get current item number
    Should be equal as integers    ${result}    0
    Check indexes    service=fts
    ${all_eventing_func_correct_status}=    Confirm existence status of all eventing functions    should_exist=False
    Should be equal    ${all_eventing_func_correct_status}    True

Test analytics restore
    [Tags]             Tier1    P2    Restore
    [Documentation]    This tests that when the --disable-(service) flag is used for all services but Analytics, only
    ...                data about the Analytics service is restored.
    Flush bucket REST
    Drop all indexes
    Run restore and wait until persisted    repo=restore_multi     items=0    disable-data=None
    ...                          disable-gsi-indexes=None
    ...                          disable-ft-indexes=None    disable-ft-alias=None    disable-eventing=None
    ${result}=    Get current item number
    Should be equal as integers    ${result}    0
    Check indexes    service=analytics
    ${all_eventing_func_correct_status}=    Confirm existence status of all eventing functions    should_exist=False
    Should be equal    ${all_eventing_func_correct_status}    True

Test eventing restore
    [Tags]             Tier1    P2    Restore
    [Documentation]    This tests that when the --disable-(service) flag is used for all services but Eventing, only
    ...                data about the Eventing service is restored.
    Flush bucket REST
    Drop all indexes
    Run restore and wait until persisted    repo=restore_multi     items=0    disable-data=None
    ...                          disable-gsi-indexes=None
    ...                          disable-ft-indexes=None    disable-ft-alias=None    disable-analytics=None
    ${result}=    Get current item number
    Should be equal as integers    ${result}    0
    ${all_eventing_func_correct_status}=    Confirm existence status of all eventing functions    should_exist=True
    Should be equal    ${all_eventing_func_correct_status}    True
    Drop all indexes
    Delete all eventing data
