#!/bin/bash

RHODE_ROOT=/var/www/rhode
RHODE_VENV=$RHODE_ROOT/venv

BLOOD_ROOT=/var/www/blood
BLOOD_VENV=$BLOOD_ROOT/venv

REPO=$(pwd)

dependencies_install() {
  yum -y update;
  yum -y install vim nano git mercurial svn ntp openssh-clients wget gcc gcc-c++ make python-devel httpd httpd-devel openssl mod_ssl apr-devel apr-util devel curl-devel

  # installs epel 6.8 repo
  rpm -Uvh http://mirror.itc.virginia.edu/fedora-epel/6/i386/epel-release-6-8.noarch.rpm

  yum -y update
  yum -y install erlang sqlite sqlite-devel openldap openldap-clients openldap-devel openssl-devel mod_wsgi

  # ruby stuff
  yum -y install ruby rubygems rubygem-passenger rubygem-passenger-native rubygem-rake ruby-rdoc ruby-devel ImageMagick-devel
}

rabbitmq_install() {
  rpm -Uvh http://www.rabbitmq.com/releases/rabbitmq-server/v3.2.2/rabbitmq-server-3.2.2-1.noarch.rpm

  chkconfig --add rabbitmq-server
  chkconfig --level 345 rabbitmq-server on

  # run rabbitmq for settings
  service rabbitmq-server start

  rabbitmqctl add_user rhodeuser rhodepass
  rabbitmqctl add_vhost rhodevhost
  rabbitmqctl set_permissions -p rhodevhost rhodeuser ".*" ".*" ".*"

  service rabbitmq-server stop
}

virtualenv_install() {
  # ez_setup and pip install
  wget https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -O - | python
  wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py -O- | python

  pip install virtualenv virtualenvwrapper

  mkdir -p $RHODE_VENV
  virtualenv --no-site-packages $RHODE_VENV
}

rhodecode_install() {

  mkdir $RHODE_ROOT/data $RHODE_ROOT/repos /var/run/rhodecode /var/log/rhodecode
  cd $RHODE_ROOT/data
  source $RHODE_VENV/bin/activate

  ##### now inside virtual environment
  ####
  ###
  ##
  #
  easy_install pastescript
  pip install https://rhodecode.com/dl/latest
  paster make-config RhodeCode production.ini

  # change
  #[server:main]
  #host = 0.0.0.0

  #[app:main]
  #use_celery = true
  #broker.vhost = rhodevhost
  #broker.user = rhodeuser
  #broker.password = rhodepass
  vim production.ini

  paster setup-rhodecode production.ini
  deactivate # leaves virtualenv
}


rhodecode_boot() {
  adduser rhodecode -U -b $RHODE_ROOT
  chown -R rhodecode:rhodecode $RHODE_ROOT /var/log/rhodecode /var/run/rhodecode
  cd $REPO
  # tmp location of gist for init
  chmod +rwx $REPO/ale-rhodecode.sh

  cp ./ale-rhodecode.sh /etc/init.d/rhodecode
  chkconfig --add rhodecode
  chkconfig --level 345 rhodecode on
}

bloodhound_install() {
  mkdir -p $BLOOD_VENV $BLOOD_ROOT/data

  svn co https://svn.apache.org/repos/asf/bloodhound/trunk/ $BLOOD_ROOT/bloodhound

  virtualenv --no-site-packages $BLOOD_VENV

  cd $BLOOD_ROOT/bloodhound/installer
  # inside
  source $BLOOD_VENV/bin/activate
  pip install -r requirements.txt

  python bloodhound_setup.py \
    --environments_directory=$BLOOD_ROOT/data \
    -d sqlite

  hg clone http://hg.edgewall.org/trac/mercurial-plugin
  cd $BLOOD_ROOT/bloodhound/installer/mercurial-plugin
  python setup.py bdist_egg
  python setup.py install

  # apache setup
  trac-admin $BLOOD_ROOT/data/main/ deploy $BLOOD_ROOT/data/site

  deactivate

  cp $REPO/bloodhound.conf /etc/httpd/conf.d/bloodhound.conf
}

redmine_install() {

  cd /var/www
  svn co http://svn.redmine.org/redmine/branches/2.4-stable redmine
  cd redmine

  cp ./config/dtabase.yml.example
  cat >> ./config/database.yml << EOF
  production:
    adapter:  sqlite3
    database: db/redmine.db
EOF

  gem update
  gem install rack
  gem install passenger
  gem install bundler

  bundle install
  gem install sqlite3

  rake generate_secret_token
  bundle exec rake db:migrate RAILS_ENV="production"
  bundle exec rake redmine:load_default_data RAILS_ENV="production"

  cd public
  cp dispatch.fcgi.example dispatch.fcgi
  cp htaccess.fcgi.example .htaccess

  chown -R apache:apache /var/www/redmine
  chmod -R 755 redmine
}

apache_setup() {
  cd $REPO
  cp redmine.conf /etc/httpd/conf.d
  cp rhodecode.conf /etc/httpd/conf.d

  cat >> /etc/httpd/conf/httpd.conf << EOF
  NameVirtualHost *:443
  RewriteEngine On
  RewriteCond %{HTTPS} off
  RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}
EOF

  # required for redmine
  passenger-install-apache2-module

  setsebool -P httpd_can_network_connect 1

  setenforce Permissive
  cat > /etc/selinux/config << EOF
  # This file controls the state of SELinux on the system.
  # SELINUX= can take one of these three values:
  #     enforcing - SELinux security policy is enforced.
  #     permissive - SELinux prints warnings instead of enforcing.
  #     disabled - No SELinux policy is loaded.
  SELINUX=permissive
  # SELINUXTYPE= can take one of these two values:
  #     targeted - Targeted processes are protected,
  #     mls - Multi Level Security protection.
  SELINUXTYPE=targeted
EOF

  chkconfig --level 345 httpd on
  service httpd configtest

}

vifm_install() {
  cd $REPO/tmp
  yum install -y ncurses-devel ncurses
  wget http://downloads.sourceforge.net/project/vifm/vifm/vifm-0.7.6.tar.bz2?r=http%3A%2F%2Fvifm.sourceforge.net%2Fdownloads.html&ts=1389042330&use_mirror=hivelocity
  tar xvf vifm*bz2
  cd vifm*
  ./configure --prefix=/usr
  make; make install
}

#ssl_setup() {
  # NEED to setup for https on redmine and rhodecode
#}

# Quick and dirty install
if [ $(whoami) != "root" ]; then
  echo "need to run as root."
  exit 2
else
  mkdir $REPO/tmp
  cd $REPO/tmp

  dependencies_install
  vifm_install
  rabbitmq_install
  virtualenv_install

  rhodecode_install
  rhodecode_boot

  redmine_install

  apache_setup
fi
