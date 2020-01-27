# collect-tsfiles

## Purpose
The purpose of the collect-tsfiles scripts is to collect specific information that Tableau Technical Support will use for tracking environmental growth and changes, as well as to generate a workbook for the Elite/Premium Support Deployment Review.

## What is collected
- **workgroup.pg_dump**\
Dump of the Tableau Server repository (PostgreSQL) which contains information about why is stored in Tableau Server (users, sites, projects, workbooks), as well as information about when and what views have been accessed and how long they took to load. Additional information about the [repository](https://help.tableau.com/current/server/en-us/server_process_repository.htm).

- **workgroup.yml**\
Contains the default Tableau Server configuration keys and values, along with any custom settings that were made with tsm configuration set.

- **servers.txt**\
List of servers in the Tableau Server cluster along with their node ID in the following format.\
Node1: Server1\
Node2: Server2

- **NFO Files**\
NFO files are originally the output of the Windows msinfo32.exe program, which can export System (hardware and software) info. We use this information to understand the specific OS version and build, number and speed of CPUs, amount of RAM, size of disks, etc.\
\
The linux script collects the same system info a builds its own NFO file, which is a simply XML formatted document containing the info.

## Windows and Linux
There are two different scripts, one each for Windows and Linux. The output from both is the same, a workgroup.zip file which contains the above files.

### More Info
- Windows - [collect-tsfiles.bat](https://github.com/TLarson-Tableau/collect-tableauserver-files/tree/master/windows)
- Linux - [collect-tsfiles.sh](https://github.com/TLarson-Tableau/collect-tableauserver-files/tree/master/linux)
