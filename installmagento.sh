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
# Use this script to install magento CE 1.6, 1.7 or 1.8.
#
# The script fills a mysql database named "magento16", "magento17" or "magento18"
# with sample data for the sample store front
#
# This script can install the magento2 distribution from github.
# As of 11mar2014, there are no data base dumps for a sample magento2 store front.
#
# Edit the admin names, below, as necessary.
# Note that the admin_password has to be pretty strong for Magento to accept it.
#
# There must be localhost httpd server running
#

set -e
set -u

do_force=no    # overwrite an existing installation
do_install=no  # Run the magento installation script
do_yireo=no

do_magento16=no
do_magento17=no
do_magento18=no
do_magento20=no  # not fully implemented

while [ $# -gt 0 ]; do
  case "$1" in
    --force|--do_force)
      do_force=yes
      ;;
    --install|--do_install)
      do_install=yes
      ;;
    --yireo|--do_yireo)
      do_yireo=yes
      ;;
    --magento16|--do_magento16)
      do_magento16=yes
      ;;
    --magento17|--do_magento17)
      do_magento17=yes
      ;;
    --magento18|--do_magento18)
      do_magento18=yes
      ;;
    --magento20|--do_magento20)
      do_magento20=yes
      ;;
  esac
  shift
done

#
# Perhaps follow instructions here:
#   http://www.magentocommerce.com/wiki/1_-_installation_and_configuration/installing_magento_via_shell_ssh#installing_magento_with_the_full_download_sample_data
#

INSTALL_DIR=/var/www/frameworks
URL_PATH="localhost:80/frameworks/"
fi
if [ ! -e ${INSTALL_DIR} ] ; then
  mkdir -p ${INSTALL_DIR}
fi

#
# Usage: do_install_magento $workdir $db_name $version $install_file
#
do_install_magento() {
  workdir=$1
  db_name=$2
  version=$3
  install_file=$4

  #
  # if the work directory already exists, presume that we've been successful before
  #
  if [ "${do_force}" == "no" -a -e "${workdir}" ] ; then
    echo "Re-using pre-existing magento installation ${workdir} ${version}"
    return
  fi

  #
  # Download, as needed, the tar files
  #
  if [ ! -e magento-${version}.tar.gz ] ; then
    echo "wget magento source"
    wget http://www.magentocommerce.com/downloads/assets/${version}/magento-${version}.tar.gz
  fi

  if [ ! -e magento-sample-data-1.6.1.0.tar.gz ] ; then
    echo "wget magento demo store data"
    wget http://www.magentocommerce.com/downloads/assets/1.6.1.0/magento-sample-data-1.6.1.0.tar.gz
  fi

  if [ ! -e Yireo_NewRelic-1.2.0.tgz ] ; then
    echo "wget magento yireo 1.2.0 extension"
    wget http://freegento.com/magento-extensions/Yireo_NewRelic-1.2.0.tgz
  fi

  if [ ! -e Yireo_NewRelic-1.2.1.tgz ] ; then
    if false ; then
      #
      # Yireo 1.2.1 released on 11Mar2014, but it isn't installed as a sibling to 1.2.0
      # Diffing, the only difference between 1.2.0 and 1.2.1 is
      # the change of license from OSL to BSD.
      #
      echo "wget magento yireo 1.2.1 extension"
      wget http://freegento.com/magento-extensions/Yireo_NewRelic-1.2.1.tgz
    fi
  fi

  echo "install magento-${version}"
  rm -rf magento || true     # the tar files create a top level directory magento
  tar xf magento-${version}.tar.gz
  rm -rf ${workdir} || true  # Remove any previous instane of the working directory
  mv magento ${workdir}

  echo "install magento sample data"
  rm -rf magento-sample-data-1.6.1.0 || true
  tar xf magento-sample-data-1.6.1.0.tar.gz

  mv magento-sample-data-1.6.1.0/media/*                             ${workdir}/media/
  mv magento-sample-data-1.6.1.0/magento_sample_data_for_1.6.1.0.sql ${workdir}/data.sql

  chmod -R o+w ${workdir}/media ${workdir}/var
  chmod -R o+w ${workdir}/var   ${workdir}/var/.htaccess ${workdir}/app/etc

  if [ "${do_yireo}" == "yes" ] ; then
    pushd ${workdir}
      tar zxvf ../Yireo_NewRelic-1.2.0.tgz
      ls -l app/code/community
    popd
  fi

  #
  # That's right, we just unpacked the magento-sample-data into the magento directory,
  # but we presume that is OK for magento2 as well (TODO: check this assumption)
  #
  # Per https://github.com/magento/magento2/issues/30 (2012 timeframe)
  # Magento1.x data dumps are incompatible with Magento2.x data dumps
  #
  pushd ${workdir} > /dev/null 2>&1
    echo "rebuild database using ${db_name}"
    which mysql
    mysql --user=root --password=root -e "drop database if exists ${db_name}"
    mysql --user=root --password=root -e "create database         ${db_name}"
    if [ "${do_magento20}" == "yes" ] ; then
      echo "No sample data for magento2 installations"
    else
      mysql --user=root --password=root                           ${db_name} < data.sql
    fi
  popd

  #
  # Run the installation script.
  # The apached/httpd must be running on the required port
  #
  # The fw_magento framework engine in the agent must be functioning.
  #
  if [ "${do_install}" == "yes" ] ; then
    echo "run install script"

    pushd ${workdir} > /dev/null 2>&1
      if [ -e "${install_file}" ] ; then

        #
        # TODO: This doesn't work for magento2 (10Mar2014)
        #
        php -f "${install_file}" -- \
          --license_agreement_accepted "yes" \
          --locale "en_US" \
          --timezone "America/Los_Angeles" \
          --default_currency "USD" \
          --db_host "localhost" \
          --db_name "${db_name}" \
          --db_user "root" \
          --db_pass "root" \
          --url "${URL_PATH}${workdir}" \
          --use_rewrites "yes" \
          --use_secure "no" \
          --secure_base_url "" \
          --use_secure_admin "no" \
          --admin_firstname "Magento" \
          --admin_lastname "Magento" \
          --admin_username "magento" \
          --admin_password "magento4now"

      else
        echo "no install.php script found"
      fi

    popd
  fi
}

pushd ${INSTALL_DIR} > /dev/null 2>&1  # {

if [ "${do_magento20}" == "yes" ] ; then
  workdir=magento2
  db_name=magento2
  version="?"
  install_file="dev/shell/install.php"
  if [ ! -e "magento2" ] ; then
    git clone git@github.com:magento/magento2.git
  fi
  do_install_magento magento2 magento2 '?' $install_file
fi

if [ "${do_magento16}" = "yes" ] ; then
  do_install_magento magento16 magento16 1.6.2.0 install.php
fi

if [ "${do_magento17}" = "yes" ] ; then
  do_install_magento magento17 magento17 1.7.0.0 install.php
fi

if [ "${do_magento18}" = "yes" ] ; then
  do_install_magento magento18 magento18 1.8.1.0 install.php
fi

popd  # }
