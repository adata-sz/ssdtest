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
require Agent;

my $agent = Agent::find_agent();

if ($agent) {
	print "Agent IP: ", $agent->{'ip'}, "\n";
	print "Agent Port: ", $agent->{'port'}, "\n";

	print "Test Config: ", Agent::get_test_config($agent), "\n";
}
