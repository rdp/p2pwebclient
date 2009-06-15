#!/bin/bash
for ((i=100;i<=215;i+=1)); do
$1 $2 $3 $4 $5 $6 $7 $8 $9
echo $?
echo 'was the result'
done
