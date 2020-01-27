The main script is [collect-tsfiles.sh](https://github.com/TLarson-Tableau/collect-tableauserver-files/blob/master/linux/collect-tsfiles.sh), this will create a pg-only backup of Tableau Server as workgroup.tsbak. workgroup.tsbak will be renamed to workgroup.zip. workgroup.yml and System Info (NFO) files are added to the workgroup.zip archive. If the "noupload" option is NOT passed, both case_number and email_address are provided, and  Tableau Server can create an outbound connection to https://report-issue.tableau.com/ then workgroup.zip will be automatically uploaded to the Tableau Technical Support Case.

## Prerequisites:
- Linux Server
- Tableau Server 2018.2 or later
- Case Number and email address (for file upload)
- Outbound connection to https://report-issue.tableau.com/ (for file upload)

## Usage:
```
source collect-tsfiles.sh [-c case_number] [-e email_address] [-o options]
```
[source](https://bash.cyberciti.biz/guide/Source_command)\
 The script must be sourced with either "source" or "." in order to run properly\
 Sourcing causes the script to run in the current shell rather than a new one\
 Running in the context of the current shell is necessary to access the shell variable $install_dir\

-c case_number\
&nbsp;&nbsp;&nbsp;&nbsp;8-digit Tableau Technical Support case number--needed for file upload\

-e email_address\
&nbsp;&nbsp;&nbsp;&nbsp;needed for file upload\

-o options\
&nbsp;&nbsp;&nbsp;&nbsp;nopg\
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;tells the script not to geneate workgroup.pg_dump\

&nbsp;&nbsp;&nbsp;&nbsp;noupload\
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;tells the script not to upload the output file (workgroup.zip) to a Tableau Technical Support case\


## Interactive Mode:

If no options are passed, the script will run in interactive mode and prompt for input
- case_number
- email_address

## Non-interactive Mode:
In order to generate an NFO output file for each server in the cluster the script connects remotely via ssh which requires authentication. If public key authentication is setup separately
and you are able to authenticate to each server without a password, then you can setup the script to run non-interactively
