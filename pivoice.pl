#!/usr/bin/perl

use warnings;
use strict;
use Config::IniFiles;

print "Hello World\n";

my %ini;
tie %ini, 'Config::IniFiles', ( -file => "./default.config.ini" );

my @secs=keys %{$ini{voice}};

print "@secs\n";

print Config::IniFiles::Sections;
