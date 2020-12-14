#!/usr/bin/perl

BEGIN {
	# Add the script directory into Perl Include path.
	use Cwd qw(abs_path);
	use File::Basename;

	# Get the script directory
	our $dirname = dirname(abs_path(__FILE__));
	# Add directory into Perl Include Path
	push(@INC, $dirname);
}

use strict;
use Socket;

my $sock;

socket($sock, PF_UNIX, SOCK_DGRAM, 0) 
	or die "Can't create socket: $!\n";
bind($sock, sockaddr_un("\x00/org/kernel/udev/adata_hdd"))
	or die "Can't bind socket: $!\n";

my ($databuf, $addr);
while (1) {
	$databuf = 0;
	recv($sock, $databuf, 8192, 0);
	printf "recieve data, length = %d\n", length($databuf);
	my @datas = split(/\000/, $databuf);
	foreach my $data (@datas) {
		print $data, "\n";
	}
	print "================================\n\n";
}
