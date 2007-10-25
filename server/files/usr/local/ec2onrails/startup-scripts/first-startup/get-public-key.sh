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


# Get public key for the keypair that this AMI instance was started with, and
# save it as /root/.ssh/authorized_keys and /home/app/.ssh/authorized_keys
# Note that the file is completely replaced, not appended to. This is so
# that it doesn't grow with every reboot.

# Get root's authorized_keys file
mkdir -p -m 700 /root/.ssh
/usr/bin/curl http://169.254.169.254/2007-08-29/meta-data/public-keys/0/openssh-key > /root/.ssh/authorized_keys

# In case the http get failed.
if [ ! -s /root/.ssh/authorized_keys ] ; then
  cp /mnt/openssh_id.pub /root/.ssh/authorized_keys
fi

chmod 600 /root/.ssh/authorized_keys

# copy it to the users:

mkdir -p -m 700 /home/app/.ssh
cp /root/.ssh/authorized_keys /home/app/.ssh
chown -R app:app /home/app/.ssh

mkdir -p -m 700 /home/admin/.ssh
cp /root/.ssh/authorized_keys /home/admin/.ssh
chown -R admin:admin /home/admin/.ssh
