#!/bin/bash
apt-get update
apt-get -y upgrade
apt-get -y install python-pip
pip install awscli
aws s3 cp s3://apitestbucket09/initialization.sh /initialization.sh
chmod 755 /initialization.sh
/./initialization.sh