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


# This one is a bit of a hack: We need to set the path for non-interactive 
# ssh commands for the app user, it needs the gem bin dir because
# capistrano assumes it's in the path
echo 'PATH=/usr/local/bin:/usr/bin:/bin:/var/lib/gems/1.8/bin' > /home/app/.ssh/environment
echo 'PATH=/usr/local/bin:/usr/bin:/bin:/var/lib/gems/1.8/bin' > /home/admin/.ssh/environment
