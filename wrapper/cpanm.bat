@echo off
perl -e "exec 'cpanm', @ARGV; die 'command not found'" -- %*
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
