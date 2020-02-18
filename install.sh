#!/bin/bash

##########################################################################
#                                                                        #
# Set TCP congestion control to BBR                                      #
#                                                                        #
##########################################################################
set_congestion_control () {
    echo "Setting TCP congestion control algorithm to BBR"
    # Specify BBR TCP congestion control algorithm
    echo "net.core.default_qdisc=fq" > /etc/sysctl.d/50-bbr.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/50-bbr.conf
    # Activate this change
    sysctl -p /etc/sysctl.d/50-bbr.conf
}

##########################################################################
#                                                                        #
# Install and configure firewalld                                        #
#                                                                        #
##########################################################################
install_configure_firewalld () {
    echo "Installing and configuring firewalld"
    # Install and start firewalld
    yum -y install firewalld
    systemctl enable firewalld
    systemctl start firewalld
    # Allow SSH only from IP address(es) in the trusted zone
    firewall-cmd --permanent --zone=trusted --add-service=ssh
    firewall-cmd --permanent --zone=trusted --add-source=$CLIENTCIDR
    # Block public SSH access
    firewall-cmd --permanent --zone=public --remove-service=ssh
    # Allow public HTTP and HTTPS access
    firewall-cmd --permanent --zone=public --add-service=http
    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --reload
}

##########################################################################
#                                                                        #
# Install and configure nginx                                            #
#                                                                        #
##########################################################################
install_configure_nginx () {
    echo "Installing and configuring nginx"
    # Install and start nginx
    yum -y install nginx
    systemctl enable nginx
    systemctl start nginx
    # Block unwarranted HTTP requests
    echo "if (\$request_method !~ ^(GET|HEAD|POST)\$ )" \
                                > /etc/nginx/default.d/requests.conf
    echo "{"                   >> /etc/nginx/default.d/requests.conf
    echo "        return 405;" >> /etc/nginx/default.d/requests.conf
    echo "}"                   >> /etc/nginx/default.d/requests.conf
    # Set server name
    sed -i -e "/server_name/s/_;/$SERVERNAME;/" /etc/nginx/nginx.conf
    # Specify custom 404 page
    echo "error_page 404 /index.html;" > /etc/nginx/default.d/404.conf
    # Restart Nginx with its new configuration
    systemctl restart nginx
    # Add website content
    wget https://github.com/lionlibr/sample-hexo-blog/archive/master.zip
    unzip master.zip
    cd sample-hexo-blog-master
    cp -rf public/* /usr/share/nginx/html/
    # Obtain Let's Encrypt SSL certificate
    wget https://dl.eff.org/certbot-auto
    mv certbot-auto /usr/local/bin/certbot-auto
    chmod 755 /usr/local/bin/certbot-auto
    /usr/local/bin/certbot-auto certonly --nginx --agree-tos --register-unsafely-without-email -d $SERVERNAME
    echo "0 0,12 * * * root python3 -c 'import random; import time; time.sleep(random.random() * 3600)' && /usr/local/bin/certbot-auto renew" | tee -a /etc/crontab > /dev/null
}

##########################################################################
#                                                                        #
# Install and configure Trojan                                           #
#                                                                        #
##########################################################################
install_configure_trojan () {
    echo "Installing and configuring Trojan"
    # Install Trojan
    curl -O https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh
    /bin/bash trojan-quickstart.sh
    # Amend Trojan server configuration file
    sed -i 's/"password1",/"password1"/' \
                          /usr/local/etc/trojan/config.json
    sed -i "s/password1/$PASSWORD/" \
                          /usr/local/etc/trojan/config.json
    sed -i '/password2/d' /usr/local/etc/trojan/config.json
    LECERT="/etc/letsencrypt/live/"$SERVERNAME"/fullchain.pem"
    sed -i "s,/path/to/certificate.crt,$LECERT," \
                          /usr/local/etc/trojan/config.json
    LEKEY="/etc/letsencrypt/live/"$SERVERNAME"/privkey.pem"
    sed -i "s,/path/to/private.key,$LEKEY," \
                          /usr/local/etc/trojan/config.json
    # Run Trojan
    systemctl enable trojan
    systemctl start trojan
}

##########################################################################
#                                                                        #
# Mainline                                                               #
#                                                                        #
##########################################################################

# Check that the user running this script is root (effective user id zero)
if [ "$EUID" -ne 0 ]; then
    echo "Fatal, user must be root to run this script"
    exit 2
fi

# Check that this server runs CentOS and version is CentOS release 8
if [ -f "/etc/centos-release" ]; then
    RELEASE=$(cat /etc/centos-release | cut -c22)
    if [ $RELEASE -ne 8 ]; then
        echo "Fatal, platform must be CentOS 8 to run this script"
        exit 2
    fi
else
    echo "Fatal, platform must be CentOS to run this script"
    exit 2
fi

# Check that Trojan is not already installed
if [ -f "/usr/local/bin/trojan" ]; then
    echo "Error, trojan is already installed, exiting script"
    exit 1
fi

# Install dependencies
echo "Installing dependencies"
yum -y install wget zip unzip curl bind-utils

# Print a header before the parameters
echo -e "\n********************************************************"
echo -e "*                                                      *"
echo -e "* Please specify the parameters you want for this run  *"
echo -e "*                                                      *"
echo -e "********************************************************\n"

# Get client IP address
CLIENTIP=$(who am i | cut -d"(" -f2 | cut -d")" -f1)
CLIENTCIDR=$CLIENTIP/32
echo "The script will attempt to block all access to the SSH port"
echo "except for the IP address(es) that you explicitly allow."
read -rp "IP address(es) to allow for SSH: " -e -i "$CLIENTCIDR" CLIENTCIDR

# Get server IP address
SERVERIP=$(wget -qO- ipinfo.io/ip)
read -rp "What is your server's public IP address: " -e -i "$SERVERIP" SERVERIP

# Get server hostname
SERVERNAME=$HOSTNAME
read -rp "What is your server's public hostname: " -e -i "$SERVERNAME" SERVERNAME

# Generate password, replacing / with @
PASSWORD=$(openssl rand -base64 6)
PASSWORD=${PASSWORD/\//@/.}
read -rp "What do you want for a Trojan password: " -e -i "$PASSWORD" PASSWORD
PASSWORD=${PASSWORD/\//@/.}

# Feedback parameters
echo -e "\nThese are the parameters for this run:"
echo "IP address(es) allowed for SSH = "$CLIENTCIDR
echo "Server's public IP address = "$SERVERIP
echo "Server's public hostname = "$SERVERNAME
DNSRESPONSE=$(dig +short $SERVERNAME)
echo "DNS resolution of this hostname = "$DNSRESPONSE
echo "Trojan password = "$PASSWORD
# Give the user a chance to exit
while true; do
    read -p "Do you want to proceed (Y/N)?" PROCEED
    case $PROCEED in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer Y or N.";;
    esac
done

# If BBR is not configured, then configure it now
TCPCC=$(sysctl net.ipv4.tcp_congestion_control)
if [[ $TCPCC =~ "bbr" ]]; then
    echo "Warning, TCP congestion control is already BBR, skipping this step"
else
    set_congestion_control
fi

# If firewalld is not installed, then install and configure it
if [[ $(rpm -qa | grep "firewalld") ]]; then
    echo "Warning, firewalld is already installed, skipping this step"
else
    install_configure_firewalld
fi

# If nginx is not installed, then install and configure it
if [[ $(rpm -qa | grep "nginx") ]]; then
    echo "Warning, nginx is already installed, skipping this step"
else
    install_configure_nginx
fi

# Install and configure Trojan
install_configure_trojan

# Display client configuration info
echo -e "\n********************************************************"
echo -e "*                                                      *"
echo -e "* Here are the parameters for the client               *"
echo -e "*                                                      *"
echo -e "********************************************************\n"
echo -e "Hostname = "$SERVERNAME
echo -e "Port = 443"
echo -e "Password = "$PASSWORD
echo -e "\nEnd of script"
