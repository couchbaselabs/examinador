*** Settings ***
Documentation     Simple Backup UI tests.
Library           SeleniumLibrary

*** Variables ***
${BASE_HOST}      http://localhost:9000/ui/index.html
${BROWSER}        Chrome
${USERNAME}       Administrator
${PASSWORD}       asdasd


*** Test Cases ***
Valid Login
    [Documentation]    Check that we can loging into the administrator console
    Open browser to main page
    Input username    ${USERNAME}
    Input password    ${PASSWORD}
    Submit credentials
    Click link    linkText=Backup
    Location should be    /ui/index.html#/backup/instances
    [Teardown]    Close browser


*** Keywords ***
Open browser to main page
    Open browser    ${BASE_HOST}    ${BROWSER}
    Sleep           2s

Input username
    [Arguments]    ${username}
    Input Text     name=username    ${username}

Input password
    [Arguments]    ${password}
    Input text     name=password    ${password}

Submit credentials
    Click button    tag=button
