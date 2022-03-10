@ECHO off
SETLOCAL EnableDelayedExpansion
SETLOCAL ENABLEEXTENSIONS

:: Usage
:: collect-tsfiles.bat [param1] [param2] [param3]
:: param1, param2, and param3 allow you to alter certain functionality of the script
:: "nopg" will result in NOT collecting a pg_dump file
:: "noupload" will result in NOT attempting to upload the resulting files directly to Tableau
:: "withlogs" will generate a ziplogs file with the default of 2-days
::
:: This script is for the collection of files needed for the Elite/Premium Support Deployment Review
:: it may be used in other situations where the same informatoin is needed
:: Files Collected: workgroup.pg_dump, workgroup.yml, msinfo32 output from each server in the cluster
::
:: To collect workgroup.yml, the script must be run in an elevated mode (as administrator), this is due to folder permissions and User Access Control
:: To collect workgroup.pg_dump, a pg-only backup is taken as workgroup.tsbak
:: msinfo32 is run from the command line to connect to each server in the cluster and generate the NFO file for each node
::
:: Some files are staged in a "staging" directory in the user's %TEMP% folder
:: tsm maintenace send-logs is used to upload the resulting files to a Tableau Technical Support Case
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
SET "uploadlist=%stagingdir%\uploadlist.txt"

:: Start with a clean stagingdir
	DEL "%stagingdir%\workgroup.yml" > nul 2>&1
	DEL "%stagingdir%\*.txt" > nul 2>&1
	DEL "%stagingdir%\*.nfo" > nul 2>&1

:: set datestamp
	ECHO %date% %time% > "%stagingdir%\starttime.txt"

	FOR /F "tokens=1-3 delims=. " %%G in (%stagingdir%\starttime.txt) do (
		SET "ldate=%%H"
		SET "ltime=%%I"
	)

	SET "ldate=%ldate:/=%"
	SET "ltime=%ltime::=%"

	SET "datestamp=!ldate!_!ltime!"

:: set ouput filenames
	SET "backupfile=workgroup_%datestamp%.tsbak"
	SET "archivefile=workgroup_%datestamp%.zip"
	SET "extrasfile=extras_%datestamp%.zip"
	SET "ziplogsfile=ziplogs_%datestamp%.zip"

:: Determine the Tableau ziplogs path
	FOR /F "delims=" %%G in ('tsm configuration get -k basefilepath.log_archive') DO (SET "ziplogsdir=%%G")
	:: Replace forward slashes / with back slashes \
	SET "ziplogsdir=%ziplogsdir:/=\%"

:: Determine the Tableau backup path
	FOR /F "delims=" %%G in ('tsm configuration get -k basefilepath.backuprestore') DO (SET "backupdir=%%G")
	:: Replace forward slashes / with back slashes \
	SET "backupdir=%backupdir:/=\%"

:: Check if "nopg", "noupload", or "withlogs" was passed to the script
	CALL :checkparam %1 %2 %3

:: If you are running the script in interactive mode (default), we'll prompt you for the values
	IF NOT "%silent%"=="Y" (
		IF NOT "%noupload%"=="Y" (
			ECHO Before we begin, a Tableau Technical Support case number is needed 
			ECHO for the output file^(s^) to be automatically uploaded.
			ECHO.
			ECHO If you do not already have a case, you can create one by visiting
			ECHO the customer portal at: https://customer.tableausoftware.com/
			SET /P "openbrowser=Go there now [Y/N]? "
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
	IF NOT EXIST "%stagingdir%" (MKDIR "%stagingdir%")
	CD /D "%stagingdir%"

:: Login to TSM
	ECHO.
	CALL :tsmlogin

:: get licenseinfo
	%comspec% /c serveractutil -view > licinfo.txt
	%comspec% /c atrdiag -product "Tableau Desktop" > td_atrdiag.txt
	%comspec% /c atrdiag -product "Tableau Server" > ts_atrdiag.txt

:: get NFO files
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

	ECHO %date% %time% - Generating NFO Files
	ECHO.

:: For each line in servers.txt, trim to just the server name
	FOR /F "tokens=2 delims=: " %%G in (servers.txt) do (
		:: Run msinfo32 remotely to each server and output servername.nfo
		SET "computer=%%G"
		ECHO %date% %time% - Generating !computer!.nfo
	)
		%comspec% /c "%sys32%\msinfo32" /computer !computer! /nfo !computer!.nfo	

	ECHO.
	ECHO %date% %time% - NFO files complete


:: Put files into extras.zip
	ECHO.
	ECHO %date% %time% - Add files to %extrasfile%
	CALL powershell compress-archive -path '%configdir%\workgroup.yml','%stagingdir%\*.txt','%userprofile%\.tableau\tsm\tsm.log','%stagingdir%\*.nfo' -destinationpath '%ziplogsdir%\%extrasfile%'
	DEL "%stagingdir%\*.nfo"
	DEL "%stagingdir%\*.txt"

	ECHO "%ziplogsdir%\%extrasfile%" > uploadlist.txt

:: Should we create a pg_only backup?
	IF NOT "%nopg%"=="Y" (
	:: Create a pg-only backup
		ECHO.
		ECHO %date% %time% - Creating pg-only backup
		CALL tsm maintenance backup --pg-only -f %backupfile%
		ECHO.
		ECHO %date% %time% - pg-only backup complete

		ECHO "%backupdir%\%backupfile%" >> %uploadlist%
	)

:: Generate ziplogs
	IF "!withlogs!" == "Y" (
		ECHO.
		ECHO %date% %time% - Generating ziplogs
		CALL tsm maintenance ziplogs --with-msinfo -f "%ziplogsfile%"

		ECHO.
		ECHO %date% %time% - Ziplogs complete

		ECHO "%ziplogsdir%\%ziplogsfile%" >> %uploadlist%
	)

:: Use tsm maintenance send-logs to upload file
:: If email or case are not set, set noupload to "Y"
	IF "!email!" == "" (SET "noupload=Y")

	IF "!case!" == "" (SET "noupload=Y")

	IF "!noupload!" == "Y" (
		CALL :promptupload
	) ELSE (
		CALL :uploadFiles
	)

	DEL "%stagingdir%\uploadlist.txt"
	ECHO.
	ECHO %date% %time% - Script complete

PAUSE
EXIT /B
::End of Main


::Functions defined here
	
	:: Function uploadFiles
		:uploadFiles
		FOR /F "delims=" %%G in (%uploadlist%) do (
			ECHO.
			ECHO %date% %time% - Sending %%G to Tableau Support case !case!
			"%comspec%" /c tsm maintenance send-logs --email !email! --case !case! --file %%G --request-timeout 86400
			IF "!ERRORLEVEL!" == "0" (
				ECHO.
				ECHO %date% %time% - File %%G sent successfully
			) ELSE (
				ECHO.
				ECHO %date% %time% - File %%G did not send successfully
				CALL :promptupload %%G
			)
 		)
 		EXIT /B
	::End uploadFiles


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
		IF [%1] == [] (
			FOR /F "delims=" %%G in (%uploadlist%) do (
				CALL :promptupload %%G
			)
		) ELSE (
			SET filename=%1
			FOR %%A in (!filename!) do (
			    SET "folder=%%~dpA"
			    SET "name=%%~nxA"

				(ECHO Windows explorer should have opened to "%%folder%%" & ECHO. & ECHO Please upload "%%name%%" to your TAM.) | "%sys32%\MSG" * /self 2>nul
				ECHO.
				ECHO Please upload !filename! to your TAM
				"%WINDIR%\explorer" /select,!filename!
			)
		)
		EXIT /B
	::End promptupload


	::Function checkparam
		:checkparam
		IF NOT [%~1] == [] (
			IF /I "%~1" == "nopg" (
				SET "nopg=Y"
			) ELSE IF /I "%~1" == "noupload" (
					SET "noupload=Y"
			) ELSE IF /I "%~1" == "withlogs" (
					SET "withlogs=Y"
			)
			IF NOT [%~2] == [] (
				::SHIFT
				CALL :checkparam %~2 %~3
			)
		)
		EXIT /B
	::End checkparam

::End Functions
