package Agent;
use strict;
require 5.000;
require Exporter;

@Agent::ISA = qw(Exporter);
@Agent::EXPORT = qw(find_agent get_test_config);
$Agent::VERSION = '1.00';

=head1 NAME
	
Agent - Perl module to communication with ADATA Agent.

=head1 FUNCTIONS

=cut

use strict;
use Socket;

sub cacl_check_sum
{
	my $data = $_[0];
	my $checksum = 0;
	
	for (my $i = 0; $i <= $#$data; ++$i) {
		$checksum += $data->[$i];
	}
	#print "checksum = $checksum\n";
	$data->[6] = $checksum & 0xFF;
	$data->[7] = ($checksum >> 8) & 0xFF;
}

=head2 find_agent

	find ADATA agent IP and port.

=head3 PARAMETERS

	NONE

=head3 RETURN VALUE

	0: Not Found

	others: Hash reference of Agent IP and port.
		Usage:
			$agent->{'ip'}
			$agent->{'port'}
=cut
sub find_agent
{
	my $agent_port = 9050;
	my $agent_proto = getprotobyname('udp');
	my $broadcastAddr = sockaddr_in($agent_port, INADDR_BROADCAST);

	my $sock;

	socket($sock, PF_INET, SOCK_DGRAM, $agent_proto)
		or return 0;

	if (!setsockopt($sock, SOL_SOCKET, SO_BROADCAST, 1)) {
		close($sock);
		return 0;
	}

	if (!setsockopt($sock, SOL_SOCKET, SO_SNDTIMEO, pack('L!L!', 15, 0))) {
		close($sock);
		return 0;
	}
	
	if (!setsockopt($sock, SOL_SOCKET, SO_RCVTIMEO, pack('L!L!', 15, 0))) {
		close($sock);
		return 0;
	}

	my $data = pack(
		"S L S Z64 Z32 Z32 l",
		0x82, # client type, DOS
		0, #op code, BROADCAST
		0, #checksum
		"Perl Loader", #Computer Name
		"Linux", #MB ID
		"SSD/UFD Tester", #MB SN
		0, #Server TCP Port
	);

	my @raw_data = unpack("C140", $data);

	cacl_check_sum(\@raw_data);

	if (!send($sock, pack("C140", @raw_data), 0, $broadcastAddr)) {
		close ($sock);
		return 0;
	}

	my $input;
	my $addr = recv($sock, $input, 4096, 0); 

	if (!$addr) {
		close ($sock);
		return 0;
	}

	my $agent_ip = 0;

	my ($client_type, $opcode, $checksum, 
		$computer_name, $mbid, $mbsn, $server_port) =
		unpack("S L S Z64 Z32 Z32 l", $input);

	if ($opcode == 0x1) {
		my $port;
		($port, $agent_ip) = sockaddr_in($addr);
		my @ip_segment = unpack("C4", $agent_ip);
		$agent_ip = sprintf "%d.%d.%d.%d",
			$ip_segment[0], $ip_segment[1], $ip_segment[2], $ip_segment[3];
	} else {
		close ($sock);
		return 0;
	}

	close($sock);

	return { 
		'ip' => $agent_ip, 
		'port' => $server_port };
}

=head2 get_test_config

	get test configuration from ADATA Agent.

=head3 PARAMETERS

	$_[0]: agent structure. The result from find_agent.

=head3 RETURN VALUE

	Test Configuration. Type: String.

=cut
sub get_test_config
{
	my $agent = $_[0];

	my $proto = getprotobyname('tcp');
	my $serverAddr = sockaddr_in($agent->{'port'}, inet_aton($agent->{'ip'}));

	my $sock;

	socket($sock, PF_INET, SOCK_STREAM, $proto)
		or return 0;

	if (!setsockopt($sock, SOL_SOCKET, SO_SNDTIMEO, pack('L!L!', 15, 0))) {
		close($sock);
		return 0;
	}
	
	if (!setsockopt($sock, SOL_SOCKET, SO_RCVTIMEO, pack('L!L!', 15, 0))) {
		close($sock);
		return 0;
	}

	if (!connect($sock, $serverAddr)) {
		close($sock);
		return 0;
	}

	if (!send($sock, "GET_TEST_CONFIG", 0)) {
		close ($sock);
		return 0;
	}

	my $result = "";
	recv($sock, $result, 4096, 0); 

	if (length($result) <= 0) {
		close ($sock);
		return 0;
	}

	close($sock);
	return $result;
}

=head1 HISTORY

Created by Chi-Chung-Lin E<lt>F<zc_lin@adata.com.tw>E<gt>.

=head1 COPYRIGHT

Copyright (c) 1998-2012 AData Technology Ltd.(http://www.adata.com.tw)
All rights reserved.

=cut

1;
