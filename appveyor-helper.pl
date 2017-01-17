use strict;
use warnings;
use 5.010;
use File::Basename qw( dirname );
use Env qw( @PATH );
use File::Spec;
use File::Path qw( mkpath );

mkpath 'c:/avh/bin', 0, 0755;
mkpath 'c:/avh/cygwin-setup-cache', 0, 0755;

my $dir = dirname __FILE__;

my $ci_perl          = $ENV{CI_PERL} // 'strawberry';
my $ci_perl_version  = $ENV{CI_PERL_VERSION};
my $ci_perl_wordsize = $ENV{CI_PERL_WORDSIZE} // 64;

my $mode = $ENV{CI_PERL_MODE} // 'none';

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
    unlink $msi_filename;
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
  if($ci_perl_wordsize != 64)
  {
    die "only MSYS2 64 bit is supported atm";
  }
  
  unshift @PATH, qw(
    C:\avh\bin
    c:\msys64\usr\bin
  );
  
  $ENV{PERL5LIB}            = '/c/avh/lib/perl5';
  $ENV{PERL_LOCAL_LIB_ROOT} = '/c/avh';
  $ENV{PERL_MB_OPT}         = '--install_base /c/avh';
  $ENV{PERL_MM_OPT}         = 'INSTALL_BASE=/c/avh';

  run 'bash', '-l', -c => 'true';
  run 'bash', '-l', -c => 'pacman -Syuu --noconfirm';
  run 'bash', '-l', -c => 'pacman -S make --noconfirm';
  run 'bash', '-l', -c => 'pacman -S gcc --noconfirm';
  run 'bash', '-l', -c => 'pacman -S perl --noconfirm';
  
  run 'curl', -o => 'cpanm-bootstrap', 'https://cpanmin.us';
  run 'perl', 'cpanm-bootstrap', 'App::cpanminus';
  unlink 'cpanm-bootstrap';
  
  push @PATH, File::Spec->catdir($dir, 'wrapper');
  
  run 'cpanm', 'Module::CoreList';
  
  push @env_to_save, qw( PATH PERL5LIB PERL_LOCAL_LIB_ROOT PERL_MB_OPT PERL_MM_OPT );
}
elsif($ci_perl eq 'cygwin')
{
  my $setup_url;
  my @setup = qw( -q -g --local-package-dir c:\avh\cygwin-setup-cache );

  if($ci_perl_wordsize == 32)
  {
    unshift @PATH, qw(
      C:\avh\bin
      C:\cygwin\usr\local\bin
      C:\cygwin\usr\bin
      C:\cygwin\bin
    );
    $setup_url = 'https://cygwin.com/setup-x86.exe';
    push @setup, '-R', 'c:\cygwin';
  }
  elsif($ci_perl_wordsize == 64)
  {
    unshift @PATH, qw(
      C:\avh\bin
      C:\cygwin64\usr\local\bin
      C:\cygwin64\usr\bin
      C:\cygwin64\bin
    );
    $setup_url = 'https://cygwin.com/setup-x86_64.exe';
    push @setup, '-R', 'c:\cygwin64';
  }
  
  run 'curl', -o => 'c:/avh/bin/cyg-setup.exe', $setup_url;
  run 'cyg-setup', @setup, -P => join(',', qw(
    zlib-devel
    openssl-devel
    libxml2-devel
    libuuid-devel
    libsasl2-devel
    libreadline-devel
    libpq-devel
    libpng16-devel
    libpng-devel
    libpcre-devel
    libncurses-devel
    liblzo2-devel
    liblzma-devel
    libintl-devel
    libiconv-devel
    libfreetype-devel
    libfontconfig-devel
    libedit-devel
    libdb-devel
    libcrypt-devel
    libffi-devel
    libexpat-devel
    libbz2-devel
    libarchive-devel
    libGL-devel
    libEGL-devel
    cygwin-devel
  ));

  run 'cyg-setup', @setup, -P $ENV{CI_PERL_CYGWIN_PACKAGES} if $ENV{CI_PERL_CYGWIN_PACKAGES};
  
  $ENV{PERL5LIB}            = '/cygdrive/c/avh/lib/perl5';
  $ENV{PERL_LOCAL_LIB_ROOT} = '/cygdrive/c/avh';
  $ENV{PERL_MB_OPT}         = '--install_base /cygdrive/c/avh';
  $ENV{PERL_MM_OPT}         = 'INSTALL_BASE=/cygdrive/c/avh';
  
  run 'curl', -o => 'cpanm-bootstrap', 'https://cpanmin.us';
  run 'perl', 'cpanm-bootstrap', 'App::cpanminus';
  unlink 'cpanm-bootstrap';
  
  push @PATH, File::Spec->catdir($dir, 'wrapper');
  push @env_to_save, qw( PATH PERL5LIB PERL_LOCAL_LIB_ROOT PERL_MB_OPT PERL_MM_OPT );
}
else
{
  die "unknown ci_perl: $ci_perl";
}

unshift @PATH, File::Spec->catdir($dir, 'bat');

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

if($ENV{CI_PERL_MOD})
{
  foreach my $mod (split /\//, $ENV{CI_PERL_MOD})
  {
    run 'cpanm', '-n', '-v', $mod;
  }
}

if($mode eq 'dzil')
{
  run 'cpanm', '-n', 'Dist::Zilla';
  if(-f 'dist.ini')
  {
    my @authordeps = `dzil authordeps --missing`;
    chomp @authordeps;
    run 'cpanm', '-n', @authordeps;
    my @listdeps   = `dzil listdeps --missing`;
    chomp @listdeps;
    run 'cpanm', '-n', @listdeps;
  }
}
elsif($mode ne 'none')
{
  run 'cpanm', '--installdeps', '.';
}

my $fn = File::Spec->catfile($dir, 'appveyor-helper-env.bat');
open my $fh, '>', $fn;
say $fh "SET $_=$ENV{$_}" for @env_to_save;
close $fh;