package SCSIDISK;
use strict;
require 5.000;
require Exporter;

@SCSIDISK::ISA = qw(Exporter);
@SCSIDISK::EXPORT = qw(scan_scsi_hosts get_scsi_disks get_usb_info get_ata_info get_filesystem_info get_smart_info);
$SCSIDISK::VERSION = '1.00';

my $SCSI_HOST_DIR = "/sys/class/scsi_host";

=head1 NAME
	
SCSIDISK - Perl module to get SCSI disk information.

=head1 FUNCTIONS

=head2 read_sys_file

	read /sys file content

=head3 PARAMETERS

	$_[0]:	/sys file path

=head3 RETURN VALUE

	file content of $_[0]

=cut
sub read_sys_file
{
	my $fh;

	if (!open($fh, $_[0])) {
		#die "Cannot open file ", $_[0];
		return "";
	}

	my $ret = <$fh>;
	chomp($ret);
	close($fh);
	#chomp($ret);
	return $ret;
}

sub scan_scsi_hosts
{
	# SCSI Host Directory Handle
	my @scsi_hosts = ();
	my $scsi_host_dh;

	# Scan SCSI Host Controller
	opendir($scsi_host_dh, $SCSI_HOST_DIR) || die "cannot open $SCSI_HOST_DIR";
	while (readdir $scsi_host_dh) {
		if (!/^\./ && -d "$SCSI_HOST_DIR/$_") {
			push(@scsi_hosts, $_);
		}
	}
	closedir($scsi_host_dh);

	return @scsi_hosts;
}

=head2 get_usb_info

	get disk's USB information

=head3 PARAMETERS

	$_[0]:	disk structure

=head3 RETURN VALUE

	NONE

=cut
sub get_usb_info
{
	my $disk = $_[0];

	# Read USB Path
	my $usb_id = $disk->{'host_parent'};
	$usb_id =~ s#.*usb\d+/(.*)/(.*)#\1#;

	my $usb_sn = uc read_sys_file("/sys/bus/usb/devices/$usb_id/serial");
	my $usb_vid = uc read_sys_file("/sys/bus/usb/devices/$usb_id/idVendor");
	my $usb_pid = uc read_sys_file("/sys/bus/usb/devices/$usb_id/idProduct");
	my $usb_manufacturer = read_sys_file("/sys/bus/usb/devices/$usb_id/manufacturer");
	my $usb_product = read_sys_file("/sys/bus/usb/devices/$usb_id/product");
	my $usb_speed = read_sys_file("/sys/bus/usb/devices/$usb_id/speed");
						
	$disk->{'usb_path'} = $usb_id;
	$disk->{'usb_sn'} = $usb_sn;
	$disk->{'usb_vid'} = $usb_vid;
	$disk->{'usb_pid'} = $usb_pid;
	$disk->{'usb_manufacturer'} = $usb_manufacturer;
	$disk->{'usb_product'} = $usb_product;
	$disk->{'usb_speed'} = $usb_speed;
}

=head2 get_filesystem_info

	get filesystem list on disk

=head3 PARAMETERS

	$_[0]:	disk structure

=head3 RETURN VALUE

	NONE

=cut
sub get_filesystem_info
{
	my $disk = $_[0];
	$disk->{'filesystems'} = [];
	my $filesystems = $disk->{'filesystems'};

	my $df;
	open ($df, "df|") or die;
	while (my $df_line = <$df>) {
		if ($df_line =~ /^\/dev\//) {
			chomp($df_line);
			my @df_info = split(' ', $df_line);
			#print $df_info[5], " on ", $df_info[0], "\n";
			if ($df_info[0] =~ /^\/dev\/$disk->{'disk_dev'}\d*$/) {
				push(@$filesystems, $df_info[5]);
			}
		}
	}
	close($df);
}

=head2 get_ata_info

	get disk's ATA information

=head3 PARAMETERS

	$_[0]:	disk structure

=head3 RETURN VALUE

	NONE

=cut
sub get_ata_info
{
	my $disk = $_[0];
	my $linkname = $disk->{'ata_link'};
	$linkname =~ s/ata(\d+)/\1/;
	$linkname = "link" . $linkname;
	my $sata_speed = read_sys_file("/sys/class/ata_link/$linkname/sata_spd");
	if ($sata_speed ne "<unknown>") {
		$disk->{'sata_speed'} = $sata_speed;
	}
}

sub parse_line
{
	my $line = $_[0];
	my $fieldname = $_[1];
	$line =~ s/(.*)$fieldname(.*)/\2/;
	chomp($line);
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	return $line;
}

=head2 get_smart_info

	get disk's SMART information

=head3 PARAMETERS

	$_[0]:	disk structure

=head3 RETURN VALUE

	NONE

=cut
sub get_smart_info
{
	my $disk = $_[0];
	my $cmd;
	my $extra_parameter = "";

	if ($disk->{'driver_name'} eq "usb-storage") {
		return;
		$extra_parameter = "-d sat";
	}

	my $smart_info = `smartctl -x $extra_parameter /dev/$disk->{'disk_dev'}`;
	if ($smart_info !~ /Device does not support SMART|Permission denied/m) {
		my @lines = split(/\n/, $smart_info);

		foreach my $line (@lines) {	
			if ($line =~ /^Serial Number:/) {
				$disk->{'smart_sn'} = parse_line($line, 'Serial Number:');
			}
			if ($line =~ /^LU WWN Device Id:/) {
				$disk->{'smart_wwn'} = parse_line($line, 'LU WWN Device Id:');
			}
			if ($line =~ /^Firmware Version:/) {
				$disk->{'smart_fw'} = parse_line($line, 'Firmware Version:');
			}
			if ($line =~ /^Device Model:/) {
				$disk->{'smart_model'} = parse_line($line, 'Device Model:');
			}
			if ($line =~ /^User Capacity:/) {
				$disk->{'smart_capacity'} = parse_line($line, 'User Capacity:');
			}
			if ($line =~ /^Sector Size:/) {
				$disk->{'smart_sector_size'} = parse_line($line, 'Sector Size:');
			}
			if ($line =~ /^SMART overall-health self-assessment test result:/) {
				$disk->{'smart_health_self_assessment'} = parse_line($line, 'SMART overall-health self-assessment test result:');
			}
		}
		#$disk->{'smart_info'} = $smart_info;

		#my $smart_health = `smartctl -H $extra_parameter /dev/$disk->{'disk_dev'}`;
		#$disk->{'smart_health'} = $smart_health;
	}
}

=head2 scan_scsi_disks

	get SCSI disk list on system.

=head3 PARAMETERS

	$_[0]:	Disk filter. We will use this filter to get the disks we needed.

=head3 RETURN VALUE

	Array of disk structure

=cut
sub scan_scsi_disks
{
	my $disk_filter = $_[0];
	my @scsi_hosts = scan_scsi_hosts();
	my @disks = ();

	while (my $host = <@scsi_hosts>) {
		my ($dh, $driver_name);

		$driver_name = read_sys_file("$SCSI_HOST_DIR/$host/proc_name");

		my $host_parent = readlink("$SCSI_HOST_DIR/$host");	
		$host_parent =~ s#(.*)/.*/devices/(.*)/$host/.*#\2#;
		my $ata_link = "";

		#Scan for ATA Link
		my @ata_links = ();
		my @host_links = ();
		opendir($dh, "/sys/devices/$host_parent") or die "cannot open /sys/devices/$host_parent";
		while (my $dir = readdir $dh) {
			if ($dir =~ /^ata/) {
				push (@ata_links, $dir);
			}
			if ($dir =~ /^host/) {
				push (@host_links, $dir);
			}
		}
		closedir($dh);

		if ($#ata_links == $#host_links) {
			for (my $i = 0; $i <= $#host_links; ++$i) {
				if ($host_links[$i] eq $host) {
					$ata_link = $ata_links[$i];
					last;
				}
			}
		}

		my $device_dir = "$SCSI_HOST_DIR/$host/device";

		opendir($dh, $device_dir) || die "cannot open $device_dir";

		#Scan for SCSI Target
		while (my $target_f = readdir $dh) {
			if (($target_f =~ /^target/) && -d "$device_dir/$target_f") {
				my $dh2;
				opendir($dh2, "$device_dir/$target_f") or die "cannot open $device_dir/$target_f";
				#Scan SCSI Bus
				while (my $bus_id = readdir $dh2) {
					if ($bus_id =~ /^\d+\:\d+:\d+:\d+/) {
						my ($dh3, $disk_dev, $sg_dev);

						# Scan for SCSI Block Device
						opendir($dh3, "$device_dir/$target_f/$bus_id/block") or die "cannot open $device_dir/$target_f/$bus_id/block";
						while (my $tmp = readdir $dh3) {
							if ($tmp !~ /^\./) {
								$disk_dev = $tmp;
								last;
							}
						}
						closedir($dh3);

						# Scan for SCSI Generic Device
						opendir($dh3, "$device_dir/$target_f/$bus_id/scsi_generic") or die "cannot open $device_dir/$target_f/$bus_id/scsi_generic";
						while (my $tmp = readdir $dh3) {
							if ($tmp !~ /^\./) {
								$sg_dev = $tmp;
								last;
							}
						}
						closedir($dh3);

						my $scsi_vendor = read_sys_file("$device_dir/$target_f/$bus_id/vendor");
						my $scsi_model = read_sys_file("$device_dir/$target_f/$bus_id/model");
						my $scsi_type = read_sys_file("$device_dir/$target_f/$bus_id/type");

						my $disk_sector_size = read_sys_file("/sys/block/$disk_dev/queue/hw_sector_size");
						my $disk_sectors = read_sys_file("/sys/block/$disk_dev/size");

						my $disk = {
							'host' => $host,
							'host_parent' => $host_parent,
							'ata_link' => $ata_link,
							'driver_name' => $driver_name,
							'target' => $target_f,
							'scsi_id' => $bus_id,
							'disk_dev' => $disk_dev,
							'sg_dev' => $sg_dev,
							'scsi_type' => $scsi_type,
							'scsi_vendor' => $scsi_vendor,
							'scsi_model' => $scsi_model,
							'sector_size' => $disk_sector_size,
							'sectors' => $disk_sectors,
						};

						if ($driver_name eq "usb-storage") {
							# USB Storage
							get_usb_info($disk);
						}

						if ($ata_link ne "") {
							# ATA Disk
							get_ata_info($disk);
						}

						get_filesystem_info($disk);
						get_smart_info($disk);

						# Filter Disk
						if (!$disk_filter || &$disk_filter($disk)) {
							push(@disks, $disk);
						}
					}
				}
				closedir($dh2);
			}
		}
		closedir($dh);
	}

	return @disks;
}

=head1 HISTORY

Created by Chi-Chung-Lin E<lt>F<zc_lin@adata.com.tw>E<gt>.

=head1 COPYRIGHT

Copyright (c) 1998-2012 AData Technology Ltd.(http://www.adata.com.tw)
All rights reserved.

=cut

1;
