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

my %dict_all;						# hash of all dicts, sorted by scenario

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

#~~~~ test ~~~~~# 
#my $test = expand_special_expression("!say", $scn_start, "playsong", %scn_all, %dict_all);
#~~~~ test ~~~~~#


my $INPUT = get_voice();

########################################################################
###     Main Loop
########################################################################

# going over all commands that are in the dict of current scenario
FL_COMMANDS: for ( keys $dict_all{$scn_current} )
{
	# looping over all commands	except in $comman_default

	# skipping default command
	next FL_COMMANDS if ( $_ eq $command_default );
	
	#TODO Weiter code aufräumen
	
	# setting important vairiables
	my $command 		= $_;												# current command
	my $listen			= $dict_all{$scn_current}{$_}{"ListenFor"};		# matching string, what we listen for
	my $matchstyle 	= $dict_all{$scn_current}{$_}{"MatchStyle"}; 	# matching style (simple|regex)
	my $action 		= $dict_all{$scn_current}{$_}{"Action"};			# action to do
	my $scn_next;															# Next Scenario
	
	print_debug( "Checking command <$command> with <$listen>", $prog_name, $func_name, $deb_th, 0);
	
	# lets check the MatchStyle (this is an ifthenelse-war, but perl
	# does not consistently support switch statements)
	
	print_debug( "Match Type for command $command is $matchstyle", $prog_name, $func_name, $deb_th, 0);
	
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
		
		# get a list of variables in $INPUT
		my  @match_list = ( $INPUT =~ /$listen/ );
		
		# DEBUG
		print_debug( "Voice command |$INPUT| matches $listen", $prog_name, $func_name, $deb_th, 0);
		my $count = scalar @match_list;
		print_debug( "Command has $count parameters: ", $prog_name, $func_name, $deb_th, 0);
		for ( @match_list )
		{
			print_debug( "$_ ", $prog_name, $func_name, $deb_th, 0);
		}
		# DEBUG END
		
		# the $action string will be split up, then every part will 
		# be expanded, then the variables will be replaced.
		$action = expand_special_expression($action, $scn_current, $command, %scn_all, %dict_all);
		$action =~ s/\$(\d+)/$match_list[($1-1)]/g;
		print_debug( "\$action is: |$action|", $prog_name, $func_name, $deb_th, 0);
		
		print_debug( "Action>>>>>>\n", $prog_name, $func_name, $deb_th, 0);
		
		# performing action
		system($action);
		print_debug( "\n\t\tAction<<<<<<", $prog_name, $func_name, $deb_th, 0);
		
		# Next Scenario can be set per command or per scenario
		# If NetScenario is found, leave loop over all commands
		if (defined $dict_all{$scn_current}{$_}{"NextScenario"} )
		{
			$scn_next = $dict_all{$scn_current}{$_}{"NextScenario"};
			last FL_COMMANDS;
		}
		elsif ( defined $scn_all{$scn_current}{"NextScenario"} )
		{
			$scn_next = $scn_all{$scn_current}{"NextScenario"};
			last FL_COMMANDS; 
		}
		else
		{
			print "Next scenario definition is missing\n";
		}
		print_debug( "Next scenario is $scn_next", $prog_name, $func_name, $deb_th, 0);
		
	} 
	else
	{
		print_debug( "Voice command |$INPUT| does not match |$listen|\n", $prog_name, $func_name, $deb_th, 0);
	}

}

print_debug( "LEAVING $func_name", $prog_name, $func_name, $deb_th, 0);


########################################################################
###     function definitions
########################################################################

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
	my $deb_th 	= 1;
	print_debug( "ENTERING $func_name", $prog_name, $func_name, $deb_th, 1);
	# ~
	
	my $listen = shift;
	my $action = shift;
	
	print_debug( "\$listen: $listen", $prog_name, $func_name, $deb_th, 0);
	print_debug( "\$action: $action", $prog_name, $func_name, $deb_th, 0);
	
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
		print_debug( "Replacing \$ and \$_ vars", $prog_name, $func_name, $deb_th, 0);
		print_debug( "Found varname \$$_", $prog_name, $func_name, $deb_th, 0);
		print_debug( "Current action is $action", $prog_name, $func_name, $deb_th, 0);
		
		# replace varnames in $action to $1, $2... 
		$action =~ s/(\$$varname)/\$$counter/g;
		
		print_debug( "New action is $action", $prog_name, $func_name, $deb_th, 0);
		
		# counting one up, so we know what ${num} ($1, $2,...} is
		$counter++;
	}
	
	
	# after replacing varnames in $action we gen. regex in $listen
	$listen =~ s/\$[^_](\w+)?/\(\\w\+\)\?/g;
	print_debug( "regex 1st run: $listen", $prog_name, $func_name, $deb_th, 0);
	
	$listen =~ s/\$[\_](\w+)?/\(\.\+\)\?/g;
	print_debug( "regex 2nd run: $listen", $prog_name, $func_name, $deb_th, 0);
	
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
	
	print_debug( "Generated regex $listen", $prog_name, $func_name, $deb_th, 0);
	
	
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
	my $deb_th = 1;
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
	my $deb_th = 1;
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
	my $deb_th = 1;
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
