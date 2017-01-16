@echo off
echo cpanm wrapper
perl -e "exec 'cpanm', @ARGV" -- %*
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
