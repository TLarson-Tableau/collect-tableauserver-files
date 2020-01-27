#!/bin/bash

#####################
##      Usage      ##
#####################
#
# source collect-tsfiles.sh [-c case_number] [-e email_address] [-o options]
#
# -c case_number
#		8-digit Tableau Technical Support case number--needed for file upload
#
# -e email_address
#		needed for file upload
#
# -o options
#	nopg
#		tells the script not to geneate workgroup.pg_dump
#
#	noupload
#		tells the script not to upload the output file (workgroup.zip) to a Tableau Technical Support case
#
# Sourcing
# The script must be sourced with either "source" or "." in order to run properly
# sourcing causes the script to run in the current shell rather than a new one
# Running in the context of the current shell is necessary to access the shell variable $install_dir
#
# This script is for the collection of files needed for the Elite/Premium Support Deployment Review
# it may be used in other situations where the same informatoin is needed
# Files Collected: workgroup.pg_dump, workgroup.yml, servers.txt and system info (NFO files) from each server in the cluster
#
# Running Non-Interactive
# By default the script requires interactivity. In order to generate an NFO output file for each server in the cluster
# the script connects remotely via ssh which requires authentication. If public key authentication is setup separately
# and you are able to authenticate to each server without a password, then you can setup the script to run non-interactively


######################
## Define Functions ##
######################

function createnfo {
	# This function collects a bunch of system info (hostname, RAM, CPU, drive info, etc.) and writes to an XML formatted .nfo file

	host=$1

	local UTCDATE=$(date --utc "+%x %T")

	declare -A LSB
	while IFS=':' read key value; do
		value=$(echo $value | awk '{$1=$1};1')
		LSB[$key]=$value
	done <<< "$(lsb_release -a 2> /dev/null)"

	local DESCRIPTION=${LSB[Description]}
	local RELEASE=${LSB[Release]}
	local DISTRIBUTOR=${LSB[Distributor ID]}

	declare -A LSCPU
	while IFS=':' read key value; do
		value=$(echo $value | awk '{$1=$1};1')
		LSCPU[$key]=$value
	done <<< "$(lscpu)"

	local ARCHITECTURE=${LSCPU[Architecture]}
	local CPU=${LSCPU[Model name]}
	local CORES=${LSCPU[Core(s) per socket]}
	local SOCKETS=${LSCPU[Socket(s)]}

	local PROCXML=''
	i=1
	while [[ $i -le $SOCKETS ]]; do
		VAR="<Data>\n<Item><![CDATA[Processor]]></Item>\n<Value><![CDATA[$PROCESSOR]]></Value>\n</Data>\n"
		((i = i+1))
		PROCXML+=$VAR
	done

	local MHZ=${LSCPU[CPU MHz]}
	local MHZ=$(printf "%.0f\n" $MHZ)
	
	local VCPUS=${LSCPU[CPU(s)]}
	local LCPUS=$(expr $VCPUS / $SOCKETS )

	local PROCESSOR="$CPU, $MHZ MHz, $CORES Core(s), $LCPUS Logical Processor(s)"

	local BIOS_Info=$(echo $(cat /sys/class/dmi/id/bios_version), $(cat /sys/class/dmi/id/bios_date))
	local System_Manufacturer=$(cat /sys/class/dmi/id/sys_vendor)

	while read key total used free shared buff available; do 
		if [[ "$key" == "Mem:" ]]; then
			RAMKB="$total"
			RAMGB=$(awk "BEGIN {print ($RAMKB/1000000)}")

			AVAILKB=$available
			AVAILGB=$(awk "BEGIN {print ($RAMKB/1000000)}")
		fi

		if [[ $key == "Swap:" ]]; then
			VRAMKB=$total
				if [ $VRAMKB -gt 0 ]; then
					VRAMGB=$(awk "BEGIN {print ($VRAMKB/1000000)}")
				else
					VRAMGB=0
				fi

			VRAMFREEKB=$free
				if [ $VRAMFREEKB -gt 0 ]; then
					VRAMFREEGB=$(awk "BEGIN {print ($VRAMFREEKB/1000000)}")
				else
					VRAMFREEGB=0
				fi
		fi
	done <<< "$(free --kilo | tail -2)"

	local drivearray=()
	local drivexml=''
	local drivelinexml=''

	while IFS= read -r line; do
		drivearray+=("$line")
	done < <(df -B1 -T -x tmpfs -x devtmpfs | tail -n +2)

	for i in "${drivearray[@]}"; do	
		drive=$(echo $i | awk '{print $7}')
		description=""
		compressed=""
		fs=$(echo $i | awk '{print $2}')
		free=$(echo $i | awk '{print $5}')
		vname=""
		vserial=""

		driveb=$(echo $i | awk '{print $3}')
		drivekb=$(awk "BEGIN {print ($driveb/1024)}")
		drivemb=$(awk "BEGIN {print ($drivekb/1024)}")
		drivegb=$(awk "BEGIN {print ($drivemb/1024)}")

		drivesize="$drivegb GB ($(printf "%'d" $driveb) bytes)"

		spaceb=$(echo $i | awk '{print $5}')
		spacekb=$(awk "BEGIN {print ($spaceb/1024)}")
		spacemb=$(awk "BEGIN {print ($spacekb/1024)}")
		spacegb=$(awk "BEGIN {print ($spacemb/1024)}")

		freespace="$spacegb GB ($(printf "%'d" $spaceb) bytes)"

		if ! [[ -z $drivexml ]]; then
			drivelinexml+="<Data>\n<Item><![CDATA[]]></Item>\n<Value><![CDATA[]]></Value>\n</Data>\n"
		fi

		drivelinexml+="<Data>\n<Item><![CDATA[Drive]]></Item>\n<Value><![CDATA[$drive]]></Value>\n</Data>\n"
		drivelinexml+="<Data>\n<Item><![CDATA[Description]]></Item>\n<Value><![CDATA[$description]]></Value>\n</Data>\n"
		drivelinexml+="<Data>\n<Item><![CDATA[Compressed]]></Item>\n<Value><![CDATA[$compressed]]></Value>\n</Data>\n"
		drivelinexml+="<Data>\n<Item><![CDATA[File System]]></Item>\n<Value><![CDATA[$fs]]></Value>\n</Data>\n"
		drivelinexml+="<Data>\n<Item><![CDATA[Size]]></Item>\n<Value><![CDATA[$drivesize]]></Value>\n</Data>\n"
		drivelinexml+="<Data>\n<Item><![CDATA[Free Space]]></Item>\n<Value><![CDATA[$freespace]]></Value>\n</Data>\n"
		drivelinexml+="<Data>\n<Item><![CDATA[Volume Name]]></Item>\n<Value><![CDATA[$vname]]></Value>\n</Data>\n"
		drivelinexml+="<Data>\n<Item><![CDATA[Volume Serial Number]]></Item>\n<Value><![CDATA[$vserial]]></Value>\n</Data>\n"
		
		drivexml+=$drivelinexml
		drivelinexml=""
	done

	declare -A subs
	subs=(
		[%%Created%%]=$UTCDATE
		[%%OS_Name%%]=$DESCRIPTION
		[%%Version%%]=$RELEASE
		[%%Other_OS%%]="Not Available"
		[%%OS_Manufacturer%%]=$DISTRIBUTOR
		[%%System_Name%%]=$host
		[%%System_Manufacturer%%]=$System_Manufacturer
		[%%System_Model%%]="Not Available"
		[%%System_Type%%]=$ARCHITECTURE
		[%%System_SKU%%]="Not Available"
		[%%Processors%%]=$PROCXML
		[%%BIOS_Info%%]=$BIOS_Info
		[%%SMBIOS_Version%%]="Not Available"
		[%%BIOS_Mode%%]="Not Available"
		[%%BaseBoard_Manufacturer%%]="Not Available"
		[%%BaseBoard_Model%%]="Not Available"
		[%%BaseBoard_Name%%]="Not Available"
		[%%Platform_Role%%]="Not Available"
		[%%Secure_Boot%%]="Not Available"
		[%%PCR7_Configuration%%]="Not Available"
		[%%Boot_Device%%]="Not Available"
		[%%Locale%%]=$LANG
		[%%Abstraction_Layer%%]="Not Available"
		[%%User_Name%%]=$USER
		[%%Time_Zone%%]=$(date "+%Z (%:::z)")
		[%%Installed_RAM%%]="Not Available"
		[%%Total_RAM%%]="$RAMGB GB"
		[%%Available_RAM%%]="$AVAILGB GB"
		[%%Total_VRAM%%]="$VRAMGB GB"
		[%%Available_VRAM%%]="$VRAMFREEGB GB"
		[%%Page_File_Space%%]="Not Available"
		[%%Page_File%%]="Not Available"
		[%%Drives%%]=$drivexml
	)

	cp template.nfo $host.nfo

	for i in "${!subs[@]}"; do
		search=${i}
		replace=${subs[$i]}
		sed -i 's|'"$search"'|'"$replace"'|' $host.nfo
	done

	cat $host.nfo
} # end function createnfo

function isIPaddress {
	local  ip=$1
	local  stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		local IFS='.'
		ip=($ip)
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
			&& ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]		
	fi
	return $?
} # end function isIPaddress

function shortName {
	read -d . shortname <<< $1
	echo $shortname
} # end function shortName

function usage {
	echo usage: collect-tsfiles.sh [-c case_number] [-e email_address] [-o option]
	echo possible options
	echo -e '\t'nopg
	echo -e '\t'noupload
} #end function usage

function checkInput {
	IFS='-' read -a array <<< "$@"

	declare -A input

	for element in "${array[@]}"; do
		if [[ $element ]]; then
			while read option parameter; do
				option=${option,,}
				parameter=${parameter,,}
				input["$option"]="$parameter"
				case "$option" in
					h)
						usage
						exit
						;;
					c)
						if ! [[ $parameter =~ ^[0-9]{8}$ ]]; then
							echo Please enter a valid case number \(8-digits\)
							usage
							exit
						else
							case="$parameter"
						fi
						
						;;
					e)
						if ! [[ $parameter =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
							echo Please enter a valid email address
							usage
							exit
						else
							email="$parameter"
						fi
						
						;;
					o)
						if ! [[ $parameter =~ ^(nopg|noupload|nopg noupload|noupload nopg)$ ]]; then
							echo Please enter a valid option
							usage
							exit
						else
							options="$parameter"
						fi
						;;
					*)
						echo unknown option -- $option
						usage
						exit
						;;
				esac
			done <<< $element
		fi
	done
} # end function checkInput

#$(echo $(hostname -s) | tr '[:upper:]' '[:lower:]')
function tolower {
	echo $(echo $1 | tr '[:upper:]' '[:lower:]')
}

######################
## End of functions ##
######################

# Beginning of Main
# Execute in a subshell to avoid creating shell variables
(

#####################################
##   User configurable variables   ##
#####################################
#
# The remoteuser variable is used to ssh to the other hosts in the cluster
# The current logged-in user is used by default, but can be overridden here
	remoteuser=$USER
#
#####################################
## End user configurable variables ##
#####################################


# Enable extended globbing
shopt -s extglob

# Check the parameters that were passed to the script at runtime
# if nopg was passed, then we don't create a pg-only backup
# if noupload was passed, then we don't attempt to upload workgroup.zip via tsm maintenance send-logs

checkInput "$@"

if [[ -z $case && ! $options =~ "noupload" ]]; then
	read -p "Enter your 8-digit case number: " case
	case=$(echo $case | sed 's/^[[:space:]]*//')
	if ! [[ -z $case ]]; then
		if [[ -z $email ]]; then
			read -p "Enter your email address: " email
			email=$(echo $email | sed 's/^[[:space:]]*//')
		fi
	fi	
fi

#####################################
## Define variables for the script ##
#####################################
#
# Since many of the Tableau Server directories include the version number, we have to determine 
# Fortunately there are some GLOBAL and SHELL variables available that we can leverage for this

#lowerlocalhost=$(tolower $(hostname -s))
lowerlocalhost=$(echo $(hostname -s) | tr '[:upper:]' '[:lower:]')
ymldir="$TABLEAU_SERVER_DATA_DIR/data/tabsvc/config/tabadmincontroller_0.$TABLEAU_SERVER_DATA_DIR_VERSION"
bindir="$install_dir/packages/bin.$TABLEAU_SERVER_DATA_DIR_VERSION"
backupdir="$(tsm configuration get -k basefilepath.backuprestore)"
backupfile="workgroup.tsbak"
archivefile="workgroup.zip"
serverlist="servers.txt"

#tsm status -v | grep node > $serverlist

# If this is a single-node Tableau Server installation, tsm status -v returns localhost in place of hostname
# Update serverlist to include the local hostname rather than "localhost"
sed -i "s/localhost/$(hostname)/g" $serverlist

# Read through serverlist and generate NFO files 
declare -A nodes
while read -r node host; do
	read -d : node <<< $node

	#lowerhost=$(tolower $(shortName $host))
	lowerhost=$(echo $(shortName $host) | tr '[:upper:]' '[:lower:]')

	if [[ $lowerhost == $lowerlocalhost ]]; then
		echo Create NFO file for localhost
		createnfo $host > $host.nfo
	else
		echo Create NFO file for $host
		echo Connecting to $host

		cat template.nfo | ssh $remoteuser@$host "cat > template.nfo; $(declare -f createnfo); createnfo $host" > $host.nfo
	fi
done < "$serverlist"

if ! [[ $options =~ "nopg" ]]; then
#if ! [[ $nopg ]]; then
	echo Create a pg-only backup
	tsm maintenance backup --pg-only --file $backupfile --request-timeout 26400
	if [[ $? -ne 0 ]]; then
		result="Backup failed. Please work with your TAM on another way to collect workgroup.pg_dump.\n"
	else
		# We don't need asset_keys.yml, backup.sql, or pg_backup_metadata.json, so remove from archive
		echo Remove asset_keys.yml, backup.sql, or pg_backup_metadata.json from $backupfile
		"$bindir/7z" d -tzip "$backupdir/$backupfile" asset_keys.yml backup.sql pg_backup_metadata.json | grep archive

		echo Rename $backupfile to $archivefile
		mv "$backupdir/$backupfile" "$backupdir/$archivefile"
	fi
else
	result="The \"nopg\" option was passed to the script. Please work with your TAM on another way to collect workgroup.pg_dump.\n"
fi

# Add workgroup.yml to archive
echo Add workgroup.yml to $archivefile
"$bindir/7z" a -tzip "$backupdir/$archivefile" "$ymldir/workgroup.yml" | grep archive

# Add servers.txt and NFO files to archive, excluding template.nfo
echo Add servers.text and NFO files to $archivefile
"$bindir/7z" a -tzip "$backupdir/$archivefile" *.nfo servers.txt '-x!template.nfo' | grep archive

if [[ ! $options =~ "noupload" && $case && $email ]]; then
	echo Send $archivefile to case\: $case
	#tsm maintenance send-logs -f "$backupdir/$archivefile" -c $case -e $email --request-timeout 26400
	if [[ $? -ne 0 ]]; then
		result+="send-logs failed. Please work with your TAM to find another way to deliver the file.\n"
	fi
else
	result+="The \"noupload\" option was passed to the script. Please work with your TAM to find another way to deliver the file.\n"
fi

echo $result
)
