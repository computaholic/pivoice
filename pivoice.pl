#!/usr/bin/perl

use warnings;
use strict;
use Config::IniFiles;


# ----------------------------------------------------------------------
# config variables
# 
# scenarios and dictionaries are organised in hashes
# these are tied hashes, so referencing will not work...I tried.
# ----------------------------------------------------------------------
my %scn_all;				# all available scenarios

my $scn_default="default";# default scenario which provides parameter 
							# values, if not present in other scenario

my $scn_start;				# starting scenario, [*scenario] 
my $scn_current;			# current scenario

my %dict_all;				# all dictionaries

my %dict_current; 			# current dictionary;
my $dict_default="default"; # default command in dictionary

my $debug=1;				# debuglevel

# ----------------------------------------------------------------------
# Prototypes
# ----------------------------------------------------------------------
sub scenario_get_start(\%);
sub dict_get_all(\%);

# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# main program
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------

# loading config into tied hash scn_all
tie %scn_all, 'Config::IniFiles', ( -file => "./pivoice.conf", -default => $scn_default );

# find the starting scenario that starts with *
$scn_start = scenario_get_start(%scn_all);

# loading all dictionaries into one hash
%dict_all = dict_get_all(%scn_all);

# For now we will fake an input string
my $input="Pi";

# now lets see if we can find the string
$scn_current=$scn_start;

for ( keys $dict_all{$scn_current} )
{
	# we do not care for the default command
	if ( $_ ne $dict_default )
	{
		my $command 	= $_;
		my $match 		= $dict_all{$scn_current}{$_}{"ListenFor"};
		my $matchstyle = $dict_all{$scn_current}{$_}{"MatchStyle"};
		
		print "pivoice.pl:\tChecking command <$command> with <$match>\n" if ($debug);
		
		# lets check the MatchStyle (this is an ifthenelse-war, but perl
		# does not consistently support switch statements
		if ( $matchstyle eq "simple" )
		{
			print "pivoice.pl:\tMatch Type for command $command is $matchstyle\n" if ($debug);
		}elsif ( $matchstyle eq "regex" )
		{
			print "pivoice.pl:\tMatch Type for command $command is $matchstyle\n" if ($debug);
		} 
	}
}



# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# function definitions
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# loading all dictionaries into one hash
# ----------------------------------------------------------------------
sub dict_get_all(\%)
{
	my $scenarios = shift;
	
	my %dict_files;		# hash of all detected files
	my %dict_all; 		# hash will all dicts
	
	for (keys %$scenarios)
	{
		if ( $$scenarios{$_}{"Dict"} ne "NONE" )
		{
			# getting dict files from all scenarios
			$dict_files{$_} 	= $$scenarios{$_}{"Dict"};
			
			# tie each file to a temporary hash and save the reference
			# to that hash in a different hash
			tie my %tmp_dict, 'Config::IniFiles', ( -file => "$dict_files{$_}", -default => $dict_default );
			$dict_all{$_} = \%tmp_dict;
			
			# debug information
			print "pivoice.pl:\tTied ", \%tmp_dict, " to file $dict_files{$_}\n" if ($debug);
		}
	}
	
	# return hash with all dictionaries
	return %dict_all;
}

# this will return the starting scenario
sub scenario_get_start(\%)
{
	my $scenarios = shift;
	for (keys %$scenarios)
	{
		if (/^\*/) # probing if first character is '*'
		{
			print "pivoice.pl:\tStarting scenario is $_\n" if ($debug);
			return $_;
		}
	}
	
	# if this gets executed, then no starting scenario was found
	print "pivoice.pl:\tNo Starting scenario found\n" if ($debug);
	return 1; 
}


