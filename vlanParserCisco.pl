#!/usr/bin/perl
# vlanParser.pl

use strict;

# Array of Vlan Names
my @vlanNames;
$vlanNames[1] = "VLAN 1";
$vlanNames[2] = "VLAN 2";
$vlanNames[3] = "VLAN 3";

my @removeTheseVlans;


######################
#
#  Parse and Print!!!
#
######################

print "\n\n!----- Start of Vlan Rename Output -----\n\n\n";

print"conf t\n";
foreach (<DATA>){
	if(m/^(\d+).*/) {
		if($vlanNames[$1]){
			print "vlan $1\n name \"$vlanNames[$1]\" \n";
		}
	}
	
	# If there is no value in the array for a vlan 
	# then add it to the "remove" list
	if(!$vlanNames[$1]){
		$removeTheseVlans[$1] = "no vlan $1";
	}
}
print "end\nwr\n";

print "\n\n\n\n!----- End of Vlan Rename Output -----\n\n";
print "\n\n!----- Start of Vlan Removal Output -----\n\n";

# For each value in the remove list print out the "no" command 
# that we put in the array earlier
print"conf t\n";
foreach my $vlanString (@removeTheseVlans){
	if($vlanString ne ""){
		print "$vlanString\n"; 
	}
}
print "end\nwr\n";

print "\n\n\n!----- End of Vlan Removal Output -----\n\n";



#Enter show vlan CLI Output Here:
__DATA__
1    std   on     on     on    on     off   off   off     on   oldName                         
2    std   on     on     on    on     off   off   off     on   Blah  
3    std   on     on     on    on     off   off   off     on   Yuck                  

