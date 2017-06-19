#
# LNXHC::SysVar.pm
#   Linux Health Checker support functions for system variable handling
#
# Copyright IBM Corp. 2012
#
# Author(s): Peter Oberparleiter <peter.oberparleiter@de.ibm.com>
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors: See file CONTRIBUTORS which is part of this package
#

package LNXHC::SysVar;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catdir catfile);


#
# Local imports
#
use LNXHC::Consts qw($CHECK_T_DEPS $CHECK_T_ID $DEP_T_DEP $DEP_T_EXPR
		     $SYSVAR_DIRECTORY);
use LNXHC::Expr qw(expr_evaluate);
use LNXHC::Misc qw(info3 run_cmd);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&sysvar_check_deps &sysvar_get &sysvar_get_copy
		    &sysvar_get_ids &sysvar_set);


#
# Constants
#


#
# Global variables
#

# Hash containing system variables
my $_sysvar_db;


#
# Sub-routines
#

#
# _init_sysvar_db()
#
# Initialize lnxhc system variables.
#
sub _init_sysvar_db()
{
	my $dir = catdir($main::lib_dir, $SYSVAR_DIRECTORY);
	my $dir_handle;
	my %env;

	# C Locale - set this to ensure that sysvar programs don't need to
	# implement locale-specific parsing of locale-aware helper program
	# output.
	$env{"LC_ALL"} = "C";

	$_sysvar_db = {};
	opendir($dir_handle, $dir) or
		die("Could not read directory '$dir': $!\n");
	foreach my $entry (sort(readdir($dir_handle))) {
		my $cmd = catfile($dir, $entry);
		my ($err, $exit_code, $output);
		my @lines;

		# Skip invalid entries
		next if ($entry eq "." || $entry eq "..");
		# Run command
		info3("Running sysvar command '$cmd'\n");
		($err, $exit_code, $output) = run_cmd($cmd, undef, undef, undef,
						      \%env);
		if (defined($err)) {
			die("Could not run '$cmd': $err!\n");
		} elsif ($exit_code != 0) {
			die("Command '$cmd' return with exit code ".
			    "$exit_code!\n");
		}
		# Process output
		@lines = split(/\n/, $output);
		foreach my $line (@lines) {
			next if ($line !~ /^(sys_[^=]+)=(.*)$/i);

			$_sysvar_db->{lc($1)} = $2;
		}
	}
	closedir($dir_handle);
}

#
# sysvar_set(spec)
#
# Overwrite the value of a system variable.
#
sub sysvar_set($)
{
	my ($spec) = @_;
	my $key;
	my $value;

	if ($spec !~ /^([^=]+)=(.*)$/) {
		die("Cannot set sysvar '$spec': unknown parameter format!\n");
	}
	($key, $value) = ($1, $2);

	# Lazy sysvar_db initialization
	_init_sysvar_db() if (!defined($_sysvar_db));

	$_sysvar_db->{$key} = $value;
}

#
# sysvar_get(var)
#
# Return value of system variable VAR;
#
sub sysvar_get($)
{
	my ($var) = @_;

	# Lazy sysvar_db initialization
	_init_sysvar_db() if (!defined($_sysvar_db));

	return $_sysvar_db->{$var};
}

#
# sysvar_get_ids()
#
# Return list of system variables
#
sub sysvar_get_ids()
{
	# Lazy sysvar_db initialization
	_init_sysvar_db() if (!defined($_sysvar_db));

	return keys(%{$_sysvar_db});
}

#
# sysvar_check_deps(check)
#
# Check if the dependencies of the specified CHECK are met.
#
# Result: (msg, 0) if dependencies are not met
#         (undef, 1) if dependencies are met
#
sub sysvar_check_deps($)
{
	my ($check) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $deps = $check->[$CHECK_T_DEPS];
	my $dep;

	# Lazy sysvar_db initialization
	_init_sysvar_db() if (!defined($_sysvar_db));

	# Evaluate each dependency
	foreach $dep (@$deps) {
		my $expr = $dep->[$DEP_T_EXPR];

		# Check dependency expression
		if (!expr_evaluate($check_id, $expr, $_sysvar_db)) {
			return ($dep->[$DEP_T_DEP], 0);
		}
	}

	return (undef, 1);
}

#
# sysvar_get_copy()
#
# Return a reference to a hash containing all system variables and values for
# the local host.
#
sub sysvar_get_copy()
{
	my %copy;

	# Lazy sysvar_db initialization
	_init_sysvar_db() if (!defined($_sysvar_db));

	%copy = %{$_sysvar_db};

	return \%copy;
}


#
# Code entry
#

# Indicate successful module initialization
1;
