#!/bin/sh

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

if [ `whoami` != 'root' ] ; then
  echo "This script must be run as root, use 'sudo $0'".
  exit 1
fi

. "/usr/local/ec2onrails/config"

TIMESTAMP="`date '+%Y-%m-%d--%H-%M-%S'`"
NEW_BUCKET_NAME="$BUCKET_BASE_NAME-image-$TIMESTAMP"

if [ ! -e /usr/local/ec2-api-tools ] ; then
  echo "The EC2 api command-line tools don't seem to be installed."
  echo "To install them (and Java, which they require), run"
  echo "/usr/local/ec2onrails/bin/install_ec2_api_tools.sh"
  exit
fi

echo "--> Setting runlevel to 1 and pausing for 10 seconds..."
runlevel --set=1
sleep 10

echo "--> Clearing sensitive files..."
/etc/init.d/sysklogd stop && cd /var/log && find . -type f | while read line; do cat /dev/null > "$line"; done && /etc/init.d/sysklogd start
rm -f /root/{.bash_history,.lesshst}

echo "--> Creating image..."
ec2-bundle-vol -e "/root/.ssh,/home/app/.ssh,/tmp,/mnt" -d /mnt -k "$EC2_PRIVATE_KEY" -c "$EC2_CERT" -u "$AWS_ACCOUNT_ID" || exit 3

echo "--> Uploading image to $NEW_BUCKET_NAME"
ec2-upload-bundle -b "$NEW_BUCKET_NAME" -m /mnt/image.manifest.xml -a "$AWS_ACCESS_KEY_ID" -s "$AWS_SECRET_ACCESS_KEY" || exit 4

echo "--> Registering image..."
ec2-register "$NEW_BUCKET_NAME/image.manifest.xml" || exit 5

echo "--> Done."

