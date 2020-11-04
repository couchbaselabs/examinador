***Settings***
Documentation      Miscellaneous tests fo cbbackupmgr.
Force tags         Miscellaneous
Library            Process
Library            OperatingSystem
Suite Teardown     Remove Directory    ${TEMP_DIR}${/}data${/}backups    recursive=True

***Variables***
${BIN_PATH}    %{HOME}${/}source${/}install${/}bin
${HELP}     SEPARATOR=\n     cbbackupmgr \\[\\<command\\>\\] \\[\\<args\\>\\]\\n
...    ${SPACE * 2}backup${SPACE * 9}Backup a Couchbase cluster
...    ${SPACE * 2}collect\\-logs${SPACE * 3}Collect debugging information
...    ${SPACE * 2}compact${SPACE * 8}Compact an incremental backup
...    ${SPACE * 2}config${SPACE * 9}Create a new backup configuration
...    ${SPACE * 2}help${SPACE * 11}Get extended help for a subcommand
...    ${SPACE * 2}examine${SPACE * 8}Search inside a backup/repository for a specified document
...    ${SPACE * 2}info${SPACE * 11}Provide information about the archive
...    ${SPACE * 2}merge${SPACE * 10}Merge incremental backups together \\(Enterprise Edition Only\\)
...    ${SPACE * 2}remove${SPACE * 9}Delete a backup permanently
...    ${SPACE * 2}restore${SPACE * 8}Restore an incremental backup\\n
...    Optional Flags:\\n    ${SPACE * 5}\\-\\-version${SPACE * 16}Prints version information
...    ${SPACE * 2}\\-h,\\-\\-help${SPACE * 19}Prints the help message\\n

***Test Cases***
Test CBM Version runs
    [Tags]    Miscellaneous
    [Documentation]     This test gets the version then checks it is the correct version
    ${result}=    Run Process     ${BIN_PATH}${/}cbbackupmgr    --version
    Should be equal as integers    ${result.rc}    0
    Should Match Regexp           ${result.stdout}    cbbackupmgr version \\d.\\d.\\d+-[\\d]{4} \\(\\w+\\)

Test CBM short help works
    [Tags]    Miscellaneous
    [Documentation]    This tests -h flags gives expected output
    ${result}=    Run Process      ${BIN_PATH}${/}cbbackupmgr    -h
    Should be equal as integers    ${result.rc}    0
    Should Match Regexp            ${result.stdout}      ${HELP}
