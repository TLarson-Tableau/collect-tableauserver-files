## Purpose
The purpose of the collect-tsfiles scripts is to collect specific information that Tableau Technical Support will use for tracking environmental growth and changes, as well as to generate a workbook for the Elite/Premium Support Deployment Review.

## Windows and Linux
There are two different scripts, one each for Windows and Linux. The output from both is the same, a workgroup.zip file which contains workgroup.pg_dump (a dump of the PostegreSQL repository), workgroup.yml (the current running config for Tableau Server), servers.txt (a list of servers in the Tableau Server cluster, and their node IDs), and a collection of NFO files, one for each server in the cluster.

### More Info
- [Windows](https://github.com/TLarson-Tableau/collect-tableauserver-files/tree/master/windows)
- [Linux](https://github.com/TLarson-Tableau/collect-tableauserver-files/tree/master/linux)
