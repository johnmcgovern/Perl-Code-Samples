#!/usr/bin/perl
#
# archive.pl - archives files from specified directories in tar format
# by: jmcgovrn
#
# To restore, navigate to / and type tar -xvf /opt/archive/tarname
#

use strict;

# Path in which we pull the tarballs
my $archiveDir = '/opt/archive/';

foreach(<DATA>){

        # Go through each entry in the DATA file and make tar
        # (We will archive each individually)

        #    $1      $2
        if(m/(\w+)\s*\,\s*(\S+)/) {
                print "$1  $2 \n";
                makeTar($1,$2);
        }
}

# Returns a correctly formated date
sub getDate() {
        return `date "+%m%d%y"`;
}

sub makeTar() {
        my $name = shift;
        my $pathToFolder = shift;
        my $date = substr(getDate(),0,6);

        `tar -cpf $archiveDir$name-$date.tar $pathToFolder`;
}

# Folders to be backed up in format: name , folder
__DATA__
devdirone , /www/devdirone
alpine , /www/alpine
www , /www
home , /home
