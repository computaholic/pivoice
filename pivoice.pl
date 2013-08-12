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

my $dict_current; 		# current dictionary;
my $dict_default="default"; # default command in dictionary

my $debug=1;				# debuglevel

# ----------------------------------------------------------------------
# Prototypes
# ----------------------------------------------------------------------
sub scenario_get_start(\%);
sub dict_get_all(\%);
sub gen_regex_from_simple($$);

########################################################################
########################################################################

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
#my $INPUT="would you play wow from bANg and so on\n";
print "Enter INPUT: ";
my $INPUT= <>;

# now removing blanks at the beginning and the end
chomp ($INPUT);
$INPUT =~ s/^(( )*)?//;
$INPUT =~ s/( )*?$//;


# set current scenario to start scenario
$scn_current=$scn_start;

# ~~~~~~~~~~~~~~~~~~~~~~~ TEST ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
my $say = $scn_all{$scn_default}{"say"};
print "pivoice.pl:\t\n\nSay Command is $say\n" if ($debug);

$say =~ s/\!(\w*)?/$scn_all{$scn_default}{$1}/g;
$say =~ s/\!(\w*)?/$scn_all{$scn_default}{$1}/g;

my $text = "Hallo, das ist mein erster Text";
$say =~ s/\$INPUT/\"$text\"/;

print "pivoice.pl:\t\n\nSay Command is $say\n" if ($debug);

system($say);

print "\n\n\n";
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# going over all commands that are in the dict of current scenario
for ( keys $dict_all{$scn_current} )
{
	# we do not care for the default command
	if ( $_ ne $dict_default )
	{
		my $command 		= $_;												# current command
		my $listen			= $dict_all{$scn_current}{$_}{"ListenFor"};		# matching string, what we listen for
		my $matchstyle 	= $dict_all{$scn_current}{$_}{"MatchStyle"}; 	# matching style (simple|regex)
		my $action 		= $dict_all{$scn_current}{$_}{"Action"};			# action to do
		
		print "pivoice.pl:\tChecking command <$command> with <$listen>\n" if ($debug);
		
		# lets check the MatchStyle (this is an ifthenelse-war, but perl
		# does not consistently support switch statements)
		
		print "pivoice.pl:\tMatch Type for command $command is $matchstyle\n" if ($debug);
		
		if ( $matchstyle eq "simple" )
		{
			# generate regex from simple string
			($listen, $action) = gen_regex_from_simple($listen, $action);
			
			# now put that regex back in and change MatchType, so we 
			# dont have to do that again
			$dict_all{$scn_current}{$command}{"ListenFor"} = $listen;
			$dict_all{$scn_current}{$command}{"Action"} = $action;
			$dict_all{$scn_current}{$command}{"MatchStyle"} = "regex";
			
			# updating help variables (not all needed, but lets keep that for now)
			$listen 		= $dict_all{$scn_current}{$command}{"ListenFor"};
			$matchstyle 	= $dict_all{$scn_current}{$command}{"MatchStyle"};
			$action 		= $dict_all{$scn_current}{$command}{"Action"};
		}
		
		# matching regex against $INPUT
		if ( $INPUT =~ /$listen/ )
		{
			my  @match_list = ( $INPUT =~ /$listen/ );
			print "pivoice.pl:\tVoice command |$INPUT| matches $listen\n" if ($debug);
			print "pivoice.pl:\tCommand has ", scalar @match_list, " parameters: " if ($debug);
			print "$_ " for @match_list;
			print "\n" if ($debug);
			
			# replacing $1, $2... in $action with actual values
			my $varcount=1;
			for ( @match_list)
			{
				$action =~ s/(\$$varcount)/$match_list[($varcount-1)]/;
				$varcount++;
			}
			
			print "pivoice.pl:\tAction>>>>>>\n\n" if ($debug);
			system($action);
			print "\npivoice.pl:\tAction<<<<<<\n\n\n" if ($debug);
		} 
		else
		{
			print "pivoice.pl:\tVoice command |$INPUT| does not match $listen\n\n" if ($debug);
		}
	}
}

########################################################################
########################################################################

# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# function definitions
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# generating regex from simple string
# ----------------------------------------------------------------------
sub gen_regex_from_simple($$)
{
	# simple means, absulute match.
	# we convert that into a regex and proceed
	# regex is /regex/, b/c we cant put '/' in a string
	# also: if $(...) is detected, it will be replaced by a group
	
	my $listen = shift;
	my $action = shift;
	
	
	# cleaning up the listen words
	chomp($listen);
	
	# replacing $(..) with $1, $2 ... in listen and action
	# first, save variable names
	my $counter=1;
	my $varname="";
	for ( $listen =~ /\$(\w*)?/g )
	{
		# thats the first match in $listen
		$varname = $_;
		
		print "pivoice.pl:\tReplacing \$ vars\n" if ($debug);
		print "pivoice.pl:\tFound varname \$$_\n" if ($debug);
		print "pivoice.pl:\tCurrent action is $action\n" if ($debug);
		
		# replace varnames in $action to $1, $2... 
		$action =~ s/(\$$varname)/\$$counter/g;
		
		print "pivoice.pl:\tNew action is $action\n" if ($debug);
		
		# counting one up, so we know what ${num} ($1, $2,...} is
		$counter++;
	}
	
	# after replacing varnames in $action we gen. regex in $listen
	$listen =~ s/\$(\w*)?/\(\\w\*\)\?/g;
	
	# checking for absolute or non absulte match
	if ( ($listen =~ /^~/) )
	{
		print "pivoice.pl:\tUsing NON absulute match\n" if ($debug);
		$listen =~ s/(^~( *))//;
	}
	else
	{
		print "pivoice.pl:\tUsing absulute match\n" if ($debug);
		$listen = "^$listen\$";
	}
	
	print "pivoice.pl:\tGenerated regex $listen\n" if ($debug);
	
	return ($listen, $action);
}

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
			print "pivoice.pl:\tTied ", \%tmp_dict, " to file $dict_files{$_}\n\n" if ($debug);
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
			print "pivoice.pl:\tStarting scenario is $_\n\n" if ($debug);
			return $_;
		}
	}
	
	# if this gets executed, then no starting scenario was found
	print "pivoice.pl:\tNo Starting scenario found\n\n" if ($debug);
	
	return 1; 
}


