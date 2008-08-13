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


# This script runs the EC2 on Rails rakefile, it's meant to be called by
# Eric Hammond's Ubuntu build script: http://alestic.com/


if [ -z `which rake` ] ; then
  echo "Installing rake..."
  (
  cd /tmp
  wget http://rubyforge.org/frs/download.php/29752/rake-0.8.1.tgz
  tar xvf rake-0.8.1.tgz
  cd rake-0.8.1
  ruby install.rb
  )
fi

cd `dirname $0`

if [ $(uname -m) = 'x86_64' ]; then
  export ARCH=x86_64
  rake
else
  rake
fi
