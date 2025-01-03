#!/bin/sh

sudo yum update -y && sudo yum upgrade -y
sudo yum install ntp ntpdate -y
sudo systemctl start ntpd
sudo systemctl enable ntpd

# Configuration Time Sync across nodes
sudo ntpdate -u -s pool.ntp.org
echo "Waiting for 10s sleep"
sleep 10s

sudo systemctl restart ntpd
echo "NTP Installed and Configured"

timedatectl  #It outputs the NTP configurations.