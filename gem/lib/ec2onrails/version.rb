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

module Ec2onrails #:nodoc:
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 9
    TINY  = 9
    BUGFIX  = 1
    STRING = [MAJOR, MINOR, TINY, BUGFIX].join('.')
    
    AMI_ID_32_BIT_US = 'ami-5394733a'
    AMI_ID_64_BIT_US = 'ami-5594733c'

    AMI_ID_32_BIT_EU = 'ami-761c3402'
    AMI_ID_64_BIT_EU = 'ami-701c3404'
  end
end
