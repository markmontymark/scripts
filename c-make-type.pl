#!perl

package types;

use File::Basename;
use File::Slurp;


sub create_file
{
	my($path, $content) = @_;
	my $basepath = dirname($path);
	mkdir $basepath unless -d $basepath;
	open F,">$path" || die "Can't create file, $path, $!\n";
	print F $content;	
	close F;
}

sub simple
{
	my($klass) = @_;
	
	&create_file("./$klass.h",qq~
#ifndef C_PATTERNS_$klass~.qq~_H_
#define C_PATTERNS_$klass~.qq~_H_

typedef struct $klass $klass~.qq~_t;
struct $klass
{
};
#define $klass~.qq~_s sizeof($klass~.qq~_t)

$klass~.qq~_t * $klass~.qq~_new() ;
void $klass~.qq~_free() ;

#endif
~);

	&create_file("./$klass.c",qq~

#include "stdlib.h"
#include "$klass.h"

$klass~.qq~_t * $klass~.qq~_new() 
{
	$klass~.qq~_t * obj = malloc( $klass~.qq~_s );
	return obj;
}


void $klass~.qq~_free($klass~.qq~_t * obj) 
{
	if( obj == NULL )
		return;
	free(obj);
}


~);

}


package main;

use strict;
use warnings;

use v5.16;

my $subname = shift;
my $obj = bless {},'types';
my $sub = UNIVERSAL::can($obj,$subname);
die "$subname isn't a valid subroutine name in package types\n"
	unless defined $sub;

$sub->($_) for @ARGV;

exit;

