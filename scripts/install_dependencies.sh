#!/bin/bash
yum install java -y
yum install -y gcc-c++ make
curl -sL https://rpm.nodesource.com/setup_6.x | sudo -E bash -
yum install nodejs -y
npm install pm2 -g