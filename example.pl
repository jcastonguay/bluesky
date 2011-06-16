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

#To simplify this example code, I took out where this is dynamically generated.
my $elinnum = '55555';

my $help =0;
my $setter=0;
my $mac;
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


# We ask the PBX for all of the active voip phone extensions
# Then for each of their MAC addresses
# We match the MAC with what we have in our MAC tables
# and then that switch port info with what TMS has for ELINs
# Finally we set that extension the ELIN we have for it
# Repeat for all of the active phones



sub getPhoneMAC
{
	#  PHONE : Hi PBX, I'm $ext, what is my address?
	#  PBX   : What, you don't know? Its $mac

	my ($node, $ext) = @_;
#	my $PBXgetName = '8003ff00';

	my %fields = ($PBXgetPhoneMAC => '','6603ff00'=>'');#,$PBXgetName => ''); #thats weird, depending on the command its the same entry for elin as it is for mac

        $node->pbx_command("status station $ext", %fields );
        if ($node->last_command_succeeded())
	{
		my @ossi_output = $node->get_ossi_objects();
		my $hash_ref = $ossi_output[0];

		my $mymac = Net::MAC->new('mac' => $hash_ref->{$PBXgetPhoneMAC}, 'die' => 0);
		$mymac = $mymac->convert('base' => 16, 'bit_group'=>8,'delimiter'=>'-');
		print '"'."NAME".'",'.$hash_ref->{'6603ff00'}.",".uc($mymac->get_mac()).",";
		return $hash_ref->{$PBXgetPhoneMAC};
	}
}


sub setELIN
{
	# PBX   : Hi $ext, when you see the cops tell them you're $elin
        # Phone : Okay!


        my ($node,$ext, $elin) = @_;

	return if $ext eq '';
	return if $elin eq '';
        #change station to set extension to that elin

        my %fields = ($PBXsetELIN => $elin);

        print ("SET  station $ext to $elin\n");
        $node->pbx_command("change station $ext", %fields );
        $node->last_command_succeeded() or die "uh oh. setting elin failed on PBX!";

}



sub getELIN
{

        my ($node,$ext, $elin) = @_;

        return if $ext eq '';
        #change station to set extension to that elin

        my %fields = ($PBXgetELIN => ''); 

        $node->pbx_command("display station $ext", %fields );
     	if ($node->last_command_succeeded())
        {
                my @ossi_output = $node->get_ossi_objects();
                my $hash_ref = $ossi_output[0];
		if ($hash_ref->{$PBXgetELIN} eq $elin)
		{
			print ($hash_ref->{$PBXgetELIN}.",");
		}
		else
		{
			print ("ext: $ext  current_elin: ".$hash_ref->{$PBXgetELIN}." our elin: $elin MISMATCH");
			if ($setter)
		        {
                	       setELIN($node, $ext, $elin);
		        }
		}
                return $hash_ref->{$PBXgetELIN};
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

	getELIN($node, $voipphone->{$PBXgetExtension}, $elinnum); #only 5 digit elins here
	#also sets elin given the set flag
	
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
