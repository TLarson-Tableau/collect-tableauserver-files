@ECHO off
SETLOCAL EnableDelayedExpansion
SETLOCAL ENABLEEXTENSIONS

:: Usage
:: collect-tsfiles.bat [param1] [param2]
:: param1 and param2 allow you to alter certain functionality of the script
:: "nopg" will result in NOT collecting a pg_dump file
:: "noupload" will result in NOT attempting to upload the resulting workgroup.zip directly to Tableau

:: This script is for the collection of files needed for the Elite/Premium Support Deployment Review
:: it may be used in other situations where the same informatoin is needed
:: Files Collected: workgroup.pg_dump, workgroup.yml, msinfo32 output from each server in the cluster
::
:: To collect workgroup.yml, the script must be run in an elevated mode (as administrator), this is due to folder permissions and User Access Control
:: To collect workgroup.pg_dump, a pg-only backup is taken as workgroup.tsbak
:: msinfo32 is run from the command line to connect to each server in the cluster and generate the NFO file for each node
::
:: Some files (workgroup.yml and NFO) are staged in a "staging" directory in the user's %TEMP% folder
:: workgroup.tsbak is renamed to workgroup.zip and all staged files are copied in to the zip file before being deleted
:: tsm maintenace send-logs is used to upload the resulting archive file (workgroup.zip) to a Tableau Technical Support Case
:: If send-logs is not successful, a prompt is displayed notifying to upload to your TAM
::
:: Only change this section if you plan to run the script without prompts, e.g. as a scheduled task
:: Uncomment the following SET lines by deleting the "::" and setting values for case and email
:: *Note: If you are on version 2019.2 or earlier, you will need to set both user and password
:: Please double-check your case number, it should be an 8 digit number
	::SET "silent=Y"
	::SET "case=12345678"
	::SET "email=name@domain.com"
	::SET "user=username"
	::SET password="Your not so secret password."

SET "bindir=%TABLEAU_SERVER_INSTALL_DIR%\packages\bin.%TABLEAU_SERVER_DATA_DIR_VERSION%"
SET "configdir=%TABLEAU_SERVER_DATA_DIR%\data\tabsvc\config\tabadmincontroller_0.%TABLEAU_SERVER_DATA_DIR_VERSION%"
SET "stagingdir=%temp%\staging"
SET "scriptdir=%~dp0"
SET "sys32=%windir%\System32"

FOR /F "usebackq tokens=1,2 delims=,=- " %%G in (`CALL "%sys32%\wbem\wmic" OS GET LocalDateTime /value`) DO (
	@IF %%G==LocalDateTime (SET "localdatetime=%%H")
)

SET "datestamp=%localdatetime:~0,8%_%localdatetime:~8,6%"

SET "backupfile=workgroup_%datestamp%.tsbak"
SET "archivefile=workgroup_%datestamp%.zip"


:: Check if "nopg" or "noupload" was passed to the script
CALL :checkparam %1 %2
	
:: If you are running the script in interactive mode (default), we'll prompt you for the values
	IF NOT "%silent%"=="Y" (
		IF NOT "%noupload%"=="Y" (
			ECHO Before we begin, a Tableau Technical Support case number is needed 
			ECHO for the output file "workgroup.zip" to be automatically uploaded.
			ECHO.
			ECHO If you do not already have a case, you can create one by visiting
			ECHO the customer portal at: https://customer.tableausoftware.com/
			SET /P "openbrowser=Go there now (Y/N)? "
			IF /I "!openbrowser!"=="Y" (
				START "" https://customer.tableausoftware.com/
			)
			ECHO.
			ECHO If you prefer to upload the file to Tableau manually, or it is not possible
			ECHO for the server to make an outbound connection to https://report-issue.tableau.com/
			ECHO leave the case number blank and just hit the enter key.
			IF NOT DEFINED case (SET /P "case=Enter your 8 digit case number: ")
			IF DEFINED case (
				SET "case=!case: =!"
				IF NOT DEFINED email (SET /P "email=Enter your email address: ")
				IF DEFINED email (SET "email=!email: =!")
			)
		)
	)

:: Now that we have all the variables set, let's go ahead and begin

:: Set working directory to user's temp folder
	IF NOT EXIST %stagingdir% (MKDIR %stagingdir%)
	CD /D %stagingdir%

:: Login to TSM
	ECHO.
	CALL :tsmlogin

:: Determine the Tableau backup path
	FOR /F "delims=" %%G in ('tsm configuration get -k basefilepath.backuprestore') DO (SET "backupdir=%%G")

:: Replace forward slashes / with back slashes \
	SET "backupdir=%backupdir:/=\%"

	IF NOT "%nopg%"=="Y" (
	:: Create a pg-only backup
		ECHO %date% %time% - Creating pg-only backup
		CALL tsm maintenance backup --pg-only -f %backupfile%
		Echo.
		ECHO %date% %time% - pg-only backup complete

	:: Change file extension of backupfile from tsbak to zip
		ECHO.
		ECHO %date% %time% - Renaming !backupfile! to !archivefile!
		RENAME "%backupdir%\%backupfile%" "%archivefile%"

	:: remove asset_keys.yml and backup.sql from archivefile (workgroup.zip)
		ECHO.
		ECHO %date% %time% - Removing unneeded files from !archivefile!
		CALL "%bindir%\7z" d -tzip "%backupdir%\%archivefile%" asset_keys.yml backup.sql | "%sys32%\FIND" "ing archive"
	)

:: get workgroup.yml
	ECHO.
	ECHO %date% %time% - Staging workgroup.yml
	COPY "%configdir%\workgroup.yml" .
	ECHO.

:: get NFO files
	ECHO %date% %time% - Generating NFO Files

	FOR /F "usebackq tokens=1,2 delims= " %%G IN (`CALL tsm status -v ^| "%sys32%\findstr" /b node`) DO (
		SET "node=%%G"
		SET "computer=%%H"
		IF "!computer!"=="localhost" (
			SET "computer=%COMPUTERNAME%"
		)
		ECHO !node! !computer! >> servers.txt
	)

	ECHO Found the following servers:
	TYPE servers.txt
	ECHO.

:: For each line in servers.txt, trim to just the server name
	FOR /F "tokens=2 delims=: " %%G in (servers.txt) do (
		:: Run msinfo32 remotely to each server and output servername.nfo
		SET "computer=%%G"
		ECHO %date% %time% - Generating !computer!.nfo
		%comspec% /c "%sys32%\msinfo32" /computer !computer! /nfo !computer!.nfo	
	)

	ECHO.
	ECHO %date% %time% - NFO files complete


:: Put staged files into archivefile (workgroup.zip)
	ECHO.
	ECHO %date% %time% - Add staged files to %archivefile%

	CALL "%bindir%\7z" a -tzip -sdel "%backupdir%\%archivefile%" backups.txt servers.txt workgroup.yml *.nfo | "%sys32%\FIND" "ing archive"

:: Use tsm maintenance send-logs to upload file
:: If email or case are not set, set noupload to "Y"
	IF "!email!" == "" (SET "noupload=Y")

	IF "!case!" == "" (SET "noupload=Y")

	IF "!noupload!" == "Y" (
		CALL :promptupload
	) ELSE (
		ECHO.
		ECHO %date% %time% - Sending %archivefile% to Tableau Support case !case!
		"%comspec%" /c tsm maintenance send-logs --email !email! --case !case! --file "%backupdir%\%archivefile%" --request-timeout 86400
		IF "!ERRORLEVEL!" == "0" (
			ECHO.
			ECHO %date% %time% - File %archivefile% sent successfully
		) ELSE (
			ECHO.
			ECHO %date% %time% - File %archivefile% did not send successfully
			CALL :promptupload
		)
	)

	ECHO.
	ECHO %date% %time% - Script complete

PAUSE
EXIT /B
::End of Main


::Functions defined here

	::Function tsmlogin
		:tsmlogin
		FOR /L %%G IN (1,1,4) DO (
			IF %%G EQU 1 (
				:: On the first iteration through the loop, if username has not already been defined, set it to current user
				IF NOT DEFINED user (SET "user=%USERDNSDOMAIN%\%USERNAME%")
			)

			IF %%G EQU 4 (
				:: On the fourth interation through the loop, notify the user of 3 failed attempts and exit
				ECHO Login failed 3 times, please re-run the script
				PAUSE
				EXIT
			)

			:: If Tableau Server version is 2019.3 or higher, there is no need to login to TSM
			IF %TABLEAU_SERVER_DATA_DIR_VERSION:~0,5% GEQ 20193 EXIT /B

			IF NOT DEFINED user (SET /P "user=username: ")
			ECHO Logging in to TSM as !user!
			ECHO.
			
			IF DEFINED password (
				%comspec% /c tsm login -u !user! -p %password%
			) ELSE (
				%comspec% /c tsm login -u !user!
			)

			:: If tsm login was NOT successful, undefine username
			IF !ERRORLEVEL! NEQ 0 (
				SET "user="
			) ELSE (
				EXIT /B
			)
		)
		EXIT /B
	::End tsmlogin


	::Function promptupload
		:promptupload
		(ECHO Windows explorer should have opened to "%backupdir%" & ECHO. & ECHO Please upload %archivefile% to your TAM.) | "%sys32%\MSG" * /self 2>nul
		ECHO.
		ECHO Please upload "%backupdir%\%archivefile%" to your TAM
		"%WINDIR%\explorer" "%backupdir%"
		EXIT /B
	::End promptupload


	::Function checkparam
		:checkparam
		IF NOT "%~1" == "" (
			IF /I "%~1" == "nopg" (
				SET "nopg=Y"
			) ELSE (
				IF /I "%~1" == "noupload" (
					SET "noupload=Y"
				)
			)
			IF NOT "%~2" == "" (
				CALL :checkparam %2
			)
		)
		EXIT /B
	::End checkparam

::End Functions
