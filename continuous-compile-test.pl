#!/usr/bin/env perl

use strict;
use warnings;
use File::Find;

my $dir = shift || './';
my %files = ();

## change to match suffixes for your project
my $qr_extensions = qr/\.(?:pl|pm|t$)/;

## using this for Perl5 so dont need a compile cmd, but you could 
## do something like perl -cw ./myscript.pl, but I find just trying
## to run the tests in t/ with prove is good enough.
my $compile_cmd = undef; ##'prove';
## this works nicely for projects with a t/ dir full of TAP-style tests
my $test_cmd = 'prove';

File::Find::find( sub {
	return unless -e $_ && -f $_;
	return unless $_ =~ $qr_extensions;
	$files{ $File::Find::name } = -M $_;
}, $dir );

print "Watching files...\n";
print "\t",$_,"\n" for sort keys %files;

while(1)
{
	sleep 1;
	my $changed = 0;
	for(sort keys %files)
	{
		if( -M $_ != $files{$_} )
		{
			$changed = 1;
			$files{$_} = -M $_;
			last;
		}
	}
	if($changed)
	{
		`$compile_cmd` if defined $compile_cmd;
		`$test_cmd` if defined $test_cmd;
		print "\n\n";
		sleep 1;
	}
}

