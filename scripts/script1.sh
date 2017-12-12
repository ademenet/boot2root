#!/bin/bash

echo "ifconfig vmnet8:"
ifconfig vmnet8 | grep inet | cut -d" " -f2  > vmnet8
cat vmnet8
echo "\nnmap `cat vmnet8`-255:"
nmap `cat vmnet8`-255 > vmnet8_nmap
cat vmnet8_nmap
echo "\nBoot2Root server port:"
cat vmnet8_nmap | grep for | tail -n1 | cut -d" " -f5 > vmnet8_port
cat vmnet8_port
echo "\nInstall Dirb soft:"
sleep 3[s]
sh dirb_install
./dirb https://`cat vmnet8_port`/ dirb222/wordlists/common.txt
