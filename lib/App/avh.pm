package App::avh;

use strict;
use warnings;
use autodie;
use 5.010;
use File::Basename qw( dirname );

sub main
{
  my $command = shift @ARGV;
  
  if($command eq 'wrapper')
  {
    my $alias = shift @ARGV;
    if($^O eq 'cygwin' || $^O eq 'msys')
    {
      my $dir = dirname __FILE__;
      my $filename = "$dir/../../wrapper/$alias.bat";
      open my $fh, '>', $filename;
      say $fh '@echo off';
      say $fh q{perl -e "exec '}, $alias, q{', @ARGV; die 'command not found'" -- %*}; 
      say $fh 'if %errorlevel% == 9009 echo You do not have Perl in your PATH.';
      say $fh 'if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul';
      close $fh;
    }
  }
  elsif($command eq 'which')
  {
    my $command = shift @ARGV;
    unless(eval { require File::Which; 1})
    {
      system 'cpanm', '-v', 'File::Which';
      require File::Which;
    }
    say for File::Which::which($command);
  }
  elsif($command eq 'whichpm')
  {
    unless(eval { require Module::Which; 1 })
    {
      system 'cpanm', 'Module::Which';
      require Module::Which;
    }
    foreach my $module (@ARGV)
    {
      my $info = Module::Which::Which($module);
      say "[$module]";
      unless($info)
      {
        say "  NOT INSTALLED";
        next;
      }
      my $path = $info->{$module}->{path};
      my $version = $info->{$module}->{version};
      say "  path    = $path";
      say "  version = $version";
    }
  }
  else
  {
    die "unknown command";
  }
}

1;
