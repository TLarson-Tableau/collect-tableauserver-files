# get-deploymentreview-files

The main script is [get-drfiles.bat](https://github.com/TLarson-Tableau/get-deploymentreview-files/blob/master/get-drfiles.bat), this will create a staging directory in %temp%\staging to copy the workgroup.pg_dump, workgroup.yml, and System Info (NFO) files. These files will be packaged up in workgroup.zip, which can then be uploaded to your TAM via Egnyte.

Putty SFTP (psftp.exe) is included should you decide to use it for uploading to egnyte.
In a future version of the get-drfiles.bat script, psftp.exe will be called directly to upload workgroup.zip automatically.
Putty License: https://www.chiark.greenend.org.uk/~sgtatham/putty/licence.html

Usage:
Place [get-drfiles.bat](https://github.com/TLarson-Tableau/get-deploymentreview-files/blob/master/get-drfiles.bat) and [psftp.exe](https://github.com/TLarson-Tableau/get-deploymentreview-files/blob/master/psftp.exe) in a directory of your chosing on the Initial node (or the node running the TSM Controller)
Run get-drfiles.bat as an administrator
  1. Right click and run as administrator
  2. Run a command prompt as administrator and execute the script
  
The script is interactive and will prompt for input along the way
