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

curl http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip > /tmp/ec2-api-tools.zip
unzip /tmp/ec2-api-tools.zip -d /usr/local
chmod -R go-w /usr/local/ec2-api-tools*
ln -sf /usr/local/ec2-api-tools-* /usr/local/ec2-api-tools

aptitude install -y sun-java6-jre