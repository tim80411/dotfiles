#!/bin/bash
echo "sleeping for 5 seconds"
sleep 5

# 為了確保mongo彼此都知道Domain Name，mongo的networkMode要設定為host
echo mongo_setup.sh time now: `date +"%T" `
HOSTNAME=$(hostname -s)
mongosh --host $HOSTNAME:27017 <<EOF
  var cfg = {
    "_id": "rs0",
    "version": 1,
    "members": [
      {
        "_id": 0,
        "host": "$HOSTNAME:27017",
        "priority": 2
      }
    ]
  };
  rs.initiate(cfg, { force: true });
EOF