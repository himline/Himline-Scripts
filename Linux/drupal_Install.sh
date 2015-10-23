# Currnetly We do it manualy as below steps

sudo tasksel install lamp-server
sudo a2enmod rewrite
sudo service apache2 restart
wget http://ftp.drupal.org/files/projects/drupal-7.25.tar.gz
tar -xvzf drupal-7.25.tar.gz
sudo mkdir /var/www/drupal
sudo mv drupal-7.25/* drupal-7.25/.htaccess drupal-7.25/.gitignore /var/www/drupal
sudo mkdir /var/www/drupal/sites/default/files
sudo chown www-data:www-data /var/www/drupal/sites/default/files
sudo cp /var/www/drupal/sites/default/default.settings.php /var/www/drupal/sites/default/settings.php
sudo chown www-data:www-data /var/www/drupal/sites/default/settings.php
mysqladmin -u root -p create drupal
mysql -u root -p

mysql> GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES ON drupal.* TO 'drupal'@'localhost' IDENTIFIED BY 'VMware1!';
mysql> FLUSH PRIVILEGES;
mysql> \q
sudo service apache2 restart
---Copy theme
sudo chown -R www-data:www-data /var/www/drupal

## Manual Steps Ends