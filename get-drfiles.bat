:: This script is for the collection of files needed for the Elite/Premium Support Deployment Review
:: it may be used in other situations where the same informatoin is needed
:: Files Collected: workgroup.pg_dump, workgroup.yml, msinfo32 output from each server in the cluster
::
:: To collect workgroup.yml, the script must be run in an elevated mode (as administrator), this is due to folder permissions and User Access Control
:: To collect workgroup.pg_dump, we first look in the configured backup location for an existing backup
:: If one exsits we prompt to use it to extract the pg_dump file, otherwise we prompt to take a postgres-only backup
:: Choosing not to use an exsiting backup and not to create a new one, will result in the collection of only the workgroup.yml and NFO files
:: msinfo32 is run from the command line to connect to each server in the cluster and generate the NFO file for each node
::
:: All files are stored in a "staging" directory in the user's %TEMP% folder and then packaged as a zip
:: The exception to this is if the user chooses to create a postgres-only backup, in which case we use the created workgroup.tsbak archive

@ECHO off
SETLOCAL EnableDelayedExpansion
SETLOCAL ENABLEEXTENSIONS
SET "USER=%USERDNSDOMAIN%\%USERNAME%"
SET "bindir=%TABLEAU_SERVER_DATA_DIR%\packages\bin.%TABLEAU_SERVER_DATA_DIR_VERSION%"
SET "configdir=%TABLEAU_SERVER_DATA_DIR%\data\tabsvc\services\tabadmincontroller_0.%TABLEAU_SERVER_DATA_DIR_VERSION%\config"
SET "stagingdir=%temp%\staging"
SET "archivefile=%stagingdir%\workgroup.zip"
SET "choice= "

::Set working directory to user's temp folder
	IF NOT EXIST %stagingdir% (MKDIR %stagingdir%)
	CD /D %stagingdir%

::Login to TSM
	CALL :tsmlogin

::Determine the Tableau backup path
	FOR /F "delims=" %%G in ('tsm configuration get -k basefilepath.backuprestore') DO (SET "backupdir=%%G")

	::Replace forward slashes / with back slashes \
	SET "backupdir=%backupdir:/=\%"

::Get the workgroup.pg_dump file
	ECHO Staging workgroup.pg_dump
	ECHO We can get this from an existing backup if present on the server
	ECHO Checking %backupdir% for .tsbak files

	::Search path %backupdir% for any backup (.tsbak) files
	::Output file-date file-time and filename to staging\backups.txt
		FORFILES /P "%backupdir%" /M *.tsbak /C "%comspec% /c echo @FDATE @FTIME - @File" 2> nul| FINDSTR /V "^$" > backups.txt

	::Iterate through backups.txt, counting and outputting each line
		FOR /F "usebackq delims=" %%G IN ("%stagingdir%\backups.txt") DO (
			SET /A "backupcount+=1"
			ECHO [!backupcount!] - %%G
		)

	::If backup (.tsbak) files are found, prompt user to select one
	::otherwise generate a pg-only backup
		IF DEFINED backupcount (CALL :choosebackup) ELSE (CALL :newbackup)
		CALL :extractdump !backupfile!
::pgdumpcomplete

::get workgroup.yml
	ECHO Copying workgroup.yml to staging
	COPY "%configdir%\workgroup.yml" .
	ECHO.

::get NFO files
	:: Run tsm status and output any line that begins with "node" to servers.txt
	:: Format will be:
	:: node1: computername1
	:: node2: comptuername2

	CALL tsm status -v | findstr /b node > servers.txt

	ECHO Generating NFO Files
	ECHO Found the following servers:
	TYPE servers.txt
	ECHO.

	:: For each line in servers.txt, trim to just the server name
	FOR /F "tokens=2 delims=: " %%G in (servers.txt) do (
		:: Run msinfo32 remotely to each server and output servername.nfo
		SET "computer=%%G"
		IF !computer!==localhost (SET "computer=%COMPUTERNAME%")
	  ECHO Generating !computer!.nfo
	  %comspec% /c msinfo32 /computer !computer! /nfo !computer!.nfo
	)

::generate archive file
	CALL "%bindir%\7z" a -tzip -sdel "%archivefile%" backups.txt servers.txt workgroup.yml workgroup.pg_dump *.nfo

::Prompt user to upload files
	(ECHO Windows explorer should have opened to "%stagingdir%" & ECHO. & ECHO Please upload workgroup.zip to your TAM.) | MSG * /self 2>nul
	ECHO Please upload "%archivefile%" to your TAM
	"%WINDIR%\explorer" "%stagingdir%"
)

::Upload archive workgroup.zip to Egnyte


PAUSE
EXIT /B 0
::End of Main


::Functions defined here

	::Function tsmlogin
		:tsmlogin
		FOR /L %%G IN (1,1,4) DO (
			IF %%G EQU 4 (
				ECHO Login failed 3 times, please re-run the script
				PAUSE
				GOTO EOF
			)

			::If Tableau Server version is 2019.3 or higher, there is no need to login to TSM
			IF %TABLEAU_SERVER_DATA_DIR_VERSION:~0,5% GEQ 20193 EXIT /B

			ECHO Logging in to TSM
			IF NOT DEFINED USER (SET /P "USER=username: ")

			%comspec% /c tsm login -u !USER!

			::If tsm login was NOT successful, undefine username
			IF !ERRORLEVEL! NEQ 0 (
				SET "USER="
				) ELSE (
				EXIT /B
			)
		)
		EXIT /B
	::End tsmlogin


	::Function choosebackup
		:choosebackup
		FOR /L %%G IN (1,1,4) DO (
		  IF %%G EQU 4 (
		    ECHO Too many bad attempts
		    EXIT /B 1
		  )
		  SET /P choice="Choose an existing backup [1-!backupcount!] or (S)kip: "
		  ECHO !choice!|FINDSTR /X /R [1-9][0-9]* >nul
		  IF !ERRORLEVEL! EQU 0 (
		    FOR /F "usebackq tokens=4 delims=- " %%I IN ("%stagingdir%\backups.txt") DO (
					SET /A "backupfileindex+=1"
					IF !backupfileindex! EQU !choice! (
						SET backupfile=%%I
						SET backupfile=!backupfile:"=!
					)
				)

		    EXIT /B
		  	) ELSE (
		    IF /I !choice!==s (
		      ECHO Will generate new file
		      CALL :newbackup
		      EXIT /B
		    )
		  )
		  ECHO Invalid input
		)
		EXIT /B
	::End choosebackup


	::Function newbackup
		:newbackup
		CALL tsm maintenance backup --pg-only -f workgroup
		IF !ERRORLEVEL! EQU 0 (
			SET "backupfile=workgroup.tsbak"
		)		
		EXIT /B
	::End newbackup


	::Function extractdump
		:extractdump
		CALL "%bindir%\7z" -tzip e "%backupdir%\%~1" workgroup.pg_dump
		EXIT /B
	::End extractdump

::End Functions
