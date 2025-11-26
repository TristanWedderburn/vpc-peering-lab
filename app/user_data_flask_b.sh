#!/bin/bash
yum update -y
yum install -y python3-pip
pip3 install flask

cat << 'EOF' > /home/ec2-user/app.py
from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return "Hello from VPC B!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

chown ec2-user:ec2-user /home/ec2-user/app.py

cat << 'EOF' > /etc/systemd/system/flask.service
[Unit]
Description=Flask App B
After=network.target

[Service]
User=ec2-user
ExecStart=/usr/bin/python3 /home/ec2-user/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable flask
systemctl start flask
