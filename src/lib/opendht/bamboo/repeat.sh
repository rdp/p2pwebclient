#!/bin/bash
for ((i=100;i<=215;i+=1)); do
$@
sleep 10
echo $?
echo 'was the result'
done
