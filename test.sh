#!/bin/bash

AUTH_LOG="/var/log/auth.log"
SYSLOG="/var/log/syslog"
APACHE_ACCESS="/var/log/apache2/access.log"
APACHE_ERROR="/var/log/apache2/error.log"

FAILED_LOGINS="failed_logins.tmp"
SUDO_EVENTS="sudo_events.tmp"
WEB_ATTACKS="web_attacks.tmp"
HTTP_ERRORS="http_errors.tmp"
SYSTEM_ERRORS="system_errors.tmp"

DATE_7_DAYS_AGO=$(date -d '7 days ago' '+%b %e')

#Verify if log file exist

check_log_file() {
	local file=$1
	if [ ! -f "$file" ]; then
		echo "Warning: $file not found!"
		return 1;
	fi
}

#Analyze AUTH.LOG

if check_log_file "$AUTH_LOG"; then
	> "$FAILED_LOGINS"
	
	#Pattern: "Failed Password"
	grep "Failed password" "$AUTH_LOG" | while read line; do
	
	#Extract timestamp, username, IP, port
	timestamp=$(echo "$line" | awk '{print $1, $2, $3}')
	username=$(echo "$line" | awk '{for(i=1;i<=NF;i ++) if($i=="for") print $(i+1)}')
	ip=$(echo "$line" | awk '{for(i=1;i<=NF;i ++) if($i=="from") print $(i+1)}')
	port=$(echo "$line" | awk '{for(i=1;i<=NF;i ++) if($i=="port") print $(i+1)}')
	
	echo "$timestamp|FAILED_SSH|$username|$ip|$port" >> "$FAILED_LOGINS"
	
	done
	
	#Extract SUDO events
	> "$SUDO_EVENTS"
	
	grep "sudo:" "$AUTH_LOG" | grep -v "session" | while read line; do
		timestamp=$(echo "$line" | awk '{print $1, $2, $3}')
		user=$(echo "$line" | awk '{for(i=1;i<=NF;i ++) if($(i-1)=="USER") print $(i)}')
		command=$(echo "$line" | grep -oP 'COMMAND=\K.*')
		
		echo "$timestamp|SUDO|$user|$command" >> "$SUDO_EVENTS"
		
		done
fi


# Analyze Apache access logs

if check_log_file "$APACHE_ACCESS"; then
	
	> "$WEB_ATTACKS"
	> "$HTTP_ERRORS"
	
	#Extract errors
	awk '$9 >= 400 && $9 < 600 {print $0}' "$APACHE_ACCESS" | while read line; do
		ip=$(echo "$line" | awk '{print $1}')
		timestamp=$(echo "$line" | grep -oP '\[.*?\]' | tr -d '[]')
		request=$(echo "$line" | grep -oP '"[A-Z]+ [^ ]+ HTTP/[^"]*"')
		status=$(echo "$line" | awk '{print $9}')
		
		echo "$timestamp|$status|$ip|$request" >> "$HTTP_ERRORS"
	done
	
	#Pattern SQL Injection
	grep -iE "(union|select|drop|insert|delete|update|'|--|;|xp_|exec|script|<script)" "$APACHE_ACCESS" | while read line; do
	
		ip=$(echo "$line" | awk '{print $1}')
		timestamp=$(echo "$line" | grep -oP '\[.*?\]' | tr -d '[]')
		request=$(echo "$line" | grep -oP '"[A-Z]+ [^"]*"')
	
		echo "$timestamp|SQL_INJECTION|$ip|$request" >> "$WEB_ATTACKS"
	done
fi 

#Analyze SYSLOG

if check_log_file "$SYSLOG"; then
	
	> "$SYSTEM_ERRORS"
	
	grep -iE "(error|failed|failure|critical|fatal)" "$SYSLOG" | while read line; do
		
		timestamp=$(echo "$line" | awk '{print $1, $2, $3}')
		service=$(echo "$line" | awk '{print $5}' | tr -d ':')
		message=$(echo "$line" | cut -d':' -f2- | cut -c1-100)
		
		echo "$timestamp|ERROR|$service|$message" >> "$SYSTEM_ERRORS"
	done
fi

#Top 10 attacks IP SSH
if [ -s "$FAILED_LOGINS" ]; then
	awk -F'|' '{print $4}' "$FAILED_LOGINS" | sort | uniq -c | sort -rn | head -10
fi


#Top 10 attackers WEB
if [ -s "$WEB_ATTACKS" ]; then
	awk -F'|' '{print $3}' "$WEB_ATTACKS" | sort | uniq -c | sort -rn | head -10
fi

#Generate FILE REPORT FOR HTML

cat > quick-report.txt << EOF

Generated: $(date '+%Y-%m-%d %H:%M:%S')

-- TOP ATTACKERS (SSH)
$(awk -F'|' '{print $4}' "FAILED_LOGINGS" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | awk '{printf "%-15s : %d attacks\n", $2, $1}')

-- TOP WEB ATTACKERS
$(awk -F'|' '{print $3}' "WEB_ATTACKS" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | awk '{printf "%-15s : %d attacks\n", $2, $1}')

-- OUTPUT FILES --
$FAILED_LOGINS : Failed logins attempts
$SUDO_EVENTS   : Sudo usage events
$WEB_ATTACKS   : Web attack attempts
$HTTP_ERRORS   : HTTP error responses
$SYSTEM_ERRORS : System errors

EOF

