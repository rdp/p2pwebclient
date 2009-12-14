cat $1 | nslookup 2>&1 | egrep 'Address:.*' | grep -v ">" | grep -v "#" > $1.ips.txt
echo 'now convert it by hand'
