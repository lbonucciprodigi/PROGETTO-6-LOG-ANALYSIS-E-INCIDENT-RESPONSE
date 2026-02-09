#!/bin/bash

#Checking if IP trying to BRUTE FORCE via SSH

THRESHOLD=5

grep "Failed password" /var/log/auth.log | awk '{print $9}' | sort | uniq -c |
while read count ip; do
	if [ "$count" -gt "$THRESHOLD" ]; then
		echo "ALERT: IP $ip trying to BRUTE FORCE $count times"
	fi
done	

#List of TOP IP attackers

FILE="top-attacker.txt"

if [ ! -e "FILE" ]; then
	touch "$FILE"
fi

grep "Failed password" /var/log/auth.log | awk '{print $9}' | sort | uniq -c > top-attacker.txt

#List of sudo COMMAND

grep "sudo:" /var/log/auth.log | grep "COMMAND"

#Analyze HTTP errors

awk '$9 ~ /^[45]/ {print $1, $7, $9}' /var/log/apache2/access.log


#Scanning ports
sudo nmap localhost -oN portscan.txt

#Searching the journal for suspicious activity
journalctl -p err --since "7 days ago" -o json > timeline.json
