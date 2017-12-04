#!/bin/bash
ifconfig vmnet8 | grep inet | cut -b 7-17 > vmnet8
cat vmnet8
nmap `cat vmnet8`-255
nmap `cat vmnet8`-255 | grep for | tail -n1 | cut -b 22-34 > vmnet8_port
cat vmnet8_port
sh dirb_install
./dirb https://`cat vmnet8_port`/ dirb222/wordlists/common.txt
