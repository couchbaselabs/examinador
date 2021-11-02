***Settings***
Documentation      These test that data from each Couchbase service can be backed up.
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
...                AND    Wait for indexer to be active
...                AND    Create CB bucket if it does not exist cli
...                AND    Create CB bucket if it does not exist cli    bucket=meta
...                AND    Create eventing file
...                AND    Create eventing file legacy
...                AND    Load data to all services
Suite Teardown     Run keywords    Collect backup logs and remove archive
...                AND    Drop all indexes
...                AND    Delete all eventing data

***Variables***
${BIN_PATH}        %{HOME}${/}test-source${/}install${/}bin
${ARCHIVE}         ${TEMP_DIR}${/}data${/}backups

***Test Cases***
Test data backup
    [Tags]             Tier2    P2    Backup
    [Documentation]    This tests that only information about the Data Service is backed up when the backup repo
    ...                is configured with all other services disabled.
    Configure backup     repo=backup_data     disable-gsi-indexes=None    disable-ft-indexes=None
    ...                  disable-ft-alias=None    disable-analytics=None    disable-eventing=None
    Run backup          repo=backup_data
    Check backup item counts    backup_data    data=2048

Test index backup
    [Tags]             Tier2    P2    Backup
    [Documentation]    This tests that only information about the Index Service is backed up when the backup repo
    ...                is configured with all other services disabled.
    Configure backup     repo=backup_index     disable-data=None    disable-ft-indexes=None
    ...                  disable-ft-alias=None    disable-analytics=None    disable-eventing=None
    Run backup          repo=backup_index
    Check backup item counts    backup_index    indexes=1

Test fts backup
    [Tags]             Tier2    P2    Backup
    [Documentation]    This tests that only information about the Full-Text Search Service is backed up when the backup repo
    ...                is configured with all other services disabled.
    Configure backup     repo=backup_fts     disable-data=None    disable-gsi-indexes=None
    ...                  disable-analytics=None    disable-eventing=None
    Run backup          repo=backup_fts
    Check backup item counts    backup_fts    fts=1

Test analytics backup
    [Tags]             Tier2    P2    Backup
    [Documentation]    This tests that only information about the Analytics Service is backed up when the backup repo
    ...                is configured with all other services disabled.
    Configure backup     repo=backup_analytics     disable-data=None    disable-gsi-indexes=None
    ...                  disable-ft-indexes=None    disable-ft-alias=None    disable-eventing=None
    Run backup          repo=backup_analytics
    Check backup item counts    backup_analytics    analytics=1


Test eventing backup
    [Tags]             Tier2    P2    Backup
    [Documentation]    This tests that only information about the Eventing Service is backed up when the backup repo
    ...                is configured with all other services disabled.
    Configure backup     repo=backup_eventing     disable-data=None    disable-gsi-indexes=None
    ...                  disable-ft-indexes=None     disable-ft-alias=None    disable-analytics=None
    Run backup          repo=backup_eventing
    Check backup item counts    backup_eventing    events=2

*** Keywords ***
Check backup item counts
    [Arguments]    ${repo}    ${data}=0    ${indexes}=0    ${fts}=0    ${analytics}=0    ${events}=0
    [Documentation]    Check that the correct number of items for each service are included in the backup
    ${result}=    Get info as json    repo=${repo}
    ${bucket_index}=    Get bucket index    ${result}
    Log To Console    ${result}     DEBUG
    Should be equal as integers     ${result}[backups][-1][buckets][${bucket_index}][items]              ${data}
    Should be equal as integers     ${result}[backups][-1][buckets][${bucket_index}][index_count]        ${indexes}
    Should be equal as integers     ${result}[backups][-1][buckets][${bucket_index}][fts_count]          ${fts}
    Should be equal as integers     ${result}[backups][-1][buckets][${bucket_index}][analytics_count]    ${analytics}
    Should be equal as integers     ${result}[backups][-1][events]                                       ${events}
