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

my $voipdirectory = "./VOIP_Port_Locations.csv";
my $buildingdata = "./voip-snapshot"; 

my $switchdomain = ".net.umd.edu";

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

sub matchMACToELIN
{

	#The brains of this outfit.

	#This takes the Mac address we find from the PBX and queries the latest dumps we have from all of our switches
	#we then can find the port its on.

	#from there we query dumps from TMS to get what switch port is assigned what ELIN
	
	#TODO handle case where we don't find an assigned ELIN

        my($mac,$ext) = @_;
	my $switch; my $junk; my $switchport; 
	my $portmac;
	my $ip;
	my $dirswitch; my $dircard; my $dirport; my $pbx; my $direlin; my $dirbuilding; my $room;
	my $card; my $port;
        open(BLDG, "< $buildingdata");
        open(DIR,  "< $voipdirectory");

	my $line;
        while (defined ($line = <BLDG>))
        {
                chomp $line;
                ($switch, $junk, $switchport, $portmac) = split(/\s+/, $line);
		($card, $port) = split(/\//,$switchport);
                last if ((defined($portmac)) && (defined($card)) &&(defined($port))&& ($portmac eq $mac));
        }

        if ($portmac ne $mac) 
	{
		# We bail here because we can't locate the phone on our network
		#XXX Do we set an ELIN? Campus default or extension?
		warn "no match for ".$mac." in $buildingdata looking at ext: $ext mac: $mac";
		$direlin = '';
	}
        else
	{
	        print "DEBUG card=".$card." port=".$port."\n" if $debug;
		no warnings;
	        $card =~ s/Gi|Fa(\d{1,})/$1/;
		use warnings;
	        $ip = nslookup(domain => $switch.$switchdomain);
	        print "DEBUG cardnumber=".$card." switch: ".$switch." ip:".$ip."\n" if $debug;
		
	        while (defined ($line = <DIR>))
	        {
	                chomp $line;
	                ($dirswitch,$dircard,$dirport,$pbx,$direlin,$dirbuilding,$room) = split(/,/,$line);
	                last if ($ip eq $dirswitch) && (int($dircard) == int($card)) && (int($dirport) == int($port)) ;
	        }
		if (!(($ip eq $dirswitch) && (int($dircard) == int($card)) && (int($dirport) == int($port)))) 
		{
			warn "no match for switch: ".$ip." (".$switch.") card: $card port: $port  in $voipdirectory looking at ext: $ext mac: $mac";
			# XXX Set to default ELIN
			$direlin = '';
		}
	}
	close(BLDG);
	close(DIR);
        return ($direlin,$dirswitch,$dircard,$dirport);
}

sub setELIN
{
	# PBX   : Hi $ext, when you see the cops tell them you're $elin
        # Phone : Teehee, okay!

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

        my %fields = ($PBXgetELIN => ''); #, $PBXgetName = '');

        $node->pbx_command("display station $ext", %fields );
     	if ($node->last_command_succeeded())
        {
                my @ossi_output = $node->get_ossi_objects();
                my $hash_ref = $ossi_output[0];
		if ($elin eq '')
		{
			print ("ext: $ext  current_elin: ".$hash_ref->{$PBXgetELIN}." tms_elin: MISSING");
		}
		elsif ($hash_ref->{$PBXgetELIN} eq $elin)
		{
			print ($hash_ref->{$PBXgetELIN}.",");
		}
		else
		{
			print ("ext: $ext  current_elin: ".$hash_ref->{$PBXgetELIN}." tms_elin: $elin MISMATCH");
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

print "extension,name,ipaddress,macaddress,ele,networkSwitch,port,switch\n";

GetOptions('help|?'=>\$help, 'debug' => \$debug,'pbx=s' =>\$pbx,'set'=>\$setter );
pod2usage(1) if $help;


$node = new DEFINITY_ossi($pbx, $debug);
unless( $node && $node->status_connection() ) {
   die("ERROR: Login failed for ". $node->get_node_name() );
}

foreach $voipphone (getRegisteredPhones($node))
{
	print $voipphone->{$PBXgetExtension}.",";

	$mac = Net::MAC->new('mac' => getPhoneMAC($node,$voipphone->{$PBXgetExtension}), 'die' => 0);
#	if (!$mac) 
#	{
#		warn "uh what. That wasn't a mac. $voipphone";
#		next;
#	}
	$mac = $mac->convert('base' => 16, 'bit_group'=>16,'delimiter'=>'.');
	my ($direlin, $dirip, $dircard, $dirport) = matchMACToELIN($mac->get_mac(),$voipphone->{$PBXgetExtension});	
	my $match = substr($direlin, -5, 5);
	getELIN($node, $voipphone->{$PBXgetExtension}, $match); #only 5 digit elins here


	print "$dirip-$dircard,$dirport,switchA\n";

}

$node->do_logoff();





__END__

=head1 NAME

phonewalk - Set the ELINs for all registered phones

=head1 SYNOPSIS

phonewalk [options] 

=head1 OPTIONS

=item B<--pbx>

	Sets the pbx used to production or lab

=item B<--help | -?>

         prints this helpful message

=item B<--debug>

             helps with debugging

=cut
