#!/bin/bash
mysql -h localhost -u root -pstackdb mysql <<EOF
CREATE DATABASE IF NOT EXISTS magnum DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON magnum.* TO
    'root'@'%' IDENTIFIED BY 'stackdb'
EOF
