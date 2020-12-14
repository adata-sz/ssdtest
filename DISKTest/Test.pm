package DISKTest::Test;
use strict;
require 5.000;
require Exporter;

@DISKTest::Test::ISA = qw(Exporter);
@DISKTest::Test::EXPORT = qw(performance_test read_performance_test write_performance_test burnin_test secure_erase);
$DISKTest::Test::VERSION = '1.00';

sub Write_log
{
	my $dh;
	open($dh,('>>home/stress/log/'.+$disk->{'disk_dev'}));
	print $dh($_[0]);
	close($dh);
	
}

# 4K performance
sub performance_test
{
	my $disk = $_[0];
	my $cmd;
	my $dh;
	my $performance_test_info;
	my $passCount=0;
	$cmd = "stressapptest -d /dev/$disk->{'disk_dev'} --read-block-size 4096 --cache-size 0 --random-threads 0 --destructive -s 10";
	print "$cmd\n";
	open($dh, "$cmd|") or die;
	while (<$dh>) {
#		print;
		$performance_test_info.=$_;
	}
	close($dh);

	$cmd = "stressapptest -d /dev/$disk->{'disk_dev'} --read-block-size 4096 --cache-size 0 --random-threads 63 --destructive -s 10";
	print "$cmd\n";
	open($dh, "$cmd|") or die;
	while (<$dh>) {
#		print;
		$performance_test_log.=$_;
	}
	close($dh);
	Write_log($performance_test_log);
	my @lines = split(/\n/, $performance_test_log);
	foreach my $line (@lines) 
	{
		if ($line =~ /Status: PASS/) 
		{
			$passCount+=1;
		}
	
	}
	if ($passCount==2)
	{
		return 'PASS';
	}
	else
	{
		return 'FAIL';
	}
}

# read performance
sub read_performance_test
{
	my $disk = $_[0];
	my $cmd = "hdparm -t /dev/$disk->{'disk_dev'}";
	print "$cmd\n";
	my $dh;
	my $read_performance_test_info;
	open($dh, "$cmd|") or die;
	while (<$dh>) {
#		print;
		$read_performance_test_info.=$_;
	}
	close($dh);
	Write_log($read_performance_test_info);
}

# write performance
sub write_performance_test
{
	my $disk = $_[0];
	my $cmd;
	my $dh;
	my $write_performance_test_info;

	$cmd = "time dd if=/dev/mem of=/dev/$disk->{'disk_dev'} bs=4096 count=65536 conv=fdatasync,notrunc";
	print "$cmd\n";
	open($dh, "$cmd|") or die;
	while (<$dh>) {
		$write_performance_test_info.=$_;
#		print;
	}
	close($dh);
	$cmd = "time dd if=/dev/mem of=/dev/$disk->{'disk_dev'} bs=1M count=256 conv=fdatasync,notrunc\n";
	print "$cmd\n";
	open($dh, "$cmd|") or die;
	while (<$dh>) {
#		print;
		$write_performance_test_info.=$_;
	}
	close($dh);
	Write_log($write_performance_test_info);
}

# burn-In + scan ECC
sub burnin_test {
	my $disk = $_[0];
	my $cmd;
	my $burnin_test_info;
	$cmd = "badblocks -svw -b 65536 -t random -c 1 -p 1 /dev/$disk->{'disk_dev'}";
	print "$cmd\n";
	
	my $dh;
	open($dh, "$cmd|") or die;
	while (<$dh>) {
#		print;
		$burnin_test_info.=$_;
	}
	close($dh);
	Write_log($burnin_test_info);
}

# security erase
sub secure_erase {
	my $disk = $_[0];
	my $cmd;
	my $secure_erase_info;
	$cmd = "hdparm --security-set-pass â€˜NULLâ€™ /dev/$disk->{'disk_dev'}";
	print "$cmd\n";

	my $dh;
	open($dh, "$cmd|") or die;
	while (<$dh>) {
#		print;
		$secure_erase_info.=$_;
	}
	close($dh);

	sleep 2;
	
	$cmd = "hdparm --security-erase â€˜NULLâ€™ /dev/$disk->{'disk_dev'}";
	print "$cmd\n";
	open($dh, "$cmd|") or die;
	while (<$dh>) {
#		print;
		$secure_erase_info.=$_;
	}
	close($dh);
	Write_log($secure_erase_info);
}

# GDN check
sub check_gdn {
        my $disk = $_[0];
        my $cmd;
        my $check_gdn_info;
#  SF_Genesis -LOGS [DEVICE] [DESTINATION_FILENAME] [-TYPE] [LOG=FILENAME]
#                DEVICE - Disk label to access (i.e. /dev/sg2).
#  DESTINATION_FILENAME - Destination file to save the output to.
#                  TYPE - Text only, Text+Binary or Erase Panic Dumps. Possible values are: -SAVE_TEXT, -SAVE_ALL or -ERASE_PANIC_DUMPS.
#                  LOG= - Log filename to capture the activity. (i.e. LOG=SomeDirectory/SomeFilename)       
        $cmd = "./SFG/SF_Genesis -LOGS /dev/$disk->{'sg_dev'} SSD.log -SAVE_TEXT LOG=SFG/test.log";

        print "$cmd\n";
        my $dh;
        open($dh, "$cmd|") or die;
        #while (<$dh>) {
        #      print;
        #}
        close($dh);

        my $gdn = 0;

        open(SSDLOG, "SSD.log") or die;
        while (<SSDLOG>) {

        # get string ¡°Total Number of Grown Defects¡±             
            if( $_ =~ / Total Number of Grown Defects/i ) {
                        #print ¡°$_\n¡±;
                        $check_gdn_info.=$_;
                        # get GDN
                        /^Total Number of Grown Defects: (.+)\s*/i;
                        $gdn = $1;
                        Print ¡°$gdn\n¡±;
                }
        }
        close(SSDLOG);
        Write_log($check_gdn_info);
        if ($gdn > 20){
			return 'FAIL';
        }
        else {
			return 'PASS';
        }
}


1;
