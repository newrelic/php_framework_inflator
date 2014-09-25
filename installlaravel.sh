#! /bin/bash

#
# The MIT License (MIT)
#
# Copyright (c) 2014 New Relic
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

#
# Use this script to install laravel 4.0 and 4.1,
# and a bootstrap starter kit from:
#   https://github.com/andrewelkins/Laravel-4-Bootstrap-Starter-Site
#
# BE CAREFUL:
#   The script removes all source prior to checking it out from github.
#   The script first removes and then fills a mysql database
#     named "laravel40" or "laravel41"
#
# There must be localhost httpd/apache2 server running to serve up
#    localhost:9090/frameworks/laravel41/public/index.php
#    localhost:80/frameworks/laravel41/public/index.php
#
# To install on a stock LAMP system
#   bash -x ./installlaravel.sh --force --laravel41 --port 80 --root /var/www
#

set -e  # stop on first error
set -u  # undefined variable refs are an error

LAMPBIN=/opt/nr/lamp/bin
# export PATH=${LAMPBIN}:${PATH}

MYSQL=${LAMPBIN}/mysql
MYSQL=/usr/bin/mysql

PHP=${LAMPBIN}/php
PHP=/usr/bin/php  # may be either hhvm or zend
PHP=/usr/bin/php5  # almost surely zend
PHP=/etc/alternatives/php  # probably zend

#
# ROOT_DIR is the file system path to the root of the served directory
# TODO (24Sep2014): we haven't had much success with stock LAMP+hhvm using anything
# other than /var/www, but we haven't tried much.
#
if [ -e /var/www ] ; then
  ROOT_DIR=/var/www
elif [ -e /opt/nr/htdocs ] ; then
  ROOT_DIR=/opt/nr/htdocs
else
  echo can not find a plausible www root directory
fi

#
# Hiphop apparently has a bug regarding timeouts,
# that impacts its ability to bootstrap composer.
#
# for a recipe on making the HHVM php tolerate timeouts, see:
# http://stackoverflow.com/questions/23471864/installing-composer-using-vagrant-hhvm-and-ubuntu-14-04?noredirect=1#comment36017902_23471864
#
# Note that hiphop php doesn't implement php -i
#
if echo "<?php phpinfo();" | $PHP | grep -q -i hiphop ; then
  PHP="${PHP} -v ResourceLimit.SocketDefaultTimeout=30 -v Http.SlowQueryThreshold=30000 "
  echo "HipHop"
else
  echo "Zend"
fi

do_force=no    # overwrite an existing installation
do_yireo=no

do_laravel40=no
do_laravel41=no
port=9090      # for nrlamp; use port=80 for regular lamp

while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      shift
      ROOT_DIR=$1
      ;;

    --port)
      shift
      port=$1
      ;;

    --force|--do_force)
      do_force=yes
      ;;

    --laravel40|--do_laravel40)
      do_laravel40=yes
      ;;

    --laravel41|--do_laravel41)
      do_laravel41=yes
      ;;

  esac
  shift
done

#
# INSTALL_DIR is the file system view to the installation area
# BASE_URL    is the url         view to the installation area
#
INSTALL_DIR=${ROOT_DIR}/frameworks
BASE_URL=http://localhost:${port}/frameworks

if [ ! -e ${INSTALL_DIR} ] ; then
  mkdir -p ${INSTALL_DIR} || true
fi

#
# In order for laravel+artisan installation to run
# the stock zend php installation on ubuntu,
# php needs a pdo_mysql
#
# The Debian/Ubuntu systems package the PDO drivers for databases
# with the non-PDO versions
# (so similarly it would be php5-pgsql for both the pgsql
# and pdo_pgsql extensions).
#
# Here is some useful information:
#   http://www.howtoforge.com/ubuntu-lamp-server-with-apache2-php5-mysql-on-14.04-lts
#  http://askubuntu.com/questions/460837/mcrypt-extension-is-missing-in-14-04-server-for-mysql
#
if false ; then
  sudo apt-get install php5
  sudo apt-get install php5-mysql php5-pgsql
  sudo apt-get install php5-mcrypt
  sudo apt-get install libapache2-mod-php5
fi

#
# Usage: do_work $workdir $db_name $version
#
do_work() {
  workdir=$1
  db_name=$2
  version=$3
  composer_patch_function=$4

  #
  # if the work directory already exists, presume that we've been successful before
  #
  if [ "${do_force}" == "no" -a -e "${workdir}" ] ; then
    echo "Re-using pre-existing laravel installation ${workdir} ${version}"
    return
  fi

  local orig_dir=$(pwd)
  pushd $INSTALL_DIR > /dev/null 2>&1  # {

    #
    # Remove, no questions asked, the old data base, and make a new empty one
    #
    ${MYSQL} --user=root --password=root -e "drop   database if exists $db_name;"
    ${MYSQL} --user=root --password=root -e "create database           $db_name;"

    if true ; then
      #
      # Remove, no questions asked, the old source tree, prior to git cloning
      #
      rm -rf $workdir
      git clone https://github.com/andrew13/Laravel-4-Bootstrap-Starter-Site $workdir
    fi
    pushd $workdir > /dev/null 2>&1  # {
      git checkout $version
      local stable_composer=${orig_dir}/../scripts/composer_installer.phar
      if [ ! -e "${stable_composer}" ] ; then
        curl --silent http://getcomposer.org/installer > ${stable_composer}
      fi

      #
      # TODO: Jun2014: This works with the zend php, but not with the hhvm php
      #
      if [ -e "${stable_composer}" ] ; then
        cat ${stable_composer} | ${PHP}
      else
        curl --silent http://getcomposer.org/installer | ${PHP}
      fi

      #
      # Patch the composer.json file as necessary
      #
      if [ -n "${composer_patch_function}" ] ; then
        $composer_patch_function composer.json
      fi

      #
      # This step can be quite slow,
      # especially if the New Relic agent is logging extensively
      # composer kind of sucks in this regard.
      #
      ${PHP} composer.phar install --dev
    popd > /dev/null 2>&1  # }

    #
    # Fill in configuration files
    #
    local hostname=$(hostname)
    pushd $workdir > /dev/null 2>&1  # {
       < bootstrap/start.php \
        sed \
          -e "s/'local' =>.*/'local' => array('${hostname}'),/" \
          -e "s/'staging' =>.*/'staging' => array('${hostname}'),/" \
          -e "s/'production' =>.*/'production' => array('${hostname}'),/" \
        > bootstrap/new.start.php
      mv bootstrap/new.start.php bootstrap/start.php

      mkdir -p app/config/local || true

        # -e "s#'url'.*#'url' => '$BASE_URL/$workdir',#"
      local xBASE_URL=http://127.0.0.1:${port}

      < app/config/app.php \
      sed \
        -e "s#'url'.*#'url' => '$xBASE_URL',#" \
        -e "s#'key'.*#'key' => 'KEY',#" \
      > app/config/new.app.php

      cp app/config/new.app.php app/config/app.php
      cp app/config/new.app.php app/config/local/app.php

      < app/config/database.php \
      sed \
        -e "s/'database'.*=>.*/'database' => '$db_name',/" \
        -e "s/'username'.*=>.*/'username' => 'root',/" \
        -e "s/'password'.*=>.*/'password' => 'root',/" \
        -e "s#'key'.*#'key' => 'KEY',#" \
      > app/config/new.database.php
      cp app/config/new.database.php app/config/local/database.php
      cp app/config/new.database.php app/config/database.php

      ${PHP} artisan migrate
      ${PHP} artisan db:seed

      #
      # It is not clear if we really need this key
      #
      local key=$(${PHP} artisan key:generate --env=local)

      #
      # get Laravel version information in two different ways
      #
      grep VERSION ./vendor/laravel/framework/src/Illuminate/Foundation/Application.php
      ${PHP} artisan --version

      if wget --quiet --output-document=- $BASE_URL/$workdir/public/index.php | grep --silent -i 'lorem' ; then
        echo "Web Server returns LOREM IPSUM.  This is good!"
      else
        echo "Web Server is not returning desired content.  This is bad."
      fi

    popd > /dev/null 2>&1 # }

  popd > /dev/null 2>&1 # }
}

laravel40_composer_patch_function() {
  #
  # TODO: sed in place composer.json
  #
  # This seems to be a consistent set of composer dependencies,
  # snapshotted around of 2013-10-21
  # to support Laravel 4.0.9
  # This was determined empirically by looking at packagist:
  #   https://packagist.org/packages/zizaco/confide
  #   https://packagist.org/packages/zizaco/entrust
  #   https://packagist.org/packages/laravel/framework
  #
  < composer.json \
  sed \
    -e 's#"laravel/framework".*#"laravel/framework": "4.0.9",#' \
    -e 's#"zizaco/confide".*#"zizaco/confide": "2.0.0b4",#' \
    -e 's#"zizaco/entrust".*#"zizaco/entrust": "v0.4.0beta",#' \
  > composer.json.new
  mv composer.json.new composer.json
}

null_composer_patch_function() {
  : empty
}

if [ "${do_laravel40}" == "yes" ] ; then
  workdir=laravel40
  db_name=laravel40
  version=bfa33379608549bf929862cd055b265168ea7570
  do_work laravel40 laravel40 $version laravel40_composer_patch_function
fi

if [ "${do_laravel41}" == "yes" ] ; then
  workdir=laravel41
  db_name=laravel41
  version=master
  do_work laravel41 laravel41 $version null_composer_patch_function
fi
