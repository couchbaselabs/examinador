***Settings***
Documentation      Miscellaneous tests fo cbbackupmgr.
Force tags         Miscellaneous
Library            Process
Library            OperatingSystem
Suite Teardown     Remove Directory    ${TEMP_DIR}${/}data${/}backups    recursive=True

***Variables***
${BIN_PATH}    %{HOME}${/}source${/}install${/}bin

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
    Should Match Regexp            ${result.stdout}      ^cbbackupmgr \\[\\<command\\>\\] \\[\\<args\\>\\]
