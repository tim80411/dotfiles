#!/bin/bash
echo "sleeping for 5 seconds"
sleep 5

# host需填寫hostname，原因是若使用docker network，本機無法解讀，需要取得hostname可用hostname -f
echo mongo_setup.sh time now: `date +"%T" `
mongosh --host TimothyiaodeMBP:27017 <<EOF
  var cfg = {
    "_id": "rs0",
    "version": 1,
    "members": [
      {
        "_id": 0,
        "host": "TimothyiaodeMBP:27017",
        "priority": 2
      }
    ]
  };
  rs.initiate();
EOF