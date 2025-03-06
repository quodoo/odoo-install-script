#!/bin/bash


ODOO_DIR=/home/ubuntu/odoo
DB_USER=odoo
DB_PASSWORD=password
DB_HOST=localhost
DB_PORT=5432

# Read the documentation for the installation of Odoo 18 
# https://www.odoo.com/documentation/18.0/administration/on_premise/source.html
# Update Server
sudo apt update -y

# Secure Server
# sudo apt install openssh-server fail2ban -y

# Install Packages and libraries
# Install Odoo's necessary Python packages. Set up pip3.
# sudo apt install -y python3-pip

# Use the methods below to install web dependencies and packages. Verify that every package has been installed correctly and without any problems.
sudo apt install -y libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev libncurses5-dev libgdbm-dev libnss3-dev libreadline-dev  libsqlite3-dev wget libbz2-dev

# install python environment
# install python3.12 from source 
mkdir $ODOO_DIR
cd $ODOO_DIR
wget https://www.python.org/ftp/python/3.12.9/Python-3.12.9.tgz
tar -xf Python-3.12.9.tgz
cd Python-3.12.9/
./configure --enable-optimizations --prefix=$ODOO_DIR/python3.12

# Now initiate the Python 3.12 build process:
# Remember, the (-j) corresponds to the number of cores in your system to speed up the build time
sudo make -j 4

# The altinstall prevents the compiler to override default Python versions.
sudo make altinstall
sudo chown -R ubuntu:ubuntu $ODOO_DIR/python3.12
# Check version
$ODOO_DIR/python3.12/bin/python3.12 --version

# Upgrade pip
$ODOO_DIR/python3.12/bin/python3.12 -m pip install --upgrade pip

$ODOO_DIR/python3.12/bin/python3.12 -m pip install setuptools wheel cython

# Install nodejs & npm
cd $ODOO_DIR/
mkdir $ODOO_DIR/node-v18
wget https://nodejs.org/dist/v18.20.0/node-v18.20.0-linux-x64.tar.xz
tar -xJf node-v18.20.0-linux-x64.tar.xz -C /home/ubuntu/odoo/node-v18 --strip-components=1
sudo ln -s /home/ubuntu/odoo/node-v18/bin/node /usr/bin/node
sudo ln -s /home/ubuntu/odoo/node-v18/bin/npm /usr/bin/npm

sudo npm install -g less less-plugin-clean-css
sudo apt install -y node-less

# Install PostgreSQL
# Import PostgreSQL 15 APT Repository
curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /usr/share/keyrings/postgresql.gpg > /dev/null

# Import PostgreSQL 15 stable APT repository
echo deb [arch=amd64,arm64,ppc64el signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main | sudo tee /etc/apt/sources.list.d/postgresql.list
sudo apt update -y

sudo apt install postgresql-client-16 -y
PG_PATH=/usr/lib/postgresql/16/bin 
# Install PostgreSQL 16 If you want to install PostgreSQL 15 on your server, you can do so by running the following command:
sudo apt install postgresql-16 -y

# Create user for Odoo
# remove createdb if you don't want the user to have the ability to create databases
sudo su - postgres -c "createuser $DB_USER --createdb --no-createrole --no-superuse"
# Set user password for Odoo
sudo su - postgres -c "psql -c \"ALTER USER $DB_USER WITH PASSWORD '$DB_PASSWORD';\""

# Odoo Base DIR 
mkdir $ODOO_DIR/odoo18/

# install git and clone odoo
sudo apt install git -y
git clone https://github.com/odoo/odoo.git --depth 1 --branch 18.0 $ODOO_DIR/odoo18/

# Install Required Python Packages
# Install Odoo Requirements
cd $ODOO_DIR/odoo18/
$ODOO_DIR/python3.12/bin/python3.12 -m pip install -r requirements.txt

# Install Wkhtmltopdf 0.12.6.1-3 
# wkhtmltopdf is not installed through pip and must be installed manually in version 0.12.6 for it to support headers and footers.
sudo wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
sudo dpkg -i wkhtmltox_0.12.6.1-3.jammy_amd64.deb
sudo apt install -f
sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin


# Create Config folder
mkdir $ODOO_DIR/custom_addons
THIRST_PARTY_ADDONS=$ODOO_DIR/custom_addons/3rd-addons   
CUSTOM_ADDON=$ODOO_DIR/custom_addons/customs
mkdir $THIRST_PARTY_ADDONS
mkdir $CUSTOM_ADDON

DATA_DIR=$ODOO_DIR/.local
LOG_DIR=$ODOO_DIR/odoo18/logs
CONF_DIR=$ODOO_DIR/odoo18/config
CUSTOM_ADDONS_PATH="$ODOO_DIR/odoo18/addons/,$ODOO_DIR/odoo18/odoo/addons/,$THIRST_PARTY_ADDONS,$CUSTOM_ADDON"
ADMIN_PASSWORD=mysupersecretpassword
DB_NAME=odoo18

mkdir $DATA_DIR
mkdir $LOG_DIR
mkdir $CONF_DIR

sudo tee $CONF_DIR/odoo.conf > /dev/null <<EOF
[options]
; This is the password that allows database operations:
admin_passwd = $ADMIN_PASSWORD
db_host = $DB_HOST
db_port = $DB_PORT
db_user = $DB_USER
db_password = $DB_PASSWORD
db_maxconn = 32
pg_path = $PG_PATH

addons_path = $CUSTOM_ADDONS_PATH
dbfilter = $DB_NAME
db_name = $DB_NAME
list_db = False

logrotate = True
logfile = $LOG_DIR/odoo.log
log_handler = :INFO
log_level = info

limit_memory_hard = 835544320
limit_memory_soft = 768435456
workers = 3
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200
max_cron_threads = 1

proxy_mode = True
http_enable = True
http_interface =
http_port = 8069
gevent_port = 8072

translate_modules = ['all']

EOF

# Create Odoo Service
# Requires=postgresql.service
# After=network.target postgresql.service

sudo tee /etc/systemd/system/odoo18.service > /dev/null <<EOF
[Unit]
Description=Odoo18
After=network.target

[Service]
Environment=PATH=/usr/local/bin:/usr/bin:/bin:/sbin
Type=simple
SyslogIdentifier=odoo18
PermissionsStartOnly=true
User=ubuntu
Group=ubuntu
ExecStart=$ODOO_DIR/python3.12/bin/python3.12 /home/ubuntu/odoo/odoo18/odoo-bin -c $CONF_DIR/odoo.conf

StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF


sudo systemctl daemon-reload
sudo systemctl enable odoo18
sudo systemctl start odoo18

# Check Odoo Service
# sudo systemctl status odoo18
# sudo systemctl restart odoo18

# Go to http://localhost:8069

# Install Nginx and Configure
sudo apt install nginx-core -y
# config nginx for 

sudo tee /etc/nginx/sites-available/odoo18.conf > /dev/null <<EOF
upstream odoo_server {
    server 127.0.0.1:8069;
}

upstream odoo_chat_servers {
    server 127.0.0.1:8072;
}

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}


map \$sent_http_content_type \$content_type_csp {
    default "";
    ~image/ "default-src 'none'";
}

server {
    listen 80;
    server_name 127.0.0.1 localhost;
    # if (\$http_x_forwarded_proto != "https") {
    #         return 301 https://\$host\$request_uri;
    # }

    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.access.log;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    client_max_body_size 60M;

    location / {
        proxy_pass http://odoo_server;
        proxy_redirect off;

        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;

        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
        proxy_cookie_flags session_id samesite=lax secure;  # requires nginx 1.19.8
    }

    # Redirect websocket requests to odoo gevent port
    location /websocket {
        proxy_pass http://odoo_chat_servers;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;

        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
        proxy_cookie_flags session_id samesite=lax secure;  # requires nginx 1.19.8
    }

    location ~ ^/[^/]+/static/.+$ { 
        proxy_cache_valid 200 60m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo_server;
    }

    # common gzip
    gzip_types text/css text/scss text/plain text/xml application/xml application/json application/javascript;
    gzip on;
}
EOF

sudo ln -s /etc/nginx/sites-available/odoo18.conf /etc/nginx/sites-enabled/odoo18.conf

sudo nginx -t
sudo nginx -s reload

# Go to http://localhost