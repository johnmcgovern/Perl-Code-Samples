#!/usr/bin/perl
# mactrack.pl
# Track up/down status of sh ip arp macs in MySQL

use strict;
use DBI;
use Net::Telnet::Cisco;

my $dbh = DBI->connect('DBI:mysql:mactrack:127.0.0.1','admin','fakePassword')
	or die "Couldn't connect to DB";

my $switchUser = 'admin';
my $switchPass = 'fakePassword';

my @returnInfo;
my @returnUpDevices;

my $eep = returnLastDBRecords();


# GET SH IP ARP FROM THE CORE AND PUT RELEVANT INFO INTO AN ARRAY
@returnInfo = runCiscoCmd('sh ip arp','1.1.1.1');

# SPLIT OUT EACH LINE OF INTO INTO A SCALAR
foreach $_ (@returnInfo){
	#               $1 IP ADDRESS                          AGE   $2 MAC ADDR                                          $3 VLAN ID        
	if(m/Internet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+\S+\s+([0-9a-z]{4}\.[0-9a-z]{4}\.[0-9a-z]{4})\s+ARPA\s+Vlan(\d+)/){
	
		# if a mac is not in devices_mac add it to db
		if(!findMac($2)){
			addMacToDB($2);
		}
		
		# see if a combo from the array is in the database in change_history
		if(findCombo($1,$2)){
			# if the combo is down in the database, but exists in 'sh ip arp'
			# add a new change_history record for the up status
			if(findLatestChangeStatus($1,$2) ne 'up'){
				addChangeRecord($1,$3,$2,'up');
			}
			
		}
		
		#REDUNDANT FROM 1ST IF STATEMENT
		#else{
		#	# if the MAC IP combo doesn't exist, add it to change_history with 'up' status
		#	addChangeRecord($1,$3,$2,'up');
		#}
		

	
	}
}

# NOW DEAL WITH RECORDS WE ALREADY HAVE STORED AND NEED TO CHECK IF THEY WENT DOWN
# IF THEY DID GO DOWN AND THEY NEED TO GO UP, WE WILL ADD A NEW RECORD WITH UP STATUS

@returnUpDevices = returnLastUpDBRecords();

print "@returnUpDevices \n";

foreach $_ (@returnUpDevices){
        #    $1 IP                                 $2 MAC
	if(m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s([0-9a-z]{12})/){
		if(!isComboAlive($1,$2)){
			#print "Found device down: $1 $2 - setting to down\n";
			addChangeRecord($1,'',$2,'down');
		}
		
	}
}


$dbh->disconnect();


# takes a command and a swith IP and returns the results in an array
# used for 'show ip arp'
sub runCiscoCmd {
	my $switchCMD = shift;
	my $switchIP  = shift;
	
	# Open session
	my $session = Net::Telnet::Cisco->new(Host => $switchIP);
	$session->login($switchUser,$switchPass);
	
	# Execute a command
	my @output = $session->cmd($switchCMD);
	
	# Close session
	$session->close;
	
	# Return array
	return @output;
}


# takes a mac and returns whether or not is is in the devices_mac table
# found=true , '' = false
sub findMac {
	my $inMac = removeMacDots(shift);
	my $macAddr = '';
		
	my $sth = $dbh->prepare('SELECT mac 
				 FROM device_mac 
				 WHERE mac=?;')
	or die "Couldn't prepare statement: ". $dbh->errstr;
	
	$sth->execute($inMac)
	or die "Can't excecute statement";
	
	$sth->bind_columns( \$macAddr );
	$sth->fetch();
	$sth->finish();
	
	if($macAddr eq ''){ 
		return '';
	}
	else{
		return 'found';
	}
}


# takes an IP and a MAC and returns whether or not the combo is in the change_history table
# found=true , '' = false
sub findCombo {
	my $inIP   = shift;
	my $inMAC  = removeMacDots(shift);
	my $ipAddr = '';
		
	my $sth = $dbh->prepare('SELECT ip 
				 FROM change_history 
				 WHERE ip=? 
				 AND mac=?;')
	or die "Couldn't prepare statement: ". $dbh->errstr;
	
	$sth->execute($inIP, $inMAC)
	or die "Can't excecute statement";
	
	$sth->bind_columns( \$ipAddr );
	$sth->fetch();
	$sth->finish();
	
	if($ipAddr eq ''){ 
		return '';
	}
	else{
		return 'found';
	}
}


# given a IP and a MAC (dots left in), this find out if a combo exists in the array 
# and therefore if exists in 'show ip arp'
sub isComboAlive{
	my $inIP  = shift;
	my $inMAC = shift;	

	foreach $_ (@returnInfo){
		#               $1 IP ADDRESS                          AGE   $2 MAC ADDR                                          $3 VLAN ID        
		if(m/Internet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+\S+\s+([0-9a-z]{4}\.[0-9a-z]{4}\.[0-9a-z]{4})\s+ARPA\s+Vlan(\d+)/){
			if(($inIP eq $1) && ($inMAC eq $2)){
				print "Combo alive!\n";
				return 'found';
			}
		}
	}
	
	return '';
}


sub returnLastUpDBRecords{
		my $counter = 0;
		my $pullIP;
		my $pullMAC;
		
		my @upDevices;
		
		my $sth = $dbh->prepare("SELECT ip,mac
		 			 FROM change_history
		           		 WHERE id IN (
					 SELECT MAX(id)
					 FROM change_history
					 GROUP BY ip,mac)
					 AND status_changed_to='up'")
				or die "Couldn't prepare statement: ". $dbh->errstr;
		
		$sth->execute()
		or die "Can't excecute statement";
		
		$sth->bind_columns( \$pullIP, \$pullMAC );
		
		while($sth->fetch()){
			$upDevices[$counter] = "$pullIP $pullMAC";
			$counter++;
		}
		
		$sth->finish();
		
		return @upDevices;
}

sub returnLastDBRecords{
		my ($ip,$mac,$status_changed_to);
		
		my $upDevices;
		
		my ($id,$idstr);
		my $sth = $dbh->prepare("SELECT MAX(id) AS id FROM change_history GROUP BY ip,mac")
				or die "Couldn't prepare statement: ". $dbh->errstr;		
		$sth->execute()
		or die "Can't excecute statement";

		$sth->bind_columns( \$id );

		my $i = 0;
		while($sth->fetch()){
			if (!$i) { $idstr = $id; }
			else { $idstr = $idstr . ",$id"; }
			$i++;
		}
		print $idstr;		
		$sth->finish();

		$sth = $dbh->prepare("SELECT ip,mac,status_changed_to FROM change_history WHERE id IN ($idstr)")
				or die "Couldn't prepare statement: ". $dbh->errstr;		
		$sth->execute()
		or die "Can't excecute statement";
			
		$sth->bind_columns( \$ip, \$mac, \$status_changed_to );
		
		while($sth->fetch()){
			$upDevices->{$ip}->{$mac}->{status} = $status_changed_to;
		}
		$sth->finish();

		return $upDevices;
}

sub findLatestChangeStatusC {
	my $inIP;
}
# takes in IP and MAC combo and tells whether it is up, down, or NULL
sub findLatestChangeStatus{
	my $inIP  = shift;
	my $inMAC = removeMacDots(shift);
	my $pullStatus = '';
		
	my $sth = $dbh->prepare('SELECT status_changed_to 
					FROM change_history 
					WHERE change_time = ( 
					SELECT max( change_time ) 
					FROM change_history 
					WHERE ip = ? AND mac = ? ) 
					AND ip = ? AND mac = ?')	
			or die "Couldn't prepare statement: ". $dbh->errstr;
	
	$sth->execute($inIP,$inMAC,$inIP,$inMAC)
	or die "Can't excecute statement";
	
	$sth->bind_columns( \$pullStatus );
	$sth->fetch();
	$sth->finish();
	
	if($pullStatus eq ''){ 
		return '';
	}
	elsif($pullStatus eq 'up'){
		return 'up';
	}
	elsif($pullStatus eq 'down'){
		return 'down';
	}
}

# takes in IP and MAC and adds an entry to change_history
sub addChangeRecord {
	my $inIP  = shift;
	my $inVLAN = shift;	
	my $inMAC = removeMacDots(shift);
	my $inStatus = shift;
	
	my $sth = $dbh->prepare("INSERT INTO change_history (id,ip,vlan,mac,change_time,status_changed_to)
					VALUES (
  					NULL,
  					?,
  					?,
  					?,
  					NOW(),
  					? 
  					)")
		or die "Couldn't prepare statement: ". $dbh->errstr;

	$sth->execute($inIP, $inVLAN, $inMAC, $inStatus)
		or die "Can't excecute statement";
		
	$sth->finish();		
}


# takes in mac and adds it to the devices_mac table
sub addMacToDB {
	my $inMac = removeMacDots(shift);
	
	my $sth = $dbh->prepare("INSERT INTO device_mac (mac,first_seen,last_seen,status) VALUES (?, NOW(), NOW(), 'up')")
		or die "Couldn't prepare statement: ". $dbh->errstr;

	$sth->execute($inMac)
		or die "Can't excecute statement";
		
	$sth->finish();		
}


# get rid of the mac dots in cisco CLI form
sub removeMacDots {
	my $inMac = shift;
	$_ = $inMac;
	
	#             $1             $2              $3
	if(m/([0-9a-z]{4})\.([0-9a-z]{4})\.([0-9a-z]{4})/){
		return "$1$2$3";
	}
	else {
		return $inMac;
	}
}
