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

make_dir() {
  mkdir -p $1
  if [ $2 ] ; then
    chown -R $2 $1
  fi
}

make_dir /mnt/app         app:app

#make sure it is setup to be able to be read/written by app user
make_dir /etc/ec2onrails  app:app

make_dir /mnt/log
make_dir /mnt/log/nginx   nginx:nginx
make_dir /mnt/log/fsck
qmake_dir /mnt/log/mysql   mysql:mysql

make_dir /mnt/tmp
chmod 777 /mnt/tmp
