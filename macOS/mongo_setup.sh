#!/bin/bash
echo "sleeping for 5 seconds"
sleep 5

# 直接使用mongo作為domain連結
echo mongo_setup.sh time now: `date +"%T" `
echo hostname: mongo
mongosh --host mongo:27017 <<EOF
  var cfg = {
    "_id": "rs0",
    "version": 1,
    "members": [
      {
        "_id": 0,
        "host": "mongo:27017",
        "priority": 2
      }
    ]
  };
  rs.initiate(cfg)
  db.getSiblingDB('admin').createUser({user: 'root', pwd: 'example', roles: [{role: 'root', db: 'admin'}]})
EOF
