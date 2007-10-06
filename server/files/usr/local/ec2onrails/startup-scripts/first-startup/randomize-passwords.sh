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


# Set the password for the user named "app" to a random value
echo app:`dd if=/dev/urandom count=50 | md5sum` | chpasswd

# Set the password for the user named "admin" to a random value
echo admin:`dd if=/dev/urandom count=50 | md5sum` | chpasswd

# Set the password for root to a random value (this is redundant 
# since root login is disabled) 
echo root:`dd if=/dev/urandom count=50 | md5sum` | chpasswd

