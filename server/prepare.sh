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


# This is a script to prepare an Amazon public Fedora AMI to build EC2 on Rails.
# It's intended to run an a public AMI such as this one:
# http://developer.amazonwebservices.com/connect/entry!default.jspa?categoryID=101&externalID=521 
#
# It must be run as root.

/etc/init.d/httpd stop
/etc/init.d/mysqld stop

cd /tmp

wget http://rubyforge.org/frs/download.php/19879/rake-0.7.3.tgz

tar xvf rake-0.7.3.tgz
cd rake-0.7.3
ruby install.rb

echo
echo "Now run 'rake'"
echo
