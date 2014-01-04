#!/bin/bash

RHODE_ROOT=/var/www/rhode

RHODE_VENV=$RHODE_ROOT/venv


# Quick and dirty install
if [ $(cat whoami ) -eq "root" ]; then 
  echo "need to run as root."
  exit 2
else
  mkdir ~/tmp && cd ~/tmp;
  
  dependencies
  rabbitmq_install
  virtualenv_install
  
  rhodecode_install
  rhodecode_boot
fi

dependencies_install() {
  yum -y update; 
  yum -y install vim ntp openssh-clients wget gcc make python-devel
  
  # installs epel 6.8 repo
  rpm -Uvh http://mirror.itc.virginia.edu/fedora-epel/6/i386/epel-release-6-8.noarch.rpm
  
  yum -y update
  yum -y install erlang openldap openldap-clients openldap-devel openssl-devel 
}


rabbitmq_install() {
  rpm -Uvh http://www.rabbitmq.com/releases/rabbitmq-server/v3.2.2/rabbitmq-server-3.2.2-1.noarch.rpm
  rabbitmqctl add_user rhodeuser rhodepass
  rabbitmqctl add_vhost rhodevhost
  rabbitmqctl set_permissions -p rhodevhost rhodeuser ".*" ".*" ".*" 
}


virtualenv_install() {
  # ez_setup and pip install
  wget https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -O - | python
  wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py -O- | python
  
  easy_install virtualenv virtualenvwrapper
  
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
  easy_install rhodecode
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
  cd ~/tmp
  # tmp location of gist for init
  wget  "https://gist.github.com/abaez/89bbda3d46c8b681cea1/raw/88021509003cf3779d518327ab3785d23df4a338/ale-rhodecode.sh"
  chmod +rwx ./ale-rhodecode.sh
  
  cp ./ale-rhodecode.sh /etc/init.d/rhodecode
  
}
