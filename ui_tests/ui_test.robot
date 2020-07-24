*** Settings ***
Documentation     Simple Backup UI tests.
Library           SeleniumLibrary
Suite setup       Set selenium timeout    5s

*** Variables ***
${BASE_HOST}      http://localhost:9000/ui/index.html
${BROWSER}        Chrome
${USERNAME}       Administrator
${PASSWORD}       asdasd


*** Test Cases ***
Loging and go to backup tab
    [Documentation]
    ...    Check that we can loging into the administrator console and click the backup tab it expects to see the no
    ...    instance exists message.
    Open browser to main page
    Input text        name:username    ${USERNAME}
    Input password    name:password    ${PASSWORD}
    Submit credentials
    Go to backup tab
    Confirm that no instance page shows
    [Teardown]    Close browser


*** Keywords ***
Open browser to main page
    Open browser    ${BASE_HOST}    ${BROWSER}
    Sleep           2s

Submit credentials
    Click button    tag:button

Go to backup tab
    Wait until element is visible    link:Backup
    Click link                       link:Backup
    Location should contain          /ui/index.html#/backup/instances

Confirm that no instance page shows
    Wait until element is visible    class:zero-content
    Page should contain              No instances are registered
