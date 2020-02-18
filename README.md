# trojan-gfw-centos-8

## Usage
 
```
sudo yum -y install wget && wget https://raw.githubusercontent.com/lionlibr/trojan-gfw-centos-8/master/install.sh && sudo bash install.sh
```

## Video Demonstration

https://www.youtube.com/watch?v=68aP4RpZDVs

## Overview

This script assumes that you start with a brand new server running CentOS 8.

1. Set TCP congestion control to BBR
2. Install and configure firewalld
3. Install and configure nginx
4. Install and configure Trojan
