#!/usr/bin/perl -w
use strict;

require "/usr/local/bluesky/DEFINITY_ossi.pm";
import DEFINITY_ossi;

use Getopt::Long;
use Pod::Usage;
use DBI;
use Term::ReadKey;



my $Database_Name = 'dbname';
my $Database_User = 'dbuser';
my $Database_Pass = 'dbpass';
my $Database;

my %extensions;
my @pbxs = ('switcha','switchb');
my $pbx;
my $debug ='';


my $help =0;
my $node;
my $extension;

###########################################################
#
# PBX magic numbers
# (use test script and 'display station' to find these)
#
my $PBXgetExtension = '0001ff00' ;
#
###########################################################


sub getPhones
{
	# PBX : "You get to drink from the firehose!"

	my($node) = @_;

	my @exts;

	$node->pbx_command("list extension-type");

	if ( $node->last_command_succeeded() ) {
		@exts= $node->get_ossi_objects();
	}


	return @exts;
}


sub grabDirectoryNumbers
{
	my @tmsexts;
	my $SQL = "SELECT DISTINCT DirectoryNbr FROM tbl_DirectoryNumbers WHERE DeactivationDate IS NULL AND DirectoryNbr NOT LIKE '888%' AND DirectoryNbr NOT LIKE '800%' "
		  ."AND DirectoryNbr NOT LIKE '887%' ";
	my $db = $Database->prepare ($SQL) or die 'ERROR: Couldn\'t prepare statement: '.$Database->errstr;

	$db->execute() or die 'ERROR: Couldn\'t execute statement: '.$Database->errstr;

	do {
                while (my @newary =  $db->fetchrow_array())
		{
			@tmsexts = (@tmsexts,@newary);
		}
                
        } while ($db->{odbc_more_results});

	$db->finish;
	return @tmsexts;
}

sub initDB
{
        # Connect to the Database
        if(!$Database_Pass) {
                print STDERR 'TMS Database Password: ';
                ReadMode('noecho');
                chomp($Database_Pass = ReadLine(0));
                ReadMode('restore');
                print STDERR "\n";
        }
        $Database = DBI->connect('dbi:ODBC:'.$Database_Name, $Database_User, $Database_Pass) or die 'ERROR: Couldn\'t connect to TMS Database: '.DBI->errstr;
        undef $Database_Pass;
        $Database->{RaiseError} = 1;  # Abort on any database error
        $Database->{AutoCommit} = 1;
}

sub closeDB
{
	undef $Database;
}

sub findInArray
{
	my ($needle,@haystack) = @_;

	foreach my $hay (@haystack)
	{
		return 1 if $hay =~ m/$needle$/;
	}
	return 0;
}



initDB();

GetOptions('help|?'=>\$help, 'debug' => \$debug );
pod2usage(1) if $help;

my @tmsexts = grabDirectoryNumbers();

foreach $pbx (@pbxs)
{

	$node = new DEFINITY_ossi($pbx, $debug);
	unless( $node && $node->status_connection() ) {
   		die("ERROR: Login failed for ". $node->get_node_name() );
	}


	foreach $extension (getPhones($node))
	{
		my $ext = $extension->{$PBXgetExtension};

		next unless  (length($ext) >= 5);

		print "$ext: ";
		if ( exists($extensions{$ext}))
		{
			print "DUP in switches extension $ext    ";
		}

		if (findInArray($ext,@tmsexts))
		{
			print "extension in TMS $ext\n";
		}
		else
		{
			print "extension NOT in TMS $ext\n";
		}

		$extensions{$ext} = $ext;
	}
	
	$node->do_logoff();
}

closeDB();


__END__

=head1 NAME

audit extensions

