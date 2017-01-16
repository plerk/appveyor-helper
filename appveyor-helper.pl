use strict;
use warnings;
use 5.010;
use File::Basename qw( dirname );
use Env qw( @PATH );
use File::Spec;

my $dir = dirname __FILE__;

my $ci_perl          = $ENV{CI_PERL} // 'strawberry';
my $ci_perl_version  = $ENV{CI_PERL_VERSION};
my $ci_perl_wordsize = $ENV{CI_PERL_WORDSIZE} // 64;

my $mode = 'none';

if(-f 'dist.ini')
{ $mode = 'dzil' }
elsif(-f 'Build.PL')
{ $mode = 'mb' }
elsif(-f 'Makefile.PL')
{ $mode = 'mm' }
elsif(-f 'cpanfile')
{ $mode = 'cpanfile' }

sub run
{
  say "> @_";
  system @_;
  if($?)
  {
    die "execute faled";
  }
}

my @env_to_save;

if($ci_perl eq 'strawberry')
{
  $ci_perl_version //= '5.24';
  my $bits = $ci_perl_wordsize;

  my %urls = (
    '5.24' => "http://strawberryperl.com/download/5.24.0.1/strawberry-perl-5.24.0.1-${bits}bit.msi",
    '5.22' => "http://strawberryperl.com/download/5.22.2.1/strawberry-perl-5.22.2.1-${bits}bit.msi",
    '5.20' => "http://strawberryperl.com/download/5.20.3.3/strawberry-perl-5.20.3.3-${bits}bit.msi",
    '5.18' => "http://strawberryperl.com/download/5.18.4.1/strawberry-perl-5.18.4.1-${bits}bit.msi",
  );

  unless(-d 'c:/strawberry')
  {
    run 'curl', -O => $urls{$ci_perl_version};
  
    my $msi_filename = $urls{$ci_perl_version};
    $msi_filename =~ s!^.*\/!!;
  
    run 'msiexec', '/i', $msi_filename, '/quiet', '/qn', '/norestart';
  }
  
  unshift @PATH, qw(
    C:\strawberry\c\bin
    C:\strawberry\perl\site\bin
    C:\strawberry\perl\bin
  );
  
  push @env_to_save, 'PATH';
}
elsif($ci_perl eq 'activestate')
{
}
elsif($ci_perl eq 'msys2')
{
}
elsif($ci_perl eq 'cygwin')
{
  if($ci_perl_wordsize == 32)
  {
    unshift @PATH, qw(
      C:\cygwin\usr\local\bin
      C:\cygwin\usr\bin
      C:\cygwin\bin
    );
  }
  elsif($ci_perl_wordsize == 64)
  {
    unshift @PATH, qw(
      C:\cygwin64\usr\local\bin
      C:\cygwin64\usr\bin
      C:\cygwin64\bin
    );
  }
  unshift @PATH, File::Spec->catdir($dir, 'bat');
  push @env_to_save, 'PATH';
}
else
{
  die "unknown ci_perl: $ci_perl";
}

run 'perl', '-v';

#eval {
#  run 'cpanm', '-n', 'App::cpanoutdated';
#  my @outdated = `cpan-outdated`;
#  chomp @outdated;
#  run 'cpanm', '-n', @outdated;
#};

if($@)
{
  say "update of outdated modules failed, proceeding anyway";
}

if($mode eq 'dzil')
{
  run 'cpanm', '-n', 'Dist::Zilla';
  my @authordeps = `dzil authordeps --missing`;
  chomp @authordeps;
  run 'cpanm', '-n', @authordeps;
  my @listdeps   = `dzil listdeps --missing`;
  chomp @listdeps;
  run 'cpanm', '-n', @listdeps;
  #run 'dzil', 'run', 'cpanm --installdeps .';
}
elsif($mode ne 'none')
{
  run 'cpanm', '--installdeps', '.';
}

my $fn = File::Spec->catfile($dir, 'appveyor-helper-env.bat');
open my $fh, '>', $fn;
say $fh "SET $_=$ENV{$_}" for @env_to_save;
close $fh;