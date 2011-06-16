#!/usr/bin/perl

require "./DEFINITY_ossi.pm";
import DEFINITY_ossi;
use Getopt::Long;


my $DEBUG =0;
my $ext = '';
my $elin= '';

GetOptions('debug' => \$DEBUG, 'extension=i'=>\$ext, 'elin=i'=>\$elin);

if ($ext eq '') {die;}
if ($elin eq '') {die;}

my $node = new DEFINITY_ossi('production', $DEBUG);
unless( $node && $node->status_connection() ) {
 	die("ERROR: Login failed for ". $node->get_node_name() );
}

if ($DEBUG)
{
	$node->pbx_command("display station $ext");
	if ( $node->last_command_succeeded() ) {
	 	my @ossi_output = $node->get_ossi_objects();
	 	my $i = 0;
	 	foreach my $hash_ref(@ossi_output) {
	 		$i++;
	 		print "output result $i\n";
	 		for my $field ( sort keys %$hash_ref ) {
	 			my $value = $hash_ref->{$field};
	 			print "\t$field => $value\n";
	 		}
	 	}
	}
}

my %fields = ('6e00ff00' => $elin);
$node->pbx_command("change station $ext", %fields );
$node->last_command_succeeded() or die "uh oh. setting elin failed on switch!";


my %fields = ('6e00ff00' => '');
$node->pbx_command("display station $ext", %fields );
if ( $node->last_command_succeeded() ) {
       my @ossi_output = $node->get_ossi_objects();
       my $hash_ref = $ossi_output[0];
       print "The PBX says the ELIN is now ". $hash_ref->{'6e00ff00'} ."\n";
}


$node->do_logoff();

