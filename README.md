# trojan-gfw-centos-8

## Usage
 
```
sudo yum -y install wget && wget https://raw.githubusercontent.com/lionlibr/trojan-gfw-centos-8/master/install.sh && sudo bash install.sh
```

## Video Demonstration

https://www.youtube.com/watch?v=68aP4RpZDVs

## Overview

This script assumes that you start with a brand new server running CentOS 8. It is not advisable to run this script on a server that already has other applications running on it. The script carries out four actions:

1. Set TCP congestion control to BBR
2. Install and configure firewalld
3. Install and configure nginx
4. Install and configure Trojan

## Detailed Explanation

https://www.lionlibr.com/posts/trojan-gfw-centos-igniter-android.html

## Troubleshooting

On your Windows client, the Trojan Command Prompt window may show some error messages.

On your CentOS server, these commands may show some error messages:

```
systemctl status trojan

journalctl -u trojan

tail /var/log/nginx/error.log
```

## Common Error Messages

https://github.com/trojan-gfw/trojan/wiki/What-the-heck-do-these-logs-mean%3F

## Backout Plan

If possible, reimage the server, as it is safer than trying to remove individual components.

This backout plan should be used with caution if other services are already running on the server, as it may have unintended effects on them if they use the same components.

### BBR

```
rm /etc/sysctl.d/50-bbr.conf
sysctl -p
```

### FirewallD

```
systemctl stop firewalld
systemctl disable firewalld
yum remove firewalld
```

### Nginx

```
systemctl stop nginx 
systemctl disable nginx
yum remove nginx
rm /etc/nginx/default.d/requests.conf
rm /etc/nginx/nginx.conf
rm /etc/nginx/default.d/404.conf
rm -rf /usr/share/nginx/html/*
```

The next command entirely removes all Let’s Encrypt certificates and keys from the server.

```
rm -rf /etc/letsencrypt
```

Manually remove the `certbot-auto renew` line from crontab:

```
vi /etc/crontab
```

### Trojan

```
systemctl stop trojan 
systemctl disable trojan 
rm /usr/local/etc/trojan/config.json
rm /usr/local/bin/trojan
rm trojan-quickstart.sh
```
