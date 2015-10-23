########################################################################################################
#https://docs.chef.io/release/server_12-2/install_server.html
#Download the package from http://downloads.chef.io/chef-server/.
#Upload the package to the machine that will run the Chef server, and then record its location on the file system. The rest of these steps assume this location is in the /tmp directory.

dpkg -i /tmp/chef-server-core-<version>.deb

#start all of the services
chef-server-ctl reconfigure

#create an administrator
chef-server-ctl user-create user_name first_name last_name email password --filename FILE_NAME

#An RSA private key is generated automatically. This is the user’s private key and should be saved to a safe location. The --filename option will save the RSA private key to a specified path.
chef-server-ctl user-create stevedanno Steve Danno steved@chef.io abc123 --filename /path/to/stevedanno.pem

#create an organization
chef-server-ctl org-create short_name "full_organization_name" --association_user user_name --filename ORGANIZATION-validator.pem

#An RSA private key is generated automatically. This is the chef-validator key and should be saved to a safe location. The --filename option will save the RSA private key to a specified path.
chef-server-ctl org-create 4thcoffee "Fourth Coffee, Inc." --association_user stevedanno --filename /path/to/4thcoffee-validator.pem

#Install Chef features
#The install subcommand downloads packages from https://packagecloud.io/ by default. For systems that are not behind a firewall (and have connectivity to https://packagecloud.io/), these packages can be installed as described below
#chef-server-ctl install PACKAGE_NAME --path /path/to/package/directory

#Feature : Chef Manage
chef-server-ctl install opscode-manage
chef-server-ctl reconfigure
opscode-manage-ctl reconfigure

#Feature : Chef Push Jobs
chef-server-ctl install opscode-push-jobs-server
chef-server-ctl reconfigure
opscode-push-jobs-server-ctl reconfigure

#Feature : Chef Replication
chef-server-ctl install chef-sync
chef-server-ctl reconfigure
chef-sync-ctl reconfigure

#Feature : Reporting
chef-server-ctl install opscode-reporting
chef-server-ctl reconfigure
opscode-reporting-ctl reconfigure
#######################################################################################################