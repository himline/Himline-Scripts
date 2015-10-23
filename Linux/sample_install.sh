#!/bin/bash
# Global Variables 


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


echo "###################################################"
echo "# Executing a series of 'Pre-flight' checks       #"
echo "# to make sure environment can support the script #"
echo "###################################################"
echo ""

# List command dependencies here
sudo tasksel install lamp-server

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
installCommand "tasksel"
installCommand "drupal7"

echo "###################################################"
echo "# 'Pre-flight' checks complete                    #"
echo "###################################################"
echo ""

sudo cp /etc/drupal/7/apache2.conf /etc/apache2/mods-enabled/drupal.conf
sudo service apache2 restart


