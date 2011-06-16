#!/usr/bin/perl

require "./DEFINITY_ossi.pm";
import DEFINITY_ossi;
use Getopt::Long;


my $DEBUG =0;
my $ext = '';

GetOptions('debug' => \$DEBUG, 'extension=i'=>\$ext, );

if ($ext eq '') {die;}

my $node = new DEFINITY_ossi('production', $DEBUG);
unless( $node && $node->status_connection() ) {
 	die("ERROR: Login failed for ". $node->get_node_name() );
}

if ($DEBUG)
{

   $node->pbx_command("status station $ext");
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

my %fields = ('6e00ff00' => '', '0013ff00'=>'', '6200ff00'=>'');
$node->pbx_command("display station $ext", %fields );
if ( $node->last_command_succeeded() ) {
       my @ossi_output = $node->get_ossi_objects();
       my $hash_ref = $ossi_output[0];
       print "The PBX says the ELIN is ". $hash_ref->{'6e00ff00'} ."\n";
#       print "The PBX says the LWC Reception is ". $hash_ref->{'0013ff00'} . "\n";
 #      print "The PBX says the MWI Served User Type is ". $hash_ref->{'6200ff00'} . "\n";
#       print "WARNING Can't find the Per Station CPN right now "."\n";
}



$node->do_logoff();

