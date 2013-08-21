#!/usr/bin/perl


########################################################################
###     STANDARD MODULES                                             
########################################################################

use warnings;
use strict;
use Config::IniFiles;


########################################################################
###     CONFIG VARIABLES                                             
# 
# scenarios and dictionaries are organised in hashes
# these are tied hashes, so referencing will not work...I tried.
#
########################################################################

my %scn_all;						# all available scenarios

my $scn_default="default";		# default scenario which provides parameter 
									# values, if not present in other scenario

my $command_default="default"; 	# default command in dictionary

my $scn_start;						# starting scenario, [*scenario] 
my $scn_current;					# current scenario
my $scn_next;						# Next Scenario

my %dict_all;						# hash of all dicts, sorted by scenario

my $INPUT="";						# Input from Speech to Text
my $ismatch = 0;					# set if match was found
my $nomatchmode="";				# what to do if no match was found
my $nextscenariomode="";			# what to do if no NextScenario is defined

#my $command_current; 				# current command of current dictionary;
									# current dict is a hash:
									# $dict_all{$scn_current}

########################################################################
###     DEBUG CONFIG                                              
# 
# some variables that help to display debug msg (which is almost most
# of the code)
#
########################################################################

my $debug		= 1;				# debuglevel
my $deb_th 	= 1;				# debug threshold for main
my $prog_name 	= "pivoice.pl";		#
my $func_name 	= "main";

########################################################################
###     Prototypes
########################################################################

sub get_next_scenario($$$$$$\%\%);
sub expand_special_expression($$$\%\%);
sub scenario_get_start(\%);
sub dict_get_all(\%);
sub gen_regex_from_simple($$);
sub get_voice();
sub split_action($);
sub print_debug($$$$$);


########################################################################
##
###     main program
##
########################################################################

print_debug("ENTERING $func_name", $prog_name, $func_name, 1, 1);

########################################################################
###     Loading config file and dictionaries
########################################################################

# loading config into tied hash scn_all
tie %scn_all, 'Config::IniFiles', ( -file => "./pivoice.conf", -default => $scn_default );
print_debug("Loading config file successfull", $prog_name, $func_name, $deb_th, 0);

# %dict_all is a hash of hashes (one for each scenario)
# these are also hashes of hashes (one for each command)
%dict_all = dict_get_all(%scn_all);
print_debug("Loading dictionaries successfull", $prog_name, $func_name, $deb_th, 0);


########################################################################
###     Setting up starting conditions
########################################################################

# find the starting scenario that starts with *
$scn_start = scenario_get_start(%scn_all);

# set current scenario to start scenario
$scn_current=$scn_start;

# set the scn_next also to scn start, this helps to get a valid state for this variable
$scn_next=$scn_start;

########################################################################
###     Main Loop
########################################################################

# creating per command vars 
my $command 		= "";
my $listen			= "";
my $matchstyle	= "";
my $action 		= "";

while ( $scn_current ne "NONE" )
{
	# setting scenario dependent variables
	$nomatchmode			= $scn_all{$scn_current}{"NoMatchMode"};
	$nextscenariomode		= $scn_all{$scn_current}{"NextScenarioMode"};
	
	# clearing per command variables 
	$command 		= "";
	$listen		= "";
	$matchstyle	= "";
	$action 		= "";
	
	# speech to text
	my $INPUT = get_voice(); # turn to get_voice($scn_current) when fully filled
	
	# going over all commands that are in the dict of current scenario
	FL_COMMANDS: for ( keys $dict_all{$scn_current} )
	{
		# looping over all commands	except in $comman_default

		# skipping default command, fallback command coming soon
		next FL_COMMANDS if ( $_ eq $command_default );
		
		
		# setting important vairiables
		$command 		= $_;												# current command
		$listen		= $dict_all{$scn_current}{$_}{"ListenFor"};		# matching string, what we listen for
		$matchstyle 	= $dict_all{$scn_current}{$_}{"MatchStyle"}; 	# matching style (simple|regex)
		$action 		= $dict_all{$scn_current}{$_}{"Action"};			# action to do
		
		print_debug( "LOOP: FL_COMMANDS", $prog_name, $func_name, $deb_th, 0);
		print_debug( "\$command:\t|$command|", $prog_name, $func_name, $deb_th, 0);
		print_debug( "\$listen:\t|$listen|", $prog_name, $func_name, $deb_th, 0);
		print_debug( "\$matchstyle:\t|$matchstyle|", $prog_name, $func_name, $deb_th, 0);
		print_debug( "\$action:\t|$action|", $prog_name, $func_name, $deb_th, 0);
		
		
		# lets check the MatchStyle (this is an ifthenelse-war, but perl
		# does not consistently support switch statements)	
		if ( $matchstyle eq "simple" )
		{
			# generate regex from simple string
			($listen, $action) = gen_regex_from_simple($listen, $action);
			
			# now put that regex back in and change MatchType, so we 
			# dont have to do that again
			$dict_all{$scn_current}{$command}{"ListenFor"} 	= $listen;
			$dict_all{$scn_current}{$command}{"Action"} 	= $action;
			$dict_all{$scn_current}{$command}{"MatchStyle"}	= "regex";
		}
		
		
		# matching regex against $INPUT
		if ( $INPUT =~ /$listen/ )
		{
			# ================================ #
			# This gets executed if we have a  #
			# match, just if you didnt notice  #
			# ================================ #
			
			print_debug( "Voice command |$INPUT| matches $listen", $prog_name, $func_name, $deb_th, 0);
			$ismatch = 1;
			
			
			# get a list of variables in $INPUT, if none are there, nothing will happen
			my  @match_list = ( $INPUT =~ /$listen/ );		
			
			
			# $action will be expanded ('!' vars) and '$' will be replaced
			$action = expand_special_expression($action, $scn_current, $command, %scn_all, %dict_all);
			print_debug( "expanded \$action: |$action|", $prog_name, $func_name, $deb_th, 0);
			
			
			$action =~ s/\$(\d+)/$match_list[($1-1)]/g;
			print_debug( "replaced \$action: |$action|", $prog_name, $func_name, $deb_th, 0);
			
			
			# performing action
			print_debug( "Action>>>>>>\n", $prog_name, $func_name, $deb_th, 0);
			system($action);
			print_debug( "\n\t\tAction<<<<<<", $prog_name, $func_name, $deb_th, 0);
			
			# leaving loop
			last FL_COMMANDS; 
		} 
		else
		{
			print_debug( "Voice command |$INPUT| does not match |$listen|\n", $prog_name, $func_name, $deb_th, 0);
		}

	} # FL_COMMANDS
	
	
	# retreiving next scenario
	$scn_next = get_next_scenario(	$ismatch,
									$nextscenariomode,
									$nomatchmode, 
									$scn_current, 
									$scn_start, 
									$command, 
									%scn_all, 
									%dict_all);
	
	# stating what has been found to be the next scenario, again
	print_debug( "NextScenario: |$scn_next|", $prog_name, $func_name, $deb_th, 0);
	
	# reset match varliable
	$ismatch = 0;
	
	# finally setting current scenario to next scenario
	$scn_current = $scn_next;

} # while

print_debug( "LEAVING $func_name", $prog_name, $func_name, $deb_th, 0);


########################################################################
###     function definitions
########################################################################

sub get_next_scenario($$$$$$\%\%)
{
	# this function returns the next scenario based on some 
	# switches (NoMatchMode, NextScenarioMode)
	# detailed info can be found in readme
	
	# ~
	my $func_name = "get_next_scenario";
	my $deb_th 	= 2;
	print_debug( "ENTERING $func_name", $prog_name, $func_name, $deb_th, 1);
	# ~
	
	my $ismatch 			= shift;
	my $nextscenariomode	= shift;
	my $nomatchmode		= shift;
	my $scn_current 		= shift;
	my $scn_start			= shift;
	my $cmd_current		= shift;
	my $scn_all			= shift;
	my $dict_all 			= shift;
	
	my $scn_next;
	
	# Next Scenario can be set per command or per scenario
	# If NetScenario is found, leave loop over all commands
	if ( $ismatch )
	{
		if (defined $$dict_all{$scn_current}{$cmd_current}{"NextScenario"} )
		{
			$scn_next = $$dict_all{$scn_current}{$cmd_current}{"NextScenario"};
		}
		elsif ( defined $$scn_all{$scn_current}{"NextScenario"} )
		{
			$scn_next = $$scn_all{$scn_current}{"NextScenario"};
		}
		else
		{
			print_debug( "Next scenario definition is missing", $prog_name, $func_name, $deb_th, 0);
			print_debug( "\$nextscenariomode: $nextscenariomode", $prog_name, $func_name, $deb_th, 0);
			
			exit 0 if ( $nextscenariomode eq "QUIT" );
			
			# if NextScenarioMode is not set to QUIT, then start again
			$scn_next = $scn_start;
		}
		
		# if no match is found, then set $scn_next according to NoMatchMode
		print_debug( "NoMatchMode is set to |$nomatchmode|", $prog_name, $func_name, $deb_th, 0);
	}
	else
	{
		print_debug( "No Match has been found", $prog_name, $func_name, $deb_th, 0);
		if ( $nomatchmode eq "START" )
		{
			$scn_next = $scn_start;
		}
		elsif ( $nomatchmode eq "STAY" )
		{
			#$scn_current = $scn_current;
		}
		else
		{
			print_debug( "NoMatchMode is set to |$nomatchmode| and not properly defined", $prog_name, $func_name, $deb_th, 0);
		}
	}
	
	return $scn_next;
}

sub expand_special_expression($$$\%\%)
{
	# ------------------------------------------------------------------
	# expanding !.. expressions
	#
	# expansion is done in following steps
	# while($command has !expressions)
	# 1. expand by definition in current command, if not defined then
	# 2. expand by definition in default command, if not defined then
	# 3. expand by definition in current scenario, if not defined then
	# 4. expand by definition in default scenario
	# endwhile
	#
	# We will only need to do 1. and 3., because the used config module
	# will automatically check for the default value if not given in 
	# current (see tie %.. command)
	# ------------------------------------------------------------------

	# ~
	my $func_name = "expand_special_expression";
	my $deb_th 	= 2;
	print_debug( "ENTERING $func_name", $prog_name, $func_name, $deb_th, 1);
	# ~
	
	my $exp				= shift;	# !expression
	my $current_scenario	= shift;	# current scenario
	my $current_command	= shift;
	my $scenarios 			= shift;	# hash with all scenarios
	my $dicts				= shift;	# hash with all dicts
	
	print_debug( "Expanding expression |$exp|", $prog_name, $func_name, $deb_th, 0);
	print_debug( "Current scenario is |$current_scenario|", $prog_name, $func_name, $deb_th, 0);
	print_debug( "Current command is |$current_command|", $prog_name, $func_name, $deb_th, 0);
	
	
	# as long as special expressions are found ...
	while ( $exp =~ /\!(\w+)/ )
	{
		print_debug( "Expression |$exp| is a special command", $prog_name, $func_name, $deb_th, 0);
	
		for ( $exp =~ /\!(\w+)/ )
		{
			# $_ holds current !exp name without '!'
			if ( defined $$dicts{$current_scenario}{$current_command}{$_} )
			{
				# replace found !.. by dict
				$exp =~ s/\!(\w+)/$$dicts{$current_scenario}{$current_command}{$1}/;
				print_debug( "Rule by command: |$exp|", $prog_name, $func_name, $deb_th, 0);
			}
			elsif ( defined $$scenarios{$current_scenario}{$_} )
			{
				# replace found !.. by scenario
				$exp =~ s/\!(\w+)/$$scenarios{$current_scenario}{$1}/;
				print_debug( "Rule by scenario: |$exp|", $prog_name, $func_name, $deb_th, 0);
			}
		} 
		
	}

	# return expanded command
	print_debug( "Expanded to: |$exp|", $prog_name, $func_name, $deb_th, 0);
	print_debug( "LEAVING $func_name", $prog_name, $func_name, $deb_th, 0);
	return $exp;
}

sub gen_regex_from_simple($$)
{
	# ------------------------------------------------------------------
	# generating regex from simple string
	#
	# simple means, absulute match.
	# we convert that into a regex and proceed
	# regex is /regex/, b/c we cant put '/' in a string
	#
	# also: 
	# if $VAR is detected, it will be replaced by a group that 
	# detects 1 word/number only
	# if @VAR is detected, it will be replaced by a 'taking all' regex,
	# this is done to allow someting like this:
	#
	# ListenFor = google @all
	# Action    = script_to_google "@all"
	# ------------------------------------------------------------------

	# ~
	my $func_name = "gen_regex_from_simple";
	my $deb_th 	= 2;
	print_debug( "ENTERING $func_name", $prog_name, $func_name, $deb_th, 1);
	# ~
	
	my $listen = shift;
	my $action = shift;
	
	print_debug( "\$listen: |$listen|", $prog_name, $func_name, $deb_th, 0);
	print_debug( "\$action: |$action|", $prog_name, $func_name, $deb_th, 0);
	
	# cleaning up the listen words
	chomp($listen);
	
	# replacing $(..) with $1, $2 ... in listen and action
	# first, save variable names
	my $counter=1;
	my $varname="";
	my $mode="unset";
	
	# first replace all @ by $_, this helps me to sort things easier
	print_debug( "Replacing @ by \$_", $prog_name, $func_name, $deb_th, 0);
	
	$listen =~ s/@(\w+?)/\$_$1/;
	$action =~ s/@(\w+?)/\$_$1/;
	
	print_debug( "\$listen: $listen", $prog_name, $func_name, $deb_th, 0);
	print_debug( "\$action: $action", $prog_name, $func_name, $deb_th, 0);
	
	#print "All vars found: ", ( $listen =~ /(\$\w*)?|(\@\w*)?/g ), "\n" if ($debug);
	for ( $listen =~ /\$(\w+)?/g )
	{
		# thats the first match in $listen
		$varname = $_;
		
		# checking if scalar or array variable
		$mode = "scalar" if ( $varname =~ /^[^\_]/ );
		$mode = "array" if ( $varname =~ /^\_/ );
		print_debug( "Detected mode is $mode", $prog_name, $func_name, $deb_th, 0);
		print_debug( "Found varname \$$_", $prog_name, $func_name, $deb_th, 0);
		
		# replace varnames in $action to $1, $2... 
		$action =~ s/(\$$varname)/\$$counter/g;
		
		# counting one up, so we know what ${num} ($1, $2,...} is
		$counter++;
	}
	print_debug( "New action is $action", $prog_name, $func_name, $deb_th, 0);
	
	
	# after replacing varnames in $action we gen. regex in $listen
	print_debug( "replace scalar vars", $prog_name, $func_name, $deb_th, 0);
	$listen =~ s/\$[^_](\w+)?/\(\\w\+\)\?/g;
	print_debug( "\$listen:\t$listen", $prog_name, $func_name, $deb_th, 0);
	
	print_debug( "replace array vars", $prog_name, $func_name, $deb_th, 0);
	$listen =~ s/\$[\_](\w+)?/\(\.\+\)\?/g;
	print_debug( "\$listen:\t$listen", $prog_name, $func_name, $deb_th, 0);
	
	# checking for absolute or non absulte match
	if ( ($listen =~ /^~/) )
	{
		print_debug( "Using NON absulute match", $prog_name, $func_name, $deb_th, 0);
		$listen =~ s/(^~( *))//;
	}
	else
	{
		print_debug( "Using absulute match", $prog_name, $func_name, $deb_th, 0);
		$listen = "^$listen\$";
	}
	
	print_debug( "Generated regex", $prog_name, $func_name, $deb_th, 0);
	print_debug( "\$listen: $listen", $prog_name, $func_name, $deb_th, 0);
	print_debug( "\$action: $action", $prog_name, $func_name, $deb_th, 0);
	
	# returning $listen and $action
	print_debug( "LEAVING $func_name", $prog_name, $func_name, $deb_th, 0);
	return ($listen, $action);
}

sub dict_get_all(\%)
{
	# ------------------------------------------------------------------
	# loading all dictionaries into one hash
	# ------------------------------------------------------------------

	# ~
	my $func_name = "dict_get_all";
	my $deb_th = 2;
	# ~
	print_debug( "ENTERING $func_name", $prog_name, $func_name, $deb_th, 1);
	
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
			tie my %tmp_dict, 'Config::IniFiles', ( -file => "$dict_files{$_}", -default => $command_default );
			$dict_all{$_} = \%tmp_dict;
			
			# debug information
			print_debug( "Tied $dict_all{$_} to file $dict_files{$_}", $prog_name, $func_name, $deb_th, 0);
			
		}
	}
	
	#print keys $dict_all{"*keyword"};
	# return hash with all dictionaries
	print_debug( "LEAVING $func_name", $prog_name, $func_name, $deb_th, 0);
	return %dict_all;
}

sub scenario_get_start(\%)
{
	# ------------------------------------------------------------------
	# this will return the starting scenario
	# ------------------------------------------------------------------

	# ~
	my $func_name = "scenario_get_start";
	my $deb_th = 2;
	# ~
	
	print_debug( "ENTERING $func_name", $prog_name, $func_name, $deb_th, 1);
	
	my $scenarios = shift;
	for (keys %$scenarios)
	{
		if (/^\*/) # probing if first character is '*'
		{
			print_debug( "Starting scenario is $_", $prog_name, $func_name, $deb_th, 0);
			return $_;
		}
	}
	
	# if this gets executed, then no starting scenario was found
	print_debug( "No Starting scenario found", $prog_name, $func_name, $deb_th, 0);
	
	print_debug( "LEAVING $func_name", $prog_name, $func_name, $deb_th, 0);
	return 1; 
}

sub get_voice()
{
	# ------------------------------------------------------------------
	# turn the mic on and get started:)
	# ------------------------------------------------------------------

	my $voice_string;
	
	# ~
	my $func_name = "scenario_get_start";
	my $deb_th = 2;
	# ~
	
	# For now we will fake an input string
	#my $INPUT="would you play wow from bANg and so on\n";
	print "Enter INPUT: ";
	$voice_string= <>;

	# now removing blanks at the beginning and the end
	chomp ($voice_string);
	$voice_string =~ s/^(( )*)?//;
	$voice_string =~ s/( )*?$//;
	
	return $voice_string;
}

sub print_debug($$$$$)
{
	# ------------------------------------------------------------------
	# printing debug messages
	# ------------------------------------------------------------------

	return 0 unless ( $debug );
	
	my $msg				= shift;
	my $prog_name			= shift;
	my $func_name			= shift;
	my $debug_threshold 	= shift;
	my $print_names 		= shift;
	
	if ($debug >= $debug_threshold )
	{
			if ( $print_names )
		{
			print "\n$prog_name", "::", "$func_name", "\n\t\t", "$msg\n";
		}
		else
		{
			print "\t\t", "$msg\n";
		}
	}
}
