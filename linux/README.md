# collect-tsfiles.sh

[collect-tsfiles.sh](https://github.com/TLarson-Tableau/collect-tableauserver-files/blob/master/linux/collect-tsfiles.sh) will create a pg-only backup of Tableau Server as workgroup.tsbak. workgroup.tsbak is then renamed to workgroup.zip where workgroup.yml, servers.txt, and hostname.nfo files are added to the archive. If the "noupload" option is NOT provided and both case_number and email_address are provided and Tableau Server can create an outbound connection to https://report-issue.tableau.com/, then workgroup.zip will be automatically uploaded to the Tableau Technical Support Case.

## Prerequisites:
- template.nfo
- Linux Server
- Tableau Server 2018.2 or later
- Case Number and email address (for file upload)
- Outbound connection to https://report-issue.tableau.com/ (for file upload)

## Usage:
Copy both collect-tsfiles.sh and template.nfo to a location on the TSM Controller node of your Tableau Server cluster--this the initial node unless it was moved at some point. The location you copy these files to will be a staging ground for the NFO files that are created; these are typically small, about 5k in size.

Run collect-tsfiles.sh with source and any desired/required parameters.

**[source](https://bash.cyberciti.biz/guide/Source_command)**\
 The script must be sourced with either "source" or "." in order to run properly\
 Sourcing causes the script to run in the current shell rather than a new one\
 Running in the context of the current shell is necessary to access the shell variable $install_dir

```
source collect-tsfiles.sh [-c case_number] [-e email_address] [-o options]
```

<dl>
 <dt><b>case_number</b></dt>
 <dd>8-digit Tableau Technical Support case number--needed for file upload</dd>
 
 <dt><b>email_address</b></dt>
 <dd>needed for file upload</dd>

<dl>
 <dt><b>options</b></dt>
 <dd>
  <dl>
   <dt><b>nopg</b></dt>
   <dd>Tells the script not to geneate workgroup.pg_dump. Under normal operation, this option should not be passed. You might pass this option if the script is only being run to collect NFO files, or your organization does not allow workgroup.pg_dump to be provided.</dd>
   <dt><b>noupload</b></dt>
   <dd>Tells the script not to upload the output file (workgroup.zip) to a Tableau Technical Support case. Only use this option if you know that *tsm maintenance send-logs* will not succeed due to infrastructure limitations.</dd>
  </dl>
 </dd>
</dl>

**Example**
```
source collect-tsfiles.sh -c 12345678 -e user@domain.com -o nopg noupload
```

## Interactive Mode:

If no options are passed, the script will run in interactive mode and prompt for input
- case_number
- email_address

## Non-interactive Mode:
In order to generate an NFO output file for each server in the cluster the script connects remotely via ssh which requires authentication. If public key authentication is setup separately and you are able to authenticate to each server without a password, then you can setup the script to run non-interactively
