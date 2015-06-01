#!/usr/bin/perl -w
use strict; 
use Net::SNMP;

# Variable List #
my $read_community	= 'fakeRead';
my $hostname_mib 	= '1.3.6.1.4.1.9.2.1.3.0';
my $firmware_mib 	= '1.3.6.1.2.1.47.1.1.1.1.9.1001';

while(<DATA>){

	chomp($_);
	
	my $firmware = get_SNMP($_,$firmware_mib);
	my $hostname = get_SNMP($_,$hostname_mib);
	 
	print "$_   $hostname   $firmware\n";  
}

sub get_resp {
	my $hostname = shift;
	my $oid = shift;
	my $session;
	my $error;
	my $response;
	
	($session, $error) = Net::SNMP->session(
		 -hostname  => $hostname,
   	 	 -community => "$read_community",
		 -port      => 161,	
		 -timeout   => 1,
		 -retries   => 0
	);
												
  	if (!defined($session)) { 
		 return "Not Available"; 
  	}

	if (!defined($response = $session->get_request($oid))) { 
			  $session->close(); 
			  return "No Response"; 
	}
	else { 
			  $session->close();
			  return $response->{$oid}; 
	}
}


sub get_SNMP {
		  my $hostname = shift;
		  my $oid = shift;
		  return get_resp($hostname, $oid);
}



__DATA__
10.1.1.1
10.1.1.2
10.1.1.3
10.1.1.4