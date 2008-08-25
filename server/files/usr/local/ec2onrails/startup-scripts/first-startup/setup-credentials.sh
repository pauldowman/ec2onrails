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
#
#    This file helps spread the root key so we can log in/deploy using the 
#    app user instead of root, but with the same ec2 key

#make sure we have the credentials
/etc/init.d/ec2-get-credentials

mkdir -p -m 700 /home/app/.ssh
cp /root/.ssh/authorized_keys /home/app/.ssh
chown -R app:app /home/app/.ssh
