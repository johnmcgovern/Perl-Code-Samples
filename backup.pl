#!/usr/bin/perl

## MySQL Backup: nightly backup of specific databases.


my $prefix = '/opt/backups/'; # The folder you want to save your backup files to



# Create array from comma separated list below in __DATA__
my @dbs = split(",",<DATA>);
my $date = substr(getDate(),0,6);

# For each database in the list...
foreach (@dbs) {
	# If the string is not empty...
	if (/[\w]+/){
		# Prepare command line command
		#my $command = 'mysqldump --user=backupuser --password=fakePassword --databases '.$_.' > '.$prefix.$_.'-'.$date.'.bak';
		my $command = 'mysqldump --user=backupuser --password=fakePassword '.$_.' > '.$prefix.$_.'-'.$date.'.bak';
		# Execute command
		`$command`;
		print "Executed: created ".$_."-$date.bak\n";
	}
}

#remove old files
exec("find '/opt/backups' -name '*.bak' -mtime '+3' -exec " . 'rm -rf {} \;');


sub getDate() {
        return `date "+%m%d%y"`;
}

## Data declaration: Insert comma separated list of databases here.  
## There must be a comma after the last entry.
__DATA__
dbname1,dbname2,dbname3,
