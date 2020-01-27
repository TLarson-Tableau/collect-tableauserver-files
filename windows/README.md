# collect-tsfiles.bat

[collect-tsfiles.bat](https://github.com/TLarson-Tableau/collect-tableauserver-files/blob/master/collect-tsfiles.bat) will create a pg-only backup of Tableau Server as workgroup.tsbak. It will then create a staging directory in %temp%\staging to copy the workgroup.yml and System Info (NFO) files. Workgroup.tsbak is renamed to workgroup.zip and then the staged files will be packaged up in workgroup.zip. If Tableau Server can create an outbound connection to https://report-issue.tableau.com/ and a case number is provided to the script, then workgroup.zip will be automatically uploaded to the Tableau Technical Support Case.

## Prerequisites:
- Windows Server
- Tableau Server 2018.2 or later
- Case Number and email address (for file upload)
- Outbound connection to https://report-issue.tableau.com/ (for file upload)

## Usage:
```
collect-tsfiles.bat [nopg] [noupload]
```
<dl>
 <dt><b>nopg</b></dt>
 <dd>Tells the script not to geneate workgroup.pg_dump. Under normal operation, this option should not be passed. You might pass this option if the script is only being run to collect NFO files, or your organization does not allow workgroup.pg_dump to be provided.</dd>

 <dt><b>noupload</b></dt>
 <dd>Tells the script not to upload the output file (workgroup.zip) to a Tableau Technical Support case. Only use this option if you know that *tsm maintenance send-logs* will not succeed due to infrastructure limitations.</dd>
</dl>

## Run as Administrator
The script must be run as administrator to complete successfully.
This can be done in one of two ways
  1. Right-click and run as administrator
  2. Open a command prompt as administrator and execute the script

## Interactive Mode:
By defaulut the script will run in interactive mode and prompt for input
- case number
- email
- TSM username and password

## Non-interactive Mode:
If you would like to schedule the script to run without user input, there are some variables that can be set near the top of the script.
Find these lines and uncomment them by removing the `"::"`
```
::SET "silent=Y"
::SET "case=12345678"
::SET "email=name@domain.com"
::SET "user=username"
::SET password="Your not so secret password."
```
 
This must be uncommented in order for the script to run in non-interactive mode
```
SET "silent=Y"
```

These must be uncommented and correct information entered to allow for the automatic upload of the output file
```
SET "case=12345678"
SET "email=name@domain.com"
```

Tableau Server version 2019.2 and earlier require you to login to TSM. Enter a valid username and password for a user who is a TSM admin. Tableau Server 2019.3 or later does not require this.
```
SET "user=username"
SET password="Your not so secret password."
```
