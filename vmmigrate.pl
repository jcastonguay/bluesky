#!/usr/bin/perl

require "./DEFINITY_ossi.pm";
import DEFINITY_ossi;
use Getopt::Long;


my $DEBUG =0;
my $SET = 0;
my $ext = '';
my $elin= '';
my $lwc = 'spe';
my $mwi = 'sip-adjunct';
my $cpn = 'y';
my $switch= 'production';

GetOptions('debug' => \$DEBUG, 'coveragelist=s'=>\$cpfile, 'extensionlist=s'=>\$extfile, 'switchconf=s'=>\$switch, 'set' => \$SET);

my @paths;

open(CP, "< $cpfile");
open(EXT,  "< $extfile");

my $line;
while (defined ($line = <CP>))
{
    chomp $line;
    ($path, $point, $rest) = split(/,/, $line);
    $paths[$path] = $path if $path ne 'Coverage Path Number';
    print "XXX path $path is $paths[$path] 	\n" if $DEBUG;
}
close(CP);

print "Logging into $switch \n";
my $node = new DEFINITY_ossi($switch, $DEBUG);
unless( $node && $node->status_connection() ) {
        die("ERROR: Login failed for ". $node->get_node_name() );
}

my $st;
my $junk;
my $cp;

while (defined ($line = <EXT>))
{
   chomp $line;
   ($ext,$st,$rest) = split(/,/,$line);

   if ($ext eq '') {die;}
   next if $ext eq 'extension';
   next if $st ne 'station-user';
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


   my %fields = ('8007ff00'=>'');
   $node->pbx_command("display station $ext", %fields );
     if ( $node->last_command_succeeded() ) {
       my @ossi_output = $node->get_ossi_objects();
       my $hash_ref = $ossi_output[0];
       $cp = $hash_ref->{'8007ff00'};
     }

   next if $cp eq '';
   if ($paths[$cp])
   {
     print "MATCH for ext:$ext coverage_path:$cp\n";
     if ($SET)
     {
 	my %fields = ('0013ff00'=>$lwc, '6200ff00'=>$mwi, '5800ff00'=>$cpn);

	$node->pbx_command("change station $ext", %fields );
	$node->last_command_succeeded() or die "uh oh. setting fields failed on switch!";
     }

     my %fields = ('0013ff00'=>'', '6200ff00'=>'', '8007ff00'=>'', '5800ff00'=>'');

     $node->pbx_command("display station $ext", %fields );
     if ( $node->last_command_succeeded() ) {
       my @ossi_output = $node->get_ossi_objects();
       my $hash_ref = $ossi_output[0];
       print "The PBX says the Coverage Path 1 is ". $hash_ref->{'8007ff00'} . "\n";
       print "The PBX says the LWC Reception is ". $hash_ref->{'0013ff00'} . "\n";
       print "The PBX says the MWI Served User Type is ". $hash_ref->{'6200ff00'} . "\n";
       print "The PBX says the Per Station CPN is ". $hash_ref->{'5800ff00'}."\n";

     }
  }
}

close(EXT);
$node->do_logoff();

