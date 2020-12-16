***Settings***
Documentation      These test that more complex restore operations can be performed.
Force tags         Tier2
Library            Process
Library            OperatingSystem
Library            Collections
Library            ../libraries/cbm_utils.py    ${BIN_PATH}    ${TEMP_DIR}${/}data${/}backups
Resource           ../resources/couchbase.resource
Resource           ../resources/cbm.resource

Suite setup        Delete bucket cli
Suite Teardown     Collect backup logs and remove archive

***Variables***
${BIN_PATH}        %{HOME}${/}test-source${/}install${/}bin

***Test Cases***
Test force updates restore
    [Tags]    P0    Restore
    [Documentation]    This tests that when data is alterd after a backup is taken, when that backup is restored with
    ...                the --force-updates flag the unalterd data from the backup replaces the alterd data.
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbc bucket level
    Configure backup    repo=force_updates
    Run backup          repo=force_updates
    FOR    ${i}    IN RANGE    5
        SDK replace    key=key${i}     value={"group":"changed","num":${i}}
    END
    Run restore    repo=force_updates    force-updates=None
    ${result}=    Get doc info
    ${number_of_doc}=         Get Length    ${result}
    FOR    ${i}    IN RANGE     ${number_of_doc}
        Should be equal    ${result}[${i}][group]    example
    END

Test conflict resolution restore
    [Tags]    P0    Restore
    [Documentation]    This tests that when data is alterd after a backup is taken, when that backup is restored the
    ...                alterd data is not replaced with the unalterd data from the backup.
    Flush bucket REST
    Load documents into bucket using cbc bucket level
    Configure backup    repo=conflict_resolution
    Run backup          repo=conflict_resolution
    FOR    ${i}    IN RANGE    10
        SDK replace    key=key${i}     value={"group":"changed","num":${i}}
    END
    Run restore    repo=conflict_resolution
    ${result}=    Get doc info
    ${number_of_doc}=         Get Length    ${result}
    FOR    ${i}    IN RANGE     ${number_of_doc}
        Should be equal    ${result}[${i}][group]    changed
    END

Test bucket restored to other auto-created bucket
    [Tags]    P1    Restore
    [Documentation]    Tests backup of one bucket can be mapped to another bucket that is auto-created when restored
    ...                with the --map-data and --auto-create-buckets flags.
    Create CB bucket if it does not exist cli
    Flush bucket REST
    Load documents into bucket using cbworkloadgen
    Configure backup    repo=map_auto_create
    Run backup          repo=map_auto_create
    Run restore         repo=map_auto_create    auto-create-buckets=None     map-data=default=new_bucket
    ${result}=    Get doc info    bucket=new_bucket
    Check restored cbworkloadgen docs contents    ${result}    2048    1024

Test filterd bucket restored to other bucket
    [Tags]    P2    Restore
    [Documentation]    Tests backup of one bucket can be mapped to another bucket when restored with --map-data flag
    ...                while also only restoring documents with the keys specified by the --filter-keys flag.
    Create CB bucket if it does not exist cli
    Flush bucket REST
    Flush bucket REST     bucket=new_bucket
    Load documents into bucket using cbworkloadgen    items=2048
    Configure backup    repo=map_filter_keys
    Run backup          repo=map_filter_keys
    Run restore         repo=map_filter_keys    filter-keys=pymc(\\d{1,3}|10[0-1]\\d|102[0-3])$
    ...                 map-data=default=new_bucket
    ${result}=    Get doc info    bucket=new_bucket
    Check restored cbworkloadgen docs contents    ${result}    1024    1024

Test filter to auto-created bucket
    [Tags]    P2    Restore
    [Documentation]    Tests backup of one bucket can be restored to an auto-created bucket when using the
    ...                --auto-create-buckets flag while also only restoring documents with the keys specified by the
    ...                --filter-keys flag.
    Create CB bucket if it does not exist cli
    Flush bucket REST
    Load documents into bucket using cbworkloadgen
    Configure backup    repo=auto_create_filter_keys
    Run backup          repo=auto_create_filter_keys
    Delete bucket cli
    Run restore         repo=auto_create_filter_keys    auto-create-buckets=None
    ...                 filter-keys=pymc(\\d{1,3}|10[0-1]\\d|102[0-3])$
    ${result}=    Get doc info
    Check restored cbworkloadgen docs contents    ${result}    1024    1024

Test filter values to auto-created bucket
    [Tags]    P2    Restore
    [Documentation]    Tests backup of one bucket can be restored to an auto-created bucket when using the
    ...                --auto-create-buckets flag while also only restoring documents with the values specified by the
    ...                --filter-values flag.
    Flush bucket REST
    Load documents into bucket using cbc bucket level    items=2048
    Configure backup    repo=auto_create_filter_values
    Run backup          repo=auto_create_filter_values
    Delete bucket cli
    Run restore         repo=auto_create_filter_values    auto-create-buckets=None
    ...               filter-values=\\{\\"group\\":\\"example\\",\\"num\\":(\\d{1,3}|10[0-1]\\d|102[0-3])\\}
    ${result}=    Get doc info
    Length should be    ${result}    1024

Test filterd values restored to other bucket
    [Tags]    P2    Restore
    [Documentation]    Tests backup of one bucket can be restored to a different bucket when using the
    ...                --map-data flag while also only restoring documents with the values specified by the
    ...                --filter-values flag.
    Flush bucket REST
    Flush bucket REST    bucket=new_bucket
    Load documents into bucket using cbc bucket level    items=2048
    Configure backup    repo=map_filter_values
    Run backup          repo=map_filter_values
    Delete bucket cli
    Run restore         repo=map_filter_values    map-data=default=new_bucket
    ...               filter-values=\\{\\"group\\":\\"example\\",\\"num\\":(\\d{1,3}|10[0-1]\\d|102[0-3])\\}
    ${result}=    Get doc info    bucket=new_bucket
    Length should be    ${result}    1024

Test filterd bucket restored to other auto-created bucket
    [Tags]    P2    Restore
    [Documentation]    Tests backup of one bucket can be mapped to another bucket that is auto-created when restored
    ...                with the --map-data and --auto-create-buckets flags while also only restoring documents with the
    ...                keys specified by the --filter-keys flag.
    Delete bucket cli    bucket=new_bucket
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen
    Configure backup    repo=auto_map_filter_keys
    Run backup          repo=auto_map_filter_keys
    Run restore         repo=auto_map_filter_keys    auto-create-buckets=None     map-data=default=new_bucket
    ...                 filter-keys=pymc(\\d{1,3}|10[0-1]\\d|102[0-3])$
    ${result}=    Get doc info    bucket=new_bucket
    Check restored cbworkloadgen docs contents    ${result}    1024    1024

Test map restore on recreated bucket
    [Tags]    P2    Restore    wait_for_bug_fix
    [Documentation]    Tests that when a bucket that is backed up then deleted then a bucket with the same name is
    ...                created and backed up, the backup can be mapped to another bucket that is auto-created when
    ...                restored with the --map-data.
    Delete bucket cli
    Delete bucket cli    bucket=new_bucket
    Create CB bucket if it does not exist cli
    Load documents into bucket using cbworkloadgen
    Run backup          repo=simple
    Run restore         repo=simple    auto-create-buckets=None     map-data=default=new_bucket
    ${result}=    Get doc info    bucket=new_bucket
    Check restored cbworkloadgen docs contents    ${result}    2048    1024
