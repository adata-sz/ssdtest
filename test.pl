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

require SCSIDISK;
require DISKTest::Test;

print "Environments:\n";
foreach my $env (keys %ENV) {
    print "$env => '", $ENV{$env}, "'\n";
}
print "=========================\n\n";

sub disk_filter
{
	my $disk = $_[0];
	if (defined($ENV{'ACTION'})) {
		return 1;
	}
	if ($disk->{'scsi_type'} == 5) {
		# Skip CD-ROM
		return 0;
	}
	#Skip System Disks
	my $filesystems = $disk->{'filesystems'};
	foreach my $fs (@$filesystems) {
		if ($fs =~ /^\/(|boot|usr|home|var|opt)$/) {
			#print "$fs matches\n";
			return 0;
		}
	}
	return 1;
}

my @disks = SCSIDISK::scan_scsi_disks(\&disk_filter);

foreach my $disk (@disks) {
	foreach my $k (sort keys %$disk) {
		if ($k eq 'filesystems') {
			print "File Systems:\n";
			my $filesystems = $disk->{$k};
			foreach my $filesystem (@$filesystems) {
				print "\t$filesystem\n";
			}
		} else {
			print "$k => $disk->{$k}\n";
		}
	}
	print "Disk Size => ", $disk->{'sectors'}*512/(1024*1024), " MB\n";

	if (!defined($ENV{'ACTION'})) {
		my $rst1=DISKTest::Test::performance_test($disk);
		my $rst2=DISKTest::Test::read_performance_test($disk);
		my $rst3=DISKTest::Test::write_performance_test($disk);
		my $rst4=DISKTest::Test::burnin_test($disk);
		my $rst5=DISKTest::Test::check_gdn($disk);
		my $rst6=DISKTest::Test::secure_erase($disk);
		

		print 'Performance Test Result:'.+$rst1.+'\n';
		print 'Read Performance Test Result:'.+$rst2.+'\n';
		print 'Write Performance Test Result:'.+$rst3.+'\n';
		print 'Burnin Test Result:'.+$rst4.+'\n';
		print 'Check GDN Result:'.+$rst5.+'\n';
		print 'Secure Erase Result:'.+$rst6.+'\n';
	}
	print "=========================\n";
}
