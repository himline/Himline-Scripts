###Ubuntu#####################
sudo apt-get update
sudo apt-get install apache2 mysql-server php5 php5-gd php5-mysql php5-mcrypt
wget https://github.com/xibosignage/xibo-cms/archive/1.7.1.tar.gz -O xibo-server.tar.gz
tar xvzf xibo-server.tar.gz
sudo mv xibo-server-142 /var/www/xibo-server
sudo chown www-data:www-data -R /var/www/xibo-server
sudo mkdir /media/xibo-library
sudo chown www-data:www-data -R /media/xibo-library
sudo /etc/init.d/apache2 restart
