#!/bin/bash

# Global Variables 

tempDir="/tmp/vmAgentInstaller"
appDServer=
vCACIaasServer=
vCACCAFEServer=
arch=
distro=
checkCert=
timeout=
java=
interactive=true

# Generate Error
Error()
{
	input="$*"
	
	echo "#######################################################################"
	echo "                           !!! ERROR !!!"
	echo "$input"
	echo "Installation unable to continue!"
	echo "#######################################################################"
	exit 1
}
# Checks to see if a particular command is available on the OS
cmdExist()
{
	input="$*"
	
	if type "$input" > /dev/null 2>&1
	then
		return 0
	else
		return 1
	fi
}

# Determine if apt-get exists, this will be used to bootstrap further needed commands
if cmdExist "apt-get"; then
	aptget=true
else
	aptget=false
fi

# Use apt-get (if available) to install a command if it isn't already available
installCommand()
{
	command="$*"
	if ! cmdExist "$command"; then
		if [ $aptget = "true" ]; then
			echo "################################################"
			echo "# '$command' missing. Installing"
			echo "################################################"
			apt-get -y install $command
			if [ $? -ne 0 ]; then
				Error "Unable to install '$command'"
			else
				echo "Successfully installed '$command'"
			fi
		else
			Error "Missing dependency: '$command'"		
		fi
	fi	
}

# Usage Output
Usage()
{
	echo ""
	echo "Installs agents for vCloud Automation Center and / or Application Services."
	echo ""
	echo "Default mode is interactive.  However, all parameters can be passed from"
	echo "the command line with the options listed below."
	echo ""
	echo "  OPTIONS:"
	echo ""
	echo "  -i <Server>          Hostname/IP of vCloud Automation Center IaaS Server"
	echo "  -a <Server>          Hostname/IP of Application Services Server"
	echo "  -c <Server>          Hostname/IP of vCloud Automation Center"
	echo "                       Manager Services Server"
	echo "  -s <true/false>      Enforce certificate checking when"
	echo "                       downloading vCloud Automation Center"
	echo "                       Agent from Manager Service Server (Default false)"
	echo "  -t <seconds>         Timeout for download attempts (Default 300)"
	echo "  -j <true/false>      Install Java JRE Runtime (Default false)"	
	echo "  -n                   Disable Interactive Mode"	
	echo "  -u                   Uninstall gugent/agent from template"
	echo ""
	echo "Some values are inferred by the OS.  If you'd like to override them use"
	echo "the overrides listed below."
	echo ""
	echo "  OVERRIDES:"
	echo "  -r <architecture>         Architecture, either 'x86_64' or 'i386'"
	echo "  -l <distro>               Linux distro and version.  Valid values are:"
	echo "                            'esx4', 'esxi4','esxi5', 'rhel5-amd64', 'rhel5-x86'"
	echo "                            'rhel6-amd64', 'rhel6-x86', 'sles10-amd64'"
	echo "                            'sles10-x86', 'sles11-amd64', 'sles11-x86'"
}

# Check -s option input
checkCertificate()
{
	input="$*"
	if [[ $input != "true" && $input != "false" ]]; then
		echo "$0: -s: Must be 'true' or 'false'"
		exit 1
	else
		if [[ $input = "true" ]]; then
			checkCert="true"
		else
			checkCert="false"
		fi
	fi
}

# Check -t option input
checkTimeout()
{
	input="$*"

	if expr "$input" : '-\?[0-9]\+$' >/dev/null; then
		timeout=$input	
	else
		echo "$0: -t: Must be an integer"
		exit 1
	fi
}

# Check -r option input
checkArch()
{
	input="$*"
	if [[ $input != "x86_64" && $input != "i386" ]]; then
		echo "$0: -s: Must be 'x86_64' or 'i386'"
		exit 1
	else
		arch=$input
		if [[ $input = "x86_64" ]]; then
			archvCAC="amd64"
		else
			archvCAC="i386"
		fi
	fi
}

# Check -d option input
checkDistro()
{
	input="$*"
	if [[ $input != "esx4" && $input != "esxi4"  && $input != "esxi5" \
	&& $input != "rhel5-amd64" && $input != "rhel5-x86" && $input != "" \
	&& $input != "rhel6-amd64" && $input != "rhel6-x86" && $input != "sles10-amd64" \
	&& $input != "sles10-x86" && $input != "sles11-amd64" && $input != "sles11-x86" ]]; then
		echo "$0: -d: Must be in the following set: "
		echo " 'esx4', 'esxi4','esxi5'"
		echo " 'rhel5-amd64', 'rhel5-x86'"
		echo " 'rhel6-amd64', 'rhel6-x86'"
		echo " 'sles10-amd64', 'sles10-x86'"
		echo " 'sles11-amd64', 'sles11-x86'"		
		exit 1
	else
		distro=$input
	fi
}

# Check -j option input
checkJava()
{
	input="$*"
	
	if [[ $input != "true" && $input != "false" ]]; then
		echo "$0: -d: Must be 'true' or 'false'"
		exit 1
	else
		java=$input
	fi
}

cleanTempDir()
{
	rm -rf $tempDir
}

removeAgents()
{

	echo ""
	echo "##########################"
	echo "# Remove existing agents #"
	echo "##########################"
	echo ""

	# Remove gugent (vCAC Agent)
	gugentInstallRPM=$(dpkg --get-selections | grep 'gugent')

	if [ "$gugentInstallRPM" != "" ]; then
		echo "Uninstalling existing vCloud Automation Center Agent: $gugentInstallRPM .. "
		dpkg -P $gugentInstallRPM
		echo "Deleting /usr/share/gugent dir ..."
		rm -rf /usr/share/gugent
		echo "Deleting /usr/share/log dir ..."
		rm -rf /usr/share/log
		gugentInstallRPM=$(dpkg --get-selections | grep 'gugent')
		if [ "$gugentInstallRPM" != "" ]; then
			Error "Failed to uninstall $gugentInstallRPM"
		else
			echo "vCloud Automation Center Agent removed successfully!"
		fi
	else
		echo "vCloud Automation Center Agent not found, skipping uninstall of agent ..."
	fi

	# Remove appD Agent
	appDInstallRPM=$(dpkg --get-selections | grep 'appdirector')

	if [ "$appDInstallRPM" != "" ]; then
		echo "Stopping Application Services agent service ..."
		service vmware_appdirector_agent stop    
		echo "Uninstalling $appDInstallRPM ..."
		dpkg -P $appDInstallRPM
		appDInstallRPM=$(dpkg --get-selections | grep 'appdirector')
		if [ "$appDInstallRPM" != "" ]; then
			Error "Failed to uninstall $appDInstallRPM"
		else
			echo "Application Services Agent removal successfully!"
		fi
	else
		echo "Application Services Agent not found, skipping uninstall of Application Services Agent ..."
	fi
	
	echo ""
	echo "###############################"
	echo "# Agents Successfully Removed #"
	echo "###############################"
	echo ""

}

# Parses command line input
while getopts i:a:c:v:d:s:t:r:l:j:un? opt
do
	case $opt in
		i) vCACIaaSServer=$OPTARG ;;
		a) appDServer=$OPTARG ;;
		c) vCACCAFEServer=$OPTARG ;;
		s) checkCertificate $OPTARG ;;
		t) checkTimeout $OPTARG ;;
		r) checkArch $OPTARG ;;
		l) checkDistro $OPTARG ;;
		j) checkJava $OPTARG ;;
		u) removeAgents ; exit 0 ;;
		n) interactive="false" ;;
		?) Usage; exit 0 ;;
	esac
done

shift $((OPTIND-1))

echo "###################################################"
echo "# Executing a series of 'Pre-flight' checks       #"
echo "# to make sure environment can support the script #"
echo "###################################################"
echo ""

# List command dependencies here
installCommand "wget"
installCommand "unzip"
installCommand "sha256sum"
installCommand "grep"
installCommand "sed"
installCommand "awk"
installCommand "ifconfig"
installCommand "sysv-rc-conf"
installCommand "dmidecode"
installCommand "perl"
installCommand "alien"
installCommand "dpkg-dev"
installCommand "debhelper"
installCommand "build-essential"


echo "###################################################"
echo "# 'Pre-flight' checks complete                    #"
echo "###################################################"
echo ""

# Begin interactive installer

echo "       _____ _                 _                                    ";
echo "      /  __ \ |               | |                                   ";
echo "__   _| /  \/ | ___  _   _  __| |                                   ";
echo "\ \ / / |   | |/ _ \| | | |/ _\` |                                   ";
echo " \ V /| \__/\ | (_) | |_| | (_| |                                   ";
echo "  \_/  \____/_|\___/ \__,_|\__,_|           _   _                   ";
echo "       / _ \      | |                      | | (_)                  ";
echo "      / /_\ \_   _| |_ ___  _ __ ___   __ _| |_ _  ___  _ __        ";
echo "      |  _  | | | | __/ _ \| '_ \` _ \ / _\` | __| |/ _ \| '_ \       ";
echo "      | | | | |_| | || (_) | | | | | | (_| | |_| | (_) | | | |      ";
echo "      \_|_|_/\__,_|\__\___/|_| |_| |_|\__,_|\__|_|\___/|_| |_|      ";
echo "      /  __ \          | |                                          ";
echo "      | /  \/ ___ _ __ | |_ ___ _ __                                ";
echo "      | |    / _ \ '_ \| __/ _ \ '__|                               ";
echo "      | \__/\  __/ | | | ||  __/ |                                  ";
echo "  ___  \____/\___|_| |_|\__\___|_|_          _        _ _           ";
echo " / _ \                 | |   |_   _|        | |      | | |          ";
echo "/ /_\ \ __ _  ___ _ __ | |_    | | _ __  ___| |_ __ _| | | ___ _ __ ";
echo "|  _  |/ _\` |/ _ \ '_ \| __|   | || '_ \/ __| __/ _\` | | |/ _ \ '__|";
echo "| | | | (_| |  __/ | | | |_   _| || | | \__ \ || (_| | | |  __/ |   ";
echo "\_| |_/\__, |\___|_| |_|\__|  \___/_| |_|___/\__\__,_|_|_|\___|_|   ";
echo "        __/ |                                                       ";
echo "       |___/                                                        ";
echo ""

if [[ -z "$vCACCAFEServer" ]]; then
	echo "Hostname/IP Address of "
	echo -n "vCloud Automation Center Manager Service Server: "
	read vCACCAFEServer
fi

if [[ -z "$vCACIaaSServer" ]]; then
	echo "Hostname/IP Address of "
	echo -n "vCloud Automation Center IaaS Server: "
	read vCACIaaSServer
fi

if [[ -z "$appDServer" ]]; then
	echo "Hostname/IP Address of "
	echo -n "Application Services Server: "
	read appDServer
fi

# Check for certificate
if [[ -z "$checkCert" ]]; then
	echo "Do you want to check certificate when downloading the "
	echo -n "vCloud Automation Center Agent? [Y/n]:"
	read usingCert
	if [[ $usingCert != "N" && $usingCert != "n" ]]; then
		checkCertificate true
	else
		checkCertificate false
	fi
fi

# Ask about timeout
if [[ -z "$timeout" ]]; then
	echo -n "Set download timeout (in seconds) for wget [300]:"
	read newtimeout
	if [ -z $newtimeout ]; then
		timeout="300"
	else
		timeout=$newtimeout
	fi
fi

# Ask about java
if [[ -z "$java" ]]; then
	echo -n "Download and install Java Runtime Environment 1.7.0_51? [y\N]:"
	read installJava
	if [[ $installJava != "Y" && $installJava != "y" ]]; then
		java="false"
	else
		java="true"
	fi
fi

echo ""
echo "############################"
echo "# Determining Architecture #"
echo "############################"
echo ""

if [[ -z $arch ]]; then
	if [ $(uname -m | grep '64') ]; then
		echo "Architecture: 64-bit";
		arch="x86_64";
		archvCAC="amd64";
	else
		echo "Architecture: 32-bit"
		arch="i386"
		archvCAC="x86"
	fi
fi
echo ""
echo "###############################################"
echo "# Determining Linux Distro and version number #"
echo "###############################################"
echo ""

if [[ -z $distro ]]; then
	if [[ $(cat /etc/*release | grep -i centos) ]] || [[ $(cat /etc/*release | grep -i rhel) ]] \
		|| [[ $(cat /etc/*release | grep -i "red hat") ]]; then
		echo "Distro is RHEL/CentOS"
		if [[ $(cat /etc/*release | grep -i "release 6") ]]; then
			distro="rhel6-$archvCAC"
		elif [[ $(cat /etc/*release | grep -i "release 5") ]]; then
			distro="rhel5-$archvCAC"
		else
			Error "Detected an unsupported version of Redhat/CentOS"
		fi	
	elif [[ $(cat /etc/*release | grep -i suse) ]]; then
		if [[ $(cat /etc/*release | grep -i "11") ]]; then
			distro="sles11-$archvCAC"
		elif [[ $(cat /etc/*release | grep -i "10") ]]; then
			distro="sles10-$archvCAC"
		else
			Error "Detected an unsupported version of SUSE"
		fi
	elif [[ $(cat /etc/*release | grep -i ubuntu) ]]; then
		if [[ $(cat /etc/*release | grep -i "14.04") ]]; then
			distro="ubuntu-$archvCAC"
		elif [[ $(cat /etc/*release | grep -i "12.04") ]]; then
			distro="ubuntu-$archvCAC"
		else
			Error "Detected an unsupported version of UBUNTU"
		fi	
	else
		Error "Unable to detect host operating system. Please specify override (Use '-?' option for more info)"
	fi
fi

echo "This distro is detected to have closest compatibility with: $distro";

echo " _____        _    _    _                       ";
echo "/  ___|      | |  | |  (_)                    _ ";
echo "\ \`--.   ___ | |_ | |_  _  _ __    __ _  ___ (_)";
echo " \`--. \ / _ \| __|| __|| || '_ \  / _\` |/ __|   ";
echo "/\__/ /|  __/| |_ | |_ | || | | || (_| |\__ \ _ ";
echo "\____/  \___| \__| \__||_||_| |_| \__, ||___/(_)";
echo "                                   __/ |        ";
echo "                                  |___/         ";
echo "################################################################################"
echo "# Here are the current settings:"
echo "#"
echo "# vCloud Automation Center"
echo "#        Manager Service Server IP:         $vCACCAFEServer"
echo "# vCloud Automation Center IaaS Server IP:  $vCACIaaSServer"
echo "# Application Services Server IP:           $appDServer"
echo "# Check Certificates:                       $checkCert"
echo "# wget timeout:                             $timeout"
echo "# Architecture:                             $arch"
echo "# Linux Distro*:                            $distro"
echo "# Install Java 1.7.0_51:                    $java"
echo "# * This may be an approximation (e.g. CentOS/Redhat both show up as 'RHEL')"
echo "################################################################################"
echo -n "Would you like to start the installation? [Y/n]:"

if [[ $interactive = "true" ]]; then
	read cont

	if [[ $cont != "N" && $cont != "n" ]]; then
		echo "Starting Installation..."
	else
		echo "Cancelling Installation"
		exit 0;
	fi
fi

# Install Java
InstallJava()
{
	echo ""
	echo "######################################"
	echo "# Installing Java JRE 1.7.0_51       #"
	echo "######################################"
	echo ""

	if [[ $arch = "x86_64" ]]; then
		javaZip="jre-1.7.0_72-lin64.zip"
	else
		javaZip="jre-1.7.0_72-lin32.zip"
	fi

	echo "Downloading $javaZip file from $appDServer .. "
	wget --timeout $timeout http://$appDServer/agent/$javaZip -O $tempDir/$javaZip

	if [ $? -ne 0 ]; then
		Error "Unable to download file http://$appDServer/agent/$javaZip"
	else
		echo "Successfully downloaded http://$appDServer/agent/$javaZip"
	fi
	
	echo "Cleaning out old java from /opt/vmware-jre..."
	rm -rf /opt/vmware-jre
	
	echo "Unzipping Java Zip to $tempDir ..."
	unzip -o $tempDir/$javaZip -d /opt/vmware-jre

	if [ $? -ne 0 ]; then
		Error "Unable to extract $javaZip"
	else
		echo "Successfully extracted $javaZip"
	fi	

	version=$(/opt/vmware-jre/bin/java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    
	if [ $version = "1.7.0_72" ]; then
		echo "Java installed successfully"
	else
		Error "Java install failed: $javaVersion"
	fi

}

echo ""
echo "######################################"
echo "# Cleaning up $tempDir"
echo "# From any previous installations"
echo "######################################"
echo ""

cleanTempDir

# Create temp directory
mkdir -p $tempDir


# Install JRE if required
if [[ $java = "true" ]]; then
	InstallJava
fi

# Remove Agents
removeAgents

InstallvCAC() 
{
	echo ""
	echo "###################################################"
	echo "# Install vCloud Autmoation Center Agent (gugent) #"
	echo "###################################################"
	echo ""

	vCACInstallZip="LinuxGuestAgentPkgs.zip"
	vCACInstallUnzipDir="LinuxGuestAgentPkgs"
	vCACAgentRPMName="gugent-6.*.$arch.rpm"
	
	# SUSE uses "i586" instead of "i386" for the RPM name so make the adjustment
	if [[ $distro = "sles11-x86" || $distro = "sles10-x86" ]]; then
		vCACAgentRPMName="gugent-6.*.i586.rpm"
	fi

	if [[ $checkCert = "true" ]]; then
		checkCert="";
	else
		checkCert="--no-check-certificate"
	fi
	
	wget $checkCert --timeout $timeout https://$vCACCAFEServer:5480/installer/$vCACInstallZip -O $tempDir/$vCACInstallZip
	

	if [ $? -ne 0 ]; then
		Error "Failed to download file: https://$vCACCAFEServer:5480/installer/$vCACInstallZip"
	else
		echo "Successfully downloaded https://$vCACCAFEServer:5480/installer/$vCACInstallZip"
	fi

	echo "Unzipping vCloud Automation Center Guest Agent Archive to $tempDir ..."
	unzip -o $tempDir/$vCACInstallZip -d $tempDir/

	if [ $? -ne 0 ]; then
		Error "Unable to extract $vCACInstallZip"
	else
		echo "Successfully extracted $vCACInstallZip"
	fi

	echo "Installing vCloud Automation Center Agent RPM"
	
	# 'LinuxGuestAgentPkgs' directory may or may not be extracted due to vCAC change
	#vCACAgentDEBName=${vCACAgentRPMName%.*}.deb
	if [ ! -d "$tempDir/$vCACInstallUnzipDir" ]; then	
		
		echo "alien $tempDir/$distro/$vCACAgentRPMName"
		alien $tempDir/$distro/$vCACAgentRPMName
		#echo "mv $vCACAgentDEBName $tempDir/$distro/$vCACAgentDEBName"
        #mv $vCACAgentDEBName $tempDir/$distro/$vCACAgentDEBName
		echo "dpkg -i *.deb"
		dpkg -i *.deb
		rm *.deb	
	else
		echo "alien $tempDir/$vCACInstallUnzipDir/$distro/$vCACAgentRPMName"
		alien $tempDir/$vCACInstallUnzipDir/$distro/$vCACAgentRPMName
		#echo "mv $vCACAgentDEBName  $tempDir/$vCACInstallUnzipDir/$distro/$vCACAgentDEBName"
        #mv $vCACAgentDEBName  $tempDir/$vCACInstallUnzipDir/$distro/$vCACAgentDEBName
		echo "dpkg -i *.deb"
		dpkg -i *.deb	
	fi

	vCACInstallRPM=$(dpkg --get-selections | grep 'gugent')

	if [ "$vCACInstallRPM" != "" ]; then
		echo "vCloud Automation Center Agent installed successfully!"
	else
		Error "Unable to install vCloud Automation Center Agent"			
	fi
}

InstallvCAC

InstallAppD()
{
	echo ""
	echo "######################################"
	echo "# Install Application Services Agent #"
	echo "######################################"
	echo ""

	#agentRPMName="vmware-appdirector-agent-service-vcac_6.0.0.0-0_$arch.deb"
	agentRPMName="vmware-appdirector-agent-service-vcac_6.0.0.0-0_amd64.deb"

	echo "Downloading agent files from $appDServer .. "
	
	wget --timeout $timeout http://$appDServer/agent/$agentRPMName -O $tempDir/$agentRPMName

	if [ $? -ne 0 ]; then
		Error "Unable to download file http://$appDServer/agent/$agentRPMName"
	else
		echo "Successfully downloaded http://$appDServer/agent/$agentRPMName"
	fi

	# Install RPM and confirm
	echo "Installing Application Services Agent RPM"
	echo "dpkg -i $tempDir/$agentRPMName"
	dpkg -i $tempDir/$agentRPMName

	appDInstallRPM=$(dpkg --get-selections | grep 'appdirector')

	if [ "$appDInstallRPM" != "" ]; then
		echo "Application Services Agent installed successfully!"
	else
		Error "Unable to install Application Services Agent"

	fi

	echo ""
	echo "######################################"
	echo "# Resetting AppD Agent Bootstrap     #"
	echo "######################################"
	echo ""

	echo "/opt/vmware-appdirector/agent-bootstrap/agent_reset.sh"
	/opt/vmware-appdirector/agent-bootstrap/agent_reset.sh
}

InstallAppD

echo ""
echo "###############################################################"
echo "# Registering vCloud Automation Center Agent with IaaS Server #"
echo "###############################################################"
echo ""

echo "/opt/vmware-appdirector/agent-bootstrap/vcac-register.sh -s $vCACIaaSServer";
/opt/vmware-appdirector/agent-bootstrap/vcac-register.sh -s $vCACIaaSServer

if [ $? -ne 0 ]; then
	Error "Unable to register vCloud Automation Center Agent to IaaS Server"
else
	echo "Successfully registered vCloud Automation Center Agent to IaaS Server"
fi


echo ""
echo "######################################"
echo "# Checking that Service is Installed #"
echo "######################################"
echo ""

isInstalled=$(sysv-rc-conf --list | grep vrm-agent)

if [[ $isInstalled =~ .*vrm-agent.*0:(off|Aus|arrÃªt).*1:(off|Aus|arrÃªt).*2:(off|Aus|arrÃªt).*3:(on|Ein|marche).*4:(off|Aus|arrÃªt).*5:(on|Ein|marche).*6:(off|Aus|arrÃªt).* ]]; then
	echo "vrm-agent service is installed: $isInstalled"
else
	Error "vrm-agent may not be configured correctly: $isInstalled"
fi

echo ""
echo "######################################"
echo "# Cleaning up $tempDir"
echo "######################################"
echo ""

cleanTempDir

echo ""
echo "#######################################"
echo "# Installation Completed Successfully #"
echo "# Ready to capture as a template      #"
echo "#######################################"
echo ""
