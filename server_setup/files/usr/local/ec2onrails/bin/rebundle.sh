#!/bin/bash

#    This file is part of EC2 on Rails.
#    http://rubyforge.org/projects/ec2onrails/
#
#    Copyright 2007 Paul Dowman, http://pauldowman.com/
#
#    EC2 on Rails is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    EC2 on Rails is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


cleanup() {
  rm -f /ec2onrails-first-boot	
}

fail() {
  echo "`basename $0`: ERROR: $1"
  cleanup
  exit 1
}

if [ `whoami` != 'root' ] ; then
  fail "This script must be run as root, use 'sudo $0'".
fi

. "/usr/local/ec2onrails/config"

TIMESTAMP="`date '+%Y-%m-%d--%H-%M-%S'`"
NEW_BUCKET_NAME="$BUCKET_BASE_NAME-image-$TIMESTAMP"

if [ ! -e /usr/local/ec2-api-tools ] ; then
  echo "The EC2 api command-line tools don't seem to be installed."
  echo "To install them (and Java, which they require), press enter..."
  read
  curl http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip > /tmp/ec2-api-tools.zip || fail "couldn't download ec2-api-tools.zip"
  unzip /tmp/ec2-api-tools.zip -d /usr/local || fail "couldn't unzip ec2-api-tools.zip"
  chmod -R go-w /usr/local/ec2-api-tools*
  ln -sf /usr/local/ec2-api-tools-* /usr/local/ec2-api-tools
  aptitude install -y sun-java6-jre || fail "couldn't install Java package"
fi

echo "--> Clearing apt cache..."
aptitude clean

touch /ec2onrails-first-boot || fail

echo "--> Clearing sensitive files..."
rm -f /root/{.bash_history,.lesshst}

echo "--> Creating image..."
ec2-bundle-vol -e "/root/.ssh,/home/app/.ssh,/tmp,/mnt" -d /mnt -k "$EC2_PRIVATE_KEY" -c "$EC2_CERT" -u "$AWS_ACCOUNT_ID" || fail "ec2-bundle-vol failed"

echo "--> Uploading image to $NEW_BUCKET_NAME"
ec2-upload-bundle -b "$NEW_BUCKET_NAME" -m /mnt/image.manifest.xml -a "$AWS_ACCESS_KEY_ID" -s "$AWS_SECRET_ACCESS_KEY" || fail "ec2-upload-bundle failed"

echo "--> Registering image..."
ec2-register "$NEW_BUCKET_NAME/image.manifest.xml" || fail "ec2-register failed"

echo "--> Done."
cleanup
