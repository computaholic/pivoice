#!/usr/bin/perl

use warnings;
use strict;
use Config::IniFiles;


# ----------------------------------------------------------------------
# config variables
# 
# scenarios and dictionaries are organised in hashes
# ----------------------------------------------------------------------
my %scn_all;				# all available scenarios
my %scn_current;			# current scenario

my %scn_default;			# default scenario which provides parameter 
							# values, if not present in other scenario

my %scn_start;				# starting scenario, [*scenario] 

my %dct_all;				# all dictionaries

my %dct_current; 			# current dictionary;

# commands??




my %ini;
tie %ini, 'Config::IniFiles', ( -file => "./pivoice.conf", -default => $default_scenario );

my @secs=keys %ini;

print "I found the following scenarios:\n";
print "@secs\n";

my @par_keyowrd = (keys %{$ini{"*keyword"}});

print "Parameters for Keyword are:", "@par_keyowrd";

my $keyword_language = $ini{"*keyword"}{language};

print "\n\nBut keyword{language} gives: ", "$keyword_language\n";

# ----------------------------------------------------------------------
# find the starting scenario that starts with *
# ----------------------------------------------------------------------
for (keys %ini)
{
	if (/^\*/) # probing if first character is '*'
	{
		print "$tmp\n";
	}
	$start_scenario = $_;
}

# ----------------------------------------------------------------------
# Now, the following happens:
#   - loading current scenarion into a dedicated hash
#   - loading dictionary
#   - start recording
#   - evaluate command
# ----------------------------------------------------------------------

my 






