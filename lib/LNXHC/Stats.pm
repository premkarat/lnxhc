#
# LNXHC::Stats.pm
#   Linux Health Checker statistics data handling
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

package LNXHC::Stats;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#
use LNXHC::Consts qw($CHECK_STATS_T_EX_HIGH $CHECK_STATS_T_EX_LOW
		     $CHECK_STATS_T_EX_MEDIUM $CHECK_STATS_T_EX_TOTAL
		     $CHECK_STATS_T_RUN_EXCEPTIONS
		     $CHECK_STATS_T_RUN_FAILED_CHKPROG
		     $CHECK_STATS_T_RUN_PARAM_ERROR
		     $CHECK_STATS_T_RUN_FAILED_SYSINFO
		     $CHECK_STATS_T_RUN_NOT_APPLICABLE
		     $CHECK_STATS_T_RUN_SUCCESS $CHECK_STATS_T_RUN_TOTAL
		     $CHECK_STATS_T_TIME_AVG $CHECK_STATS_T_TIME_MAX
		     $CHECK_STATS_T_TIME_MIN $CRDS_EX_T_SEVERITY
		     $CRDS_RUN_T_CHECK_ID $CRDS_RUN_T_END $CRDS_RUN_T_EXCEPTIONS
		     $CRDS_RUN_T_RC $CRDS_RUN_T_START $CRDS_SUMMARY_T_EXCEPTIONS
		     $CRDS_SUMMARY_T_FAILED_CHKPROG
		     $CRDS_SUMMARY_T_PARAM_ERROR
		     $CRDS_SUMMARY_T_FAILED_SYSINFO
		     $CRDS_SUMMARY_T_NOT_APPLICABLE $CRDS_SUMMARY_T_SUCCESS
		     $SEVERITY_T_HIGH $SEVERITY_T_LOW $SEVERITY_T_MEDIUM
		     $STATS_STORED_FILENAME $STAT_T_CHECK_STATS_DB);
use LNXHC::Misc qw(info2 quiet_retrieve quiet_store);
use LNXHC::UData qw(udata_get_path);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&stats_add_run &stats_get_check &stats_new
		    &stats_new_check);


#
# Constants
#


#
# Global variables
#

# Run-time statistics
my $_stats;

# Flag indicating whether statistics should be written on program exit
my $_write_stats;


#
# Sub-routines
#

#
# stats_new()
#
# Set statistics data set to a new, empty data set.
#
sub stats_new()
{
	# Create empty statistics data set
	$_stats = [ {} ];

	# Set write marker
	$_write_stats = 1;
}

#
# _init_stats()
#
# Initialize statistics data from saved data. If no saved data exists,
# create an empty data set.
#
sub _init_stats()
{
	my $filename = udata_get_path($STATS_STORED_FILENAME);

	if (-e $filename) {
		# Read data file
		info2("Initializing statistics database\n");
		$_stats = quiet_retrieve($filename);
	} else {
		info2("No statistics data found\n");
		# Create empty data set.
		stats_new();
	}
}

#
# _write_stats()
#
# Write statistics data set.
#
sub _write_stats()
{
	my $filename = udata_get_path($STATS_STORED_FILENAME);

	quiet_store($_stats, $filename) or
		warn("Could not write statistics file '$filename'\n");
}

#
# stats_get_check(check_id)
#
# Return statistics data set for specified CHECK_ID.
#
sub stats_get_check($)
{
	my ($check_id) = @_;
	my $check_stats_db;

	# Lazy statistics data set initialization
	_init_stats() if (!defined($_stats));

	$check_stats_db = $_stats->[$STAT_T_CHECK_STATS_DB];

	return $check_stats_db->{$check_id};
}

#
# stats_new_check(check_id)
#
# Create an empty data set for check CHECK_ID and return it.
#
sub stats_new_check($)
{
	my ($check_id) = @_;
	my $check_stats;
	my $check_stats_db;

	# Lazy statistics data set initialization
	_init_stats() if (!defined($_stats));

	$check_stats_db = $_stats->[$STAT_T_CHECK_STATS_DB];

	# Create new check_stats_t
	$check_stats = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];

	# Add to data base
	$check_stats_db->{$check_id} = $check_stats;

	# Set write marker
	$_write_stats = 1;

	return $check_stats;
}

#
# stats_add_run(run)
#
# Add check run data RUN to statistics data set.
#
sub stats_add_run($)
{
	my ($run) = @_;
	my $check_id	= $run->[$CRDS_RUN_T_CHECK_ID];
	my $summary	= $run->[$CRDS_RUN_T_RC];
	my $exs		= $run->[$CRDS_RUN_T_EXCEPTIONS];
	my $start	= $run->[$CRDS_RUN_T_START];
	my $end		= $run->[$CRDS_RUN_T_END];
	my $ex;
	my $check_stats;

	# Get data set
	$check_stats = stats_get_check($check_id);
	if (!defined($check_stats)) {
		$check_stats = stats_new_check($check_id);
	}

	# Add result data
	if ($summary == $CRDS_SUMMARY_T_SUCCESS) {
		$check_stats->[$CHECK_STATS_T_RUN_SUCCESS]++;
	} elsif ($summary == $CRDS_SUMMARY_T_EXCEPTIONS) {
		$check_stats->[$CHECK_STATS_T_RUN_EXCEPTIONS]++;
	} elsif ($summary == $CRDS_SUMMARY_T_NOT_APPLICABLE) {
		$check_stats->[$CHECK_STATS_T_RUN_NOT_APPLICABLE]++;
	} elsif ($summary == $CRDS_SUMMARY_T_FAILED_SYSINFO) {
		$check_stats->[$CHECK_STATS_T_RUN_FAILED_SYSINFO]++;
	} elsif ($summary == $CRDS_SUMMARY_T_FAILED_CHKPROG) {
		$check_stats->[$CHECK_STATS_T_RUN_FAILED_CHKPROG]++;
	} elsif ($summary == $CRDS_SUMMARY_T_PARAM_ERROR) {
		$check_stats->[$CHECK_STATS_T_RUN_PARAM_ERROR]++;
	}
	$check_stats->[$CHECK_STATS_T_RUN_TOTAL]++;

	# Add exception results
	foreach $ex (@$exs) {
		my $severity = $ex->[$CRDS_EX_T_SEVERITY];

		if ($severity == $SEVERITY_T_LOW) {
			$check_stats->[$CHECK_STATS_T_EX_LOW]++;
		} elsif ($severity == $SEVERITY_T_MEDIUM) {
			$check_stats->[$CHECK_STATS_T_EX_MEDIUM]++;
		} elsif ($severity == $SEVERITY_T_HIGH) {
			$check_stats->[$CHECK_STATS_T_EX_HIGH]++;
		}
		$check_stats->[$CHECK_STATS_T_EX_TOTAL]++;
	}

	# Add run-time results if check program was actually run
	if ($summary == $CRDS_SUMMARY_T_SUCCESS ||
	    $summary == $CRDS_SUMMARY_T_EXCEPTIONS) {
		my $time_min;
		my $time_max;
		my $time_avg;
		my $time;
		my $num_runs;

		$time_min = $check_stats->[$CHECK_STATS_T_TIME_MIN];
		$time_max = $check_stats->[$CHECK_STATS_T_TIME_MAX];
		$time_avg = $check_stats->[$CHECK_STATS_T_TIME_AVG];
		$time = $end - $start;
		# Min time
		if ($time_min == 0 || $time < $time_min) {
			$check_stats->[$CHECK_STATS_T_TIME_MIN] = $time;
		}
		# Max time
		if ($time_max == 0 || $time > $time_max) {
			$check_stats->[$CHECK_STATS_T_TIME_MAX] = $time;
		}
		# Average time
		$num_runs = $check_stats->[$CHECK_STATS_T_RUN_SUCCESS] +
			    $check_stats->[$CHECK_STATS_T_RUN_EXCEPTIONS];
		$time_avg = ($time_avg * ($num_runs - 1) + $time) / $num_runs;
		$check_stats->[$CHECK_STATS_T_TIME_AVG] = $time_avg;
	}

	# Set write marker
	$_write_stats = 1;
}


#
# Code entry
#

# Ensure that statistics are written at program termination
END {
	if ($_write_stats) {
		_write_stats();
		$_write_stats = undef;
	}
};

# Indicate successful module initialization
1;
