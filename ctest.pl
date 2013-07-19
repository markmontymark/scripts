#!/perl

use strict;
use warnings;

use Test::More;
use File::Which;
use File::Find;
use JSON::XS;
use File::Slurp;
use Getopt::Long;
use Algorithm::Diff;

my $test_cfg_file = shift;
my $test_dir = shift;
my $do_save = 0;

my $valgrind = File::Which::which('valgrind');
my $do_valgrind = 0;

GetOptions(
	'valgrind' => \$do_valgrind
);

my $cfg = JSON::XS::decode_json( File::Slurp::read_file($test_cfg_file));

&walk( $test_dir, \&run_tests );
done_testing();
&save_cfg($cfg,$test_cfg_file) if $do_save;
exit;


sub run_tests
{
	my($path) = shift;
	my($name) = $path =~ m/\/+(.*?)$/;
	unless(exists $cfg->{$name})
	{
		print "Found test, $path, but $name doesn't exist in test config...Skipping\n";
		return;
	}
	
	my $test_cfg = $cfg->{$name};
	if($test_cfg && ref $test_cfg eq 'ARRAY')
	{
		&run_tests_on_cfg($_,$path) for @$test_cfg;
	}
	else
	{
		&run_tests_on_cfg($test_cfg,$path);
	}
}

sub run_tests_on_cfg
{
	my($test_cfg,$path) = @_;
	my $name = $test_cfg->{name};
	if(exists $test_cfg->{expected_file})
	{
		$test_cfg->{expected} = File::Slurp::read_file($test_cfg->{expected_file});
		#$do_save = 1;
	}

	my $test_args = exists $test_cfg->{args} ? $test_cfg->{args} : undef;
	unless(exists $test_cfg->{expected} or exists $test_cfg->{regex_expected})
	{
		print "Found test with $name but no 'expected' or 'regex_expected' is set...Skipping\n";
		return;
	}
	my $cmdline = $path;
	$cmdline .= " $test_args" if defined $test_args;
	&basic_test($cmdline,$test_cfg);
	&valgrind_test($cmdline,$test_cfg) if $do_valgrind;
}

sub basic_test
{
	my($cmdline, $test_cfg) = @_;
	return unless exists $test_cfg->{expected} or exists $test_cfg->{regex_expected};
	my $test_name = $test_cfg->{name};
	my @ogot =  `$cmdline`;
	my $got = &trim(join '',@ogot);
	if(exists $test_cfg->{regex_expected})
	{
		&complain_about_unescaped_regex_modifiers($test_name,$test_cfg->{regex_expected});
		like($got, $test_cfg->{regex_expected} , $test_name);
	}
	else
	{
		my $r;
      ## handle JSON not allowing multiline string literals by using array ref and joining with \n
      if( ($r = ref $test_cfg->{expected}) && $r eq 'ARRAY')
      {
         is($got, &trim(join "\n",@{$test_cfg->{expected}}) , $test_name);
      }
      else
      {
         is($got, &trim($test_cfg->{expected}) , $test_name);
			if( $got ne &trim($test_cfg->{expected}))
			{
				print "do_diff\n",&do_diff(\@ogot, [(map{"$_\n"}(split "\n",$test_cfg->{expected}))]),"\n\n";
			}
      }
	}
}

sub valgrind_test
{
	my($cmdline, $test_cfg) = @_;
	return unless defined $valgrind;
	return unless exists $test_cfg->{expected} or exists $test_cfg->{regex_expected};
	my $test_name = $test_cfg->{name} . ' Valgrind clean';
	my $got = &trim(join '',`$valgrind --leak-check=full $cmdline 2>&1`);
	like( $got , '/All heap blocks were freed -- no leaks are possible/is', $test_name );
}

sub complain_about_unescaped_regex_modifiers
{
   my($testname,$str) = @_;
   my($unwrapped_str) = $str;
   $unwrapped_str =~ s/^\///;
   $unwrapped_str =~ s/\/$//s;
   my @chars = split '',$unwrapped_str;
   my $i = -1;
   for(@chars)
   {
      $i++;
      next unless /[?\/*()+.]/;
      if( /[*+]/)
      {
         next if $i > 2 && ($chars[$i - 1] eq '\\' or $chars[$i-2] eq '\\' or $chars[$i-1] eq ']');
      }
      elsif( /[()]/)
      {
         next if $i > 2 && ($chars[$i - 1] eq '\\' or $chars[$i-2] eq '\\' or $chars[$i+1] eq '{');
      }
      else
      {
         next if $i > 1 && $chars[$i - 1] eq '\\';
      }
      print STDERR "xxxxx   test $testname has regex modifier $_ at pos $i\n";
   }
}


sub trim
{
	my $s = shift;
	$s =~ s/^\s+//;
	$s =~ s/\s+$//mg;
	$s
}

sub walk
{
	my($dir,$callback) = @_;
	$dir =~ s/\/$//; ## Remove trailing slash because we'll be adding one in `map` below
	opendir D,$dir || die "Can't opendir $dir, $!\n";
	my @entries = map{"$dir/$_"} grep !/^\./, readdir D;
	my @bins;
	my @dirs;
	for(@entries)
	{
		if( -d $_ )
		{
			push @dirs,$_;
		}
		elsif( -B $_ and -X $_ and (not -l $_) )
		{
			push @bins,$_;
		}
	}
	closedir D;
	$callback->($_) for sort @bins;
	&walk($_,$callback) for sort @dirs;
}

sub save_cfg
{
   my($cfg,$path) = @_;
   my $coder = JSON::XS->new->ascii->pretty->allow_nonref;
   File::Slurp::write_file($path,$coder->encode($cfg));
}

sub do_diff
{
	my($seq1,$seq2) = @_;
	my $diff = Algorithm::Diff->new( $seq1, $seq2 );
	$diff->Base( 1 );   # Return line numbers, not indices
	my @retval;
	while(  $diff->Next()  ) {
		next   if  $diff->Same();
		my $sep = '';
		if(  ! $diff->Items(2)  ) 
		{
			push @retval,sprintf("%d,%dd%d\n", $diff->Get(qw( Min1 Max1 Max2 )));
		} 
		elsif(  ! $diff->Items(1)  ) 
		{
			push @retval,sprintf("%da%d,%d\n", $diff->Get(qw( Max1 Min2 Max2 )));
		} 
		else 
		{
			$sep = "---\n";
			push @retval,sprintf("%d,%dc%d,%d\n", $diff->Get(qw( Min1 Max1 Min2 Max2 )));
		}
		push(@retval,"< $_")   for  $diff->Items(1);
		push(@retval, $sep);
		push(@retval,"> $_")   for  $diff->Items(2);
	}
	join '',@retval
}


