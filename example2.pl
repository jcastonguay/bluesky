#!/usr/bin/perl -w
use strict;

require "./DEFINITY_ossi.pm";
import DEFINITY_ossi;

use Getopt::Long;
use Pod::Usage;
use Net::Nslookup;
use Net::MAC;

my $pbx = 'switcha'; #'production'; #'lab';

my $debug ='';


my $help =0;
my $node;
my $voipphone;

###########################################################
#
# PBX magic numbers
# (use test script and 'display station' to find these)
#
my $PBXgetPhoneMAC  = '6e00ff00';
my $PBXsetELIN      = '6e00ff00';
my $PBXgetELIN      = '6e00ff00';
my $PBXgetExtension = '6800ff00';
#
###########################################################


sub getPhoneFields
{

	my ($node, $ext) = @_;

	my %fields = ('0001ff00' => '','0002ff00'=>'', '7003ff00' => '', '6d00ff00' => '', '6e00ff00' => '');

        $node->pbx_command("status station $ext", %fields );
        if ($node->last_command_succeeded())
	{
		my @ossi_output = $node->get_ossi_objects();
		my $hash_ref = $ossi_output[0];

		print '"'.$hash_ref->{'0001ff00'}.",".$hash_ref->{'0002ff00'}.",".$hash_ref->{'7003ff00'}.","$hash_ref->{'6d00ff00'}.",".$hash_ref->{'6e00ff00'}."\n";

		return;
	}
}




sub getRegisteredPhones
{

	# PBX : "You get to drink from the firehose!"

	my($node) = @_;

	my @registered;

	$node->pbx_command("list registered");

	if ( $node->last_command_succeeded() ) {
		@registered= $node->get_ossi_objects();
	}

	return @registered;
}


GetOptions('help|?'=>\$help, 'debug' => \$debug,'pbx=s' =>\$pbx,'set'=>\$setter );
pod2usage(1) if $help;


$node = new DEFINITY_ossi($pbx, $debug);
unless( $node && $node->status_connection() ) {
   die("ERROR: Login failed for ". $node->get_node_name() );
}

foreach $voipphone (getRegisteredPhones($node))
{
	print $voipphone->{$PBXgetExtension}.",";

	getPhoneFields($node,$voip->{$PBXgetExtension});	
}

$node->do_logoff();





__END__

=head1 NAME

testscript -- test script to show functionality

=head1 SYNOPSIS

testscript [options] 

=head1 OPTIONS

=item B<--pbx>

	Sets the pbx used to production or lab

=item B<--help | -?>

         prints this helpful message

=item B<--debug>

             helps with debugging

=cut
