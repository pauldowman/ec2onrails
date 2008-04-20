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


# Generate a new self-signed cert and key for https

echo "Generating default self-signed SSL cert and key..."

export RANDFILE=/tmp/randfile

cd /tmp
openssl genrsa -out server.key 1024
openssl req -new -key server.key -out server.csr <<END
CA
.
.
.
.
.
.
.
.

END
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt

mkdir -p /etc/ec2onrails/ssl/cert
mkdir -p -m 700 /etc/ec2onrails/ssl/private
mv server.key /etc/ec2onrails/ssl/private/ec2onrails-default.key
mv server.crt /etc/ec2onrails/ssl/cert/ec2onrails-default.crt
rm $RANDFILE
rm server.csr
