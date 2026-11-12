#!/bin/bash

# directory 
readonly BASE_DIR="$HOME/la-kurssi/week3"
readonly WEB_DIR="$BASE_DIR/stats"

# create directory if it doesn't exist
mkdir -p "$WEB_DIR"

# report generated at
date '+%d.%m.%Y %H:%M' > "$WEB_DIR/generated.txt"

# server time zone
date '+%:z %Z' > "$WEB_DIR/tz.txt"

# server uptime
uptime -p | sed 's/^up //' > "$WEB_DIR/uptime.txt"

# rootdisk usage
diskusage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%') 
if [ $diskusage -ge 95 ]; then
  echo "CRITICAL" > "$WEB_DIR/diskusage.txt"
elif [ $diskusage -ge 80 ]; then
  echo "WARNING" > "$WEB_DIR/diskusage.txt"
else
  echo "OK" > "$WEB_DIR/diskusage.txt"
fi


# disk space status
df -h / | awk 'NR==2 {print "used: " $3 " / " $2 }' > "$WEB_DIR/diskspace.txt"

# total RAM MiB
free -m | awk 'NR==2 {print $2 " MiB"}' > "$WEB_DIR/totalram.txt"

# available RAM total MiB
free -m | awk 'NR==2 {print $7 " MiB"}' > "$WEB_DIR/availableram.txt"


# disk status tests with random numbers
disktest=$(( RANDOM % 100 ))
if [ $disktest -ge 95 ]; then
  echo "$disktest% CRITICAL" > "$WEB_DIR/val-disk-usage-95.txt"
elif [ $disktest -ge 80 ]; then
  echo "$disktest% WARNING" > "$WEB_DIR/val-disk-usage-80.txt"
else 
  echo "$disktest% OK" > "$WEB_DIR/val-disk-usage-50.txt"
fi


echo "report.sh ok"
