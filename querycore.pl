#!/usr/bin/perl
###### Query Core 
## Query the core for the ip addresse of
## Mac Addresses in its arp table and 
## puts them in the MySQL table `core_ips`

use DBD::MySQL;
use Net::Telnet::Cisco;

## Configure options...

my $host	= '10.10.10.10';	 	# MySQL host
my $database 	= 'dbname';   		# MySQL Database
my $table	= 'core_ips'; # MySQL table in database
my $user	= 'username';
my $password	= 'fakePassword';	# MySQL Username and password
my $switchUser 	= 'switchUser';		
my $switchPass 	= 'fakePassword';		# Switch username and password

## Script...

## !! CHANGE NOTHING BELOW THIS LINE !!
#######################################

$dbh = DBI->connect("dbi:MySQL:$database:$host", $user, $password);
my @coreip = ('10.1.1.1', '10.2.2.2', '10.3.3.3', '10.4.4.4');

my ($mac, $ip, $vlan);
foreach (@coreip) {
	@data = runCiscoCmd($_);
		foreach (@data){
		if(/Internet[\s]*([\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3})[\s]*([-\d]+)[\s]*([\da-fA-F]{4})\.([\da-fA-F]{4})\.([\da-fA-F]{4})[\s]*ARPA[\s]*Vlan([\d]*)[\n]*/ or /Internet[\s]*([\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3})[\s]*([-\d]+)[\s]*([\da-fA-F]{4})\.([\da-fA-F]{4})\.([\da-fA-F]{4})[\s]*ARPA[\s]*GigabitEthernet.*[\.]([\d]+)/) {
			$ip = $1;
			$mac = $3.$4.$5;
			$vlan = $6;
			insertIntoDB($ip,$mac,$vlan);
		}
	}
}
sub insertIntoDB {
	$ip = shift;
	$mac = shift;
	$vlan = shift;
	$dbh->do("INSERT INTO `core_ips` VALUES ('".$ip."','".$mac."','".$vlan."',CURRENT_TIMESTAMP) 
		ON DUPLICATE KEY UPDATE `ip`='".$ip."'");
}

sub runCiscoCmd {
	$coreip = shift;
	# Open session
	$session = Net::Telnet::Cisco->new(Host => $coreip);
	$session->login($switchUser,$switchPass);
	# Execute a command
	@output = $session->cmd("show ip arp");
	# Close session
	$session->close();
	# Return array
	return @output;
}
