#
# LNXHC::ConsRun.pm
#   Linux Health Checker support functions for running result consumers
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

package LNXHC::ConsRun;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catfile);
use Cwd qw(getcwd);


#
# Local imports
#
use LNXHC::Config qw(config_cons_get_active_ids
		     config_cons_get_param_or_default);
use LNXHC::Consts qw($COLUMNS $CONS_EVENT_T_EX $CONS_FMT_T_XML $CONS_FREQ_T_BOTH
		     $CONS_FREQ_T_FOREACH $CONS_FREQ_T_ONCE $CONS_PROG_FILENAME
		     $CONS_T_DIR $CONS_T_EVENT $CONS_T_FORMAT $CONS_T_FREQ
		     $CONS_T_ID $CONS_T_PARAM_DB $CRDS_RUN_T_EXCEPTIONS
		     $CRDS_RUN_T_PROG_ERR $CRDS_RUN_T_PROG_INFO
		     $CRDS_RUN_T_RUN_ID $CRDS_RUN_T_RUN_ID_MAX
		     $CRDS_T_NUM_EX_REPORTED $CRDS_T_NUM_HOSTS $CRDS_T_NUM_INSTS
		     $CRDS_T_NUM_RUNS_SCHEDULED $CRDS_T_RUNS $RC_T_OK);
use LNXHC::DBCons qw(db_cons_get);
use LNXHC::Misc qw($opt_debug $opt_verbose create_temp_file debug run_cmd
		   xml_encode_data xml_encode_predeclared term_use_color);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&cons_run_single &cons_run_summary);


#
# Constants
#

# Offset in files data for program info output
my $_FILES_T_PROG_INFO		= 0;
# Offset in files data for program error output
my $_FILES_T_PROG_ERR		= 1;


#
# Global variables
#


#
# Sub-routines
#

#
# _add_run_env(env, run, files)
#
# Add environment variables containing check run data to ENV. FILES lists the
# files written for this run.
#
sub _add_run_env($$$)
{
	my ($env, $run, $files) = @_;
	my ($run_id, $run_id_max, $check_id, $inst_ids, $host_ids, $source, $rc,
	    $deps, $multihost, $multitime, $start, $end, $prog_exit_code,
	    $prog_info, $prog_err, $inactive_ex_ids, $exs) = @$run;
	my $prog_info_file = $files->[$_FILES_T_PROG_INFO];
	my $prog_err_file = $files->[$_FILES_T_PROG_ERR];
	my $prefix;
	my $inst_num;
	my $inst_id;
	my $host_num;
	my $host_id;
	my $ex_num;
	my $ex_id;
	my $ex;

	# Determine environment variable prefix
	$prefix = "LNXHC_RUN_".$run_id."_";

	# Basic run data
	$env->{$prefix."CHECK_ID"} = $check_id;

	# List of instance IDs
	$env->{$prefix."NUM_INSTS"} = scalar(@$inst_ids);
	$inst_num = 0;
	foreach $inst_id (@$inst_ids) {
		$env->{$prefix."INST_".$inst_num."_ID"} = $inst_id;
		$inst_num++;
	}

	# List of host IDs
	$env->{$prefix."NUM_HOSTS"} = scalar(@$host_ids);
	$host_num = 0;
	foreach $host_id (@$host_ids) {
		$env->{$prefix."HOST_".$host_num."_ID"} = $host_id;
		$host_num++;
	}

	# Per instance and host combination data
	for ($inst_num = 0; $inst_num < scalar(@$inst_ids); $inst_num++) {
		for ($host_num = 0; $host_num < scalar(@$host_ids);
		    $host_num++) {
			my $dep_list = $deps->[$inst_num]->[$host_num];
			my $dep;
			my $dep_num;
			my $subprefix = $prefix."INST_".$inst_num."_HOST_".
					$host_num."_";
			my $valid = $source->[$inst_num]->[$host_num];

			# Source combination validity flag
			$env->{$subprefix."SOURCE"} = $valid ? 1 : 0;
			next if (!$valid);

			# Dependency results
			if (!defined($dep_list)) {
				$dep_list = [];
			}
			$env->{$subprefix."NUM_DEPS"} =	scalar(@$dep_list);
			$dep_num = 0;
			foreach $dep (@$dep_list) {
				my ($statement, $result) = @$dep;

				$env->{$subprefix."DEP_".$dep_num.
				       "_STATEMENT"} = $statement;
				$env->{$subprefix."DEP_".$dep_num.
				       "_RESULT"} = ($result == $RC_T_OK ?
						     1 : 0);
				$dep_num++;
			}
		}
	}

	$env->{$prefix."RC"} = $rc;
	$env->{$prefix."MULTIHOST"} = $multihost;
	$env->{$prefix."MULTITIME"} = $multitime;

	# Run-time data
	if (defined($start)) {
		$env->{$prefix."START_TIME"} = $start;
		$env->{$prefix."END_TIME"} = $end;
	}
	if (defined($prog_exit_code)) {
		$env->{$prefix."PROG_EXIT_CODE"} = $prog_exit_code;
	}
	if (defined($prog_info_file)) {
		$env->{$prefix."PROG_INFO"} = $prog_info_file;
	}
	if (defined($prog_err_file)) {
		$env->{$prefix."PROG_ERR"} = $prog_err_file;
	}

	# Inactive exception data
	$env->{$prefix."NUM_INACTIVE_EX_IDS"} = scalar(@$inactive_ex_ids);
	$ex_num = 0;
	foreach $ex_id (@$inactive_ex_ids) {
		$env->{$prefix."INACTIVE_EX_".$ex_num."_ID"} = $ex_id;
		$ex_num++;
	}

	# Exception data
	$env->{$prefix."NUM_EXCEPTIONS"} = scalar(@$exs);
	$ex_num = 0;
	foreach $ex (@$exs) {
		my ($ex_id, $severity, $summary, $explanation, $solution,
		    $reference) = @$ex;
		my $subprefix = $prefix."EX_".$ex_num."_";

		$env->{$subprefix."ID"} = $ex_id;
		$env->{$subprefix."SEVERITY"} = $severity;
		$env->{$subprefix."SUMMARY"} = $summary;
		$env->{$subprefix."EXPLANATION"} = $explanation;
		$env->{$subprefix."SOLUTION"} = $solution;
		$env->{$subprefix."REFERENCE"} = $reference;
		$ex_num++;
	}
}

#
# _add_cons_env(env, cons, num_insts, num_hosts)
#
# Add basic consumer environment variables to ENV.
#
sub _add_cons_env($$$$$$)
{
	my ($env, $cons, $num_insts, $num_hosts, $run_id, $run_id_max) = @_;
	my $dir = $cons->[$CONS_T_DIR];
	my $cons_id = $cons->[$CONS_T_ID];
	my $param_db = $cons->[$CONS_T_PARAM_DB];
	my $param_id;

	# Number of columns
	$env->{"COLUMNS"}		= $COLUMNS;
	# Color usage flag
	$env->{"LNXHC_USE_COLOR"}	= term_use_color();
	# Tool library directory
	$env->{"LNXHC_LIBDIR"}		= $main::lib_dir;
	# Tool invocation
	$env->{"LNXHC_INVOCATION"}	= $main::tool_inv;
	# Consumer name
	$env->{"LNXHC_CONS_ID"}		= $cons_id;
	# Consumer directory
	$env->{"LNXHC_CONS_DIR"}	= $dir;
	# Debugging level
	$env->{"LNXHC_DEBUG"}		= $opt_debug;
	# Verbosity level
	$env->{"LNXHC_VERBOSE"}		= $opt_verbose;
	# Total number of instances used in input data
	$env->{"LNXHC_NUM_INSTS"}	= $num_insts;
	# Total number of hosts used in input data
	$env->{"LNXHC_NUM_HOSTS"}	= $num_hosts;
	if (defined($run_id)) {
		# Sequence number of this run
		$env->{"LNXHC_RUN_ID"}	= $run_id;
	}
	# Sequence number of the final run
	$env->{"LNXHC_RUN_ID_MAX"}	= $run_id_max;
	# Consumer parameters
	foreach $param_id (keys(%{$param_db})) {
		my $value;

		# Get parameter from profile
		$value = config_cons_get_param_or_default($cons_id, $param_id);
		$env->{"LNXHC_PARAM_$param_id"} = $value;
	}
}

#
# _get_run_xml(run)
#
# Return XML representation of RUN.
#
sub _get_run_xml($)
{
	my ($run) = @_;
	my ($run_id, $run_id_max, $check_id, $inst_ids, $host_ids, $source, $rc,
	    $deps, $multihost, $multitime, $start, $end, $prog_exit_code,
	    $prog_info, $prog_err, $inactive_ex_ids, $exs) = @$run;
	my $inst_num;
	my $ex;
	my $ex_id;
	my $xml;

	# Prolog
	$run_id		= xml_encode_predeclared($run_id);
	$run_id_max	= xml_encode_predeclared($run_id_max);
	$check_id	= xml_encode_predeclared($check_id);
	$xml = <<EOF;
  <run id="$run_id" max_id="$run_id_max">
    <check_id>$check_id</check_id>

EOF

	# Instance + host related data
	for ($inst_num = 0; $inst_num < scalar(@$inst_ids); $inst_num++) {
		my $inst_id = $inst_ids->[$inst_num];
		my $host_num;

		# Data for this instance
		$inst_id = xml_encode_predeclared($inst_id);
		$xml .= <<EOF;
    <instance id="$inst_id">
EOF
		for ($host_num = 0; $host_num < scalar(@$host_ids);
		     $host_num++) {
			my $host_id = $host_ids->[$host_num];
			my $dep_list = $deps->[$inst_num]->[$host_num];
			my $dep;

			if (!$source->[$inst_num]->[$host_num]) {
				next;
			}
			# Data for this host
			$host_id = xml_encode_predeclared($host_id),
			$xml .= <<EOF;
      <host id="$host_id">
EOF

			# Dependency results for this host
			foreach $dep (@$dep_list) {
				my ($statement, $result) = @$dep;

				$statement = xml_encode_predeclared(
						$statement);
				$result = $result ? "true" : "false";
				$xml .= <<EOF;
        <dep result="$result">$statement</dep>
EOF
			}
			$xml .= <<EOF;
      </host>
EOF
		}
		$xml .= <<EOF;
    </instance>

EOF
	}

	$rc		= xml_encode_predeclared($rc);
	$multihost	= xml_encode_predeclared($multihost);
	$multitime	= xml_encode_predeclared($multitime);
	$xml .= <<EOF;
    <rc>$rc</rc>

    <multihost>$multihost</multihost>
    <multitime>$multitime</multitime>

EOF

	# Check program run-time data
	if (defined($start)) {
		$start = xml_encode_predeclared($start);
		$end = xml_encode_predeclared($end);

		$xml .= <<EOF;
    <start_time>$start</start_time>
    <end_time>$end</end_time>

EOF
	}

	# Check program result data
	if (defined($prog_exit_code)) {
		$prog_exit_code = xml_encode_predeclared($prog_exit_code);
		$xml .= <<EOF;
    <prog_exit_code>$prog_exit_code</prog_exit_code>
EOF
	}
	if (defined($prog_info)) {
		my $encoding;

		($encoding, $prog_info) = xml_encode_data($prog_info);
		$xml .= <<EOF;
    <prog_info encoding="$encoding">$prog_info</prog_info>
EOF
	}
	if (defined($prog_err)) {
		my $encoding;

		($encoding, $prog_err) = xml_encode_data($prog_err);
		$xml .= <<EOF;
    <prog_err encoding="$encoding">$prog_err</prog_err>
EOF
	}

	# Exception data
	foreach $ex_id (@$inactive_ex_ids) {
		$ex_id = xml_encode_predeclared($ex_id);
		$xml .= <<EOF;
    <inactive_ex_id>$ex_id</inactive_ex_id>
EOF
	}

	foreach $ex (@$exs) {
		my ($ex_id, $severity, $summary, $explanation, $solution,
		    $reference) = @$ex;

		$ex_id = xml_encode_predeclared($ex_id);
		$severity = xml_encode_predeclared($severity);
		$summary = xml_encode_predeclared($summary);
		$explanation = xml_encode_predeclared($explanation);
		$solution = xml_encode_predeclared($solution);
		$reference = xml_encode_predeclared($reference);
		$xml .= <<EOF
    <exception id="$ex_id">
      <severity>$severity</severity>
      <summary>$summary</summary>
      <explanation>$explanation</explanation>
      <solution>$solution</solution>
      <reference>$reference</reference>
    </exception>

EOF
	}

	$xml .= <<EOF;
  </run>
EOF

	return $xml;
}

#
# _get_result_xml(run)
#
# Return single-run-type XML consumer input.
#
sub _get_result_xml($)
{
	my ($run) = @_;
	my $xml;

	# Prolog
	$xml = <<EOF;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE result SYSTEM "$main::lib_dir/result.dtd">

<result version="1">
EOF

	# Add run data
	$xml .= _get_run_xml($run);

	# Epilog
	$xml .= <<EOF;
</result>
EOF

	return $xml;
}

#
# _get_summary_xml(crds)
#
# Return an XML representation of the check run summary data in CRDS.
#
sub _get_summary_xml($)
{
	my ($crds) = @_;
	my ($start, $end, $num_insts, $num_hosts, $num_runs_scheduled,
	    $num_runs_success, $num_runs_exceptions, $num_runs_not_applicable,
	    $num_runs_failed_sysinfo, $num_runs_failed_chkprog,
	    $num_runs_param_error, $num_ex_reported, $num_ex_low,
	    $num_ex_medium, $num_ex_high, $num_ex_inactive, $runs) = @$crds;
	my $xml;

	$start = xml_encode_predeclared($start);
	$end = xml_encode_predeclared($end);
	$num_runs_scheduled = xml_encode_predeclared($num_runs_scheduled);
	$num_runs_success = xml_encode_predeclared($num_runs_success);
	$num_runs_exceptions = xml_encode_predeclared($num_runs_exceptions);
	$num_runs_not_applicable =
		xml_encode_predeclared($num_runs_not_applicable);
	$num_runs_failed_sysinfo =
		xml_encode_predeclared($num_runs_failed_sysinfo);
	$num_runs_failed_chkprog =
		xml_encode_predeclared($num_runs_failed_chkprog);
	$num_runs_param_error =
		xml_encode_predeclared($num_runs_param_error);
	$num_ex_reported = xml_encode_predeclared($num_ex_reported);
	$num_ex_low = xml_encode_predeclared($num_ex_low);
	$num_ex_medium = xml_encode_predeclared($num_ex_medium);
	$num_ex_high = xml_encode_predeclared($num_ex_high);
	$num_ex_inactive = xml_encode_predeclared($num_ex_inactive);

	$xml = <<EOF;
  <stats>
    <start_time>$start</start_time>
    <end_time>$end</end_time>

    <num_runs_scheduled>$num_runs_scheduled</num_runs_scheduled>
    <num_runs_success>$num_runs_success</num_runs_success>
    <num_runs_exceptions>$num_runs_exceptions</num_runs_exceptions>
    <num_runs_not_applicable>$num_runs_not_applicable</num_runs_not_applicable>
    <num_runs_failed_sysinfo>$num_runs_failed_sysinfo</num_runs_failed_sysinfo>
    <num_runs_failed_chkprog>$num_runs_failed_chkprog</num_runs_failed_chkprog>
    <num_runs_param_error>$num_runs_param_error</num_runs_param_error>

    <num_ex_reported>$num_ex_reported</num_ex_reported>
    <num_ex_low>$num_ex_low</num_ex_low>
    <num_ex_medium>$num_ex_medium</num_ex_medium>
    <num_ex_high>$num_ex_high</num_ex_high>

    <num_ex_inactive>$num_ex_inactive</num_ex_inactive>
  </stats>
EOF

	return $xml;
}

#
# _get_crds_xml(crds, ex_only)
#
# Return summary-type XML consumer input.
#
sub _get_crds_xml($$)
{
	my ($crds, $ex_only) = @_;
	my $xml;
	my $runs = $crds->[$CRDS_T_RUNS];
	my $run;

	# Prolog
	$xml = <<EOF;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE result SYSTEM "$main::lib_dir/result.dtd">

<result version="1">
EOF

	# Add summary data
	$xml .= _get_summary_xml($crds);

	# Add run data for each run
	foreach $run (@$runs) {
		if ($ex_only && !@{$run->[$CRDS_RUN_T_EXCEPTIONS]}) {
			next;
		}
		$xml .= "\n";
		$xml .= _get_run_xml($run);
	}

	# Epilog
	$xml .= <<EOF;
</result>
EOF

	return $xml;
}

#
# _write_run_files(run)
#
# Write check program output data found in RUN to files.
#
sub _write_run_files($)
{
	my ($run) = @_;
	my $prog_info = $run->[$CRDS_RUN_T_PROG_INFO];
	my $prog_err = $run->[$CRDS_RUN_T_PROG_ERR];
	my $prog_info_file;
	my $prog_err_file;

	if (defined($prog_info) && $prog_info ne "") {
		$prog_info_file = create_temp_file($prog_info);
	}
	if (defined($prog_err) && $prog_err ne "") {
		$prog_err_file = create_temp_file($prog_err);
	}

	return [ $prog_info_file, $prog_err_file ];
}

#
# _delete_run_files(run_files)
#
# Remove all files referenced in RUN_FILES.
#
sub _delete_run_files($)
{
	my ($run_files) = @_;
	my $prog_info_file = $run_files->[$_FILES_T_PROG_INFO];
	my $prog_err_file = $run_files->[$_FILES_T_PROG_ERR];

	if (defined($prog_info_file)) {
		unlink($prog_info_file) or
			warn("Could not remove temporary file ".
			     "'$prog_info_file': $!\n");
	}
	if (defined($prog_err_file)) {
		unlink($prog_err_file) or
			warn("Could not remove temporary file ".
			     "'$prog_err_file': $!\n");
	}
}

#
# cons_run_single(run, num_insts, num_hosts)
#
# Call consumers with results for a single check run.
#
sub cons_run_single($$$)
{
	my ($run, $num_insts, $num_hosts) = @_;
	my $num_ex = scalar(@{$run->[$CRDS_RUN_T_EXCEPTIONS]});
	my $run_id = $run->[$CRDS_RUN_T_RUN_ID];
	my $run_id_max = $run->[$CRDS_RUN_T_RUN_ID_MAX];
	my $cons_id;
	my $run_files;
	my $old_dir = getcwd();

	# Call all active consumers
	foreach $cons_id (config_cons_get_active_ids()) {
		my $cons = db_cons_get($cons_id);
		my $format = $cons->[$CONS_T_FORMAT];
		my $freq = $cons->[$CONS_T_FREQ];
		my $event = $cons->[$CONS_T_EVENT];
		my $dir = $cons->[$CONS_T_DIR];
		my %env;
		my $input;
		my $err_msg;
		my $exit_code;
		my $run_files;

		# Check consumer frequency
		if (!(($freq == $CONS_FREQ_T_FOREACH) ||
		      ($freq == $CONS_FREQ_T_BOTH))) {
			next;
		}
		# Check consumer event type
		if ($event == $CONS_EVENT_T_EX && $num_ex == 0) {
			next;
		}

		# Initialize per consumer environment
		_add_cons_env(\%env, $cons, $num_insts, $num_hosts, $run_id,
			      $run_id_max);

		if ($format == $CONS_FMT_T_XML) {
			$input = _get_result_xml($run);
		} else {
			# Initialize per check result environment
			if (!defined($run_files)) {
				$run_files = _write_run_files($run);
			}
			_add_run_env(\%env, $run, $run_files);
		}

		debug("Running consumer '$cons_id'\n");
		chdir($dir)
			or die("could not change to directory '$dir': $!\n");

		# Run consumer program
		($err_msg, $exit_code) =
			run_cmd(catfile($dir, $CONS_PROG_FILENAME), undef,
					undef, $input, \%env, 1);

		chdir($old_dir);

		if (defined($err_msg)) {
			warn("could not run consumer '$cons_id': $err_msg\n");
		} elsif ($exit_code != 0) {
			warn("consumer '$cons_id' returned with non-zero exit ".
			     "code $exit_code\n");
		}
	}

	# Delete data files if necessary
	if (defined($run_files)) {
		_delete_run_files($run_files);
	}
}

#
# _add_summary_env(env, crds)
#
# Add environment variables containing summary data to ENV.
#
sub _add_summary_env($$)
{
	my ($env, $crds) = @_;
	my ($start, $end, $num_insts, $num_hosts, $num_runs_scheduled,
	    $num_runs_success, $num_runs_exceptions, $num_runs_not_applicable,
	    $num_runs_failed_sysinfo, $num_runs_failed_chkprog,
	    $num_runs_param_error, $num_ex_reported, $num_ex_low,
	    $num_ex_medium, $num_ex_high, $num_ex_inactive, $runs) = @$crds;
	my $prefix = "LNXHC_STATS_";

	$env->{$prefix."START_TIME"} = $start;
	$env->{$prefix."END_TIME"} = $end;

	$env->{$prefix."NUM_RUNS_SCHEDULED"} = $num_runs_scheduled;
	$env->{$prefix."NUM_RUNS_SUCCESS"} = $num_runs_success;
	$env->{$prefix."NUM_RUNS_EXCEPTIONS"} = $num_runs_exceptions;
	$env->{$prefix."NUM_RUNS_NOT_APPLICABLE"} = $num_runs_not_applicable;
	$env->{$prefix."NUM_RUNS_FAILED_SYSINFO"} = $num_runs_failed_sysinfo;
	$env->{$prefix."NUM_RUNS_FAILED_CHKPROG"} = $num_runs_failed_chkprog;
	$env->{$prefix."NUM_RUNS_PARAM_ERROR"} = $num_runs_param_error;

	$env->{$prefix."NUM_EX_REPORTED"} = $num_ex_reported;
	$env->{$prefix."NUM_EX_LOW"} = $num_ex_low;
	$env->{$prefix."NUM_EX_MEDIUM"} = $num_ex_medium;
	$env->{$prefix."NUM_EX_HIGH"} = $num_ex_high;

	$env->{$prefix."NUM_EX_INACTIVE"} = $num_ex_inactive;
}

#
# _write_crds_files(crds, crds_files, ex_only)
#
# Write all check program output data found in CRDS to files. If CRDS_FILES
# is already defined, add result to that. If EX_ONLY is non-zero, only write
# files for runs which produced exceptions.
#
sub _write_crds_files($$$)
{
	my ($crds, $crds_files, $ex_only) = @_;
	my $runs = $crds->[$CRDS_T_RUNS];

	$crds_files = {} if (!defined($crds_files));

	foreach my $run (@$runs) {
		my $run_id = $run->[$CRDS_RUN_T_RUN_ID];
		my $prog_info = $run->[$CRDS_RUN_T_PROG_INFO];
		my $prog_err = $run->[$CRDS_RUN_T_PROG_ERR];
		my $run_files = $crds_files->{$run_id};
		my $prog_info_file;
		my $prog_err_file;

		next if (defined($run_files));
		next if ($ex_only && !@{$run->[$CRDS_RUN_T_EXCEPTIONS]});

		if (defined($prog_info) && $prog_info ne "") {
			$prog_info_file = create_temp_file($prog_info);
		}
		if (defined($prog_err) && $prog_err ne "") {
			$prog_err_file = create_temp_file($prog_err);
		}
		$crds_files->{$run_id} = [ $prog_info_file, $prog_err_file ];
	}

	return $crds_files;
}

#
# _delete_crds_files(crds_files)
#
# Remove all files referenced in CRDS_FILES.
#
sub _delete_crds_files($)
{
	my ($crds_files) = @_;

	foreach my $run_id (keys(%{$crds_files})) {
		my $run_files = $crds_files->{$run_id};
		my $prog_info_file = $run_files->[$_FILES_T_PROG_INFO];
		my $prog_err_file = $run_files->[$_FILES_T_PROG_ERR];

		if (defined($prog_info_file)) {
			unlink($prog_info_file) or
				warn("Could not remove temporary file ".
				     "'$prog_info_file': $!\n");
		}
		if (defined($prog_err_file)) {
			unlink($prog_err_file) or
				warn("Could not remove temporary file ".
				     "'$prog_err_file': $!\n");
		}
	}
}

#
# _add_crds_env(env, crds, crds_files, ex_only)
#
# Add check result data CRDS to environment ENV. CRDS_FILES contains a mapping
# run_id -> [ info_file, err_file ] if there is info or error data for
# this run.
#
sub _add_crds_env($$$$)
{
	my ($env, $crds, $crds_files, $ex_only) = @_;
	my $runs = $crds->[$CRDS_T_RUNS];
	my $run;

	_add_summary_env($env, $crds);

	# Add run data for each run
	foreach $run (@$runs) {
		my $run_files;

		if ($ex_only && !@{$run->[$CRDS_RUN_T_EXCEPTIONS]}) {
			next;
		}
		$run_files = $crds_files->{$run->[$CRDS_RUN_T_RUN_ID]};
		_add_run_env($env, $run, $run_files);
	}
}

#
# cons_run_summary(crds)
#
# Run consumers which registered for being called after all checks were
# run.
#
sub cons_run_summary($)
{
	my ($crds) = @_;
	my $num_insts = $crds->[$CRDS_T_NUM_INSTS];
	my $num_hosts = $crds->[$CRDS_T_NUM_HOSTS];
	my $run_id_max = $crds->[$CRDS_T_NUM_RUNS_SCHEDULED] - 1;
	my $cons_id;
	my $all_env;
	my $ex_env;
	my $crds_files;
	my $old_dir = getcwd();

	# Call all active consumers
	foreach $cons_id (config_cons_get_active_ids()) {
		my $cons = db_cons_get($cons_id);
		my $format = $cons->[$CONS_T_FORMAT];
		my $freq = $cons->[$CONS_T_FREQ];
		my $event = $cons->[$CONS_T_EVENT];
		my $dir = $cons->[$CONS_T_DIR];
		my $ex_only = ($event == $CONS_EVENT_T_EX);
		my $env;
		my $input;
		my $err_msg;
		my $exit_code;

		if (!(($freq == $CONS_FREQ_T_ONCE) ||
		      ($freq == $CONS_FREQ_T_BOTH))) {
			# This consumer doesn't want to be called with
			# summary data
			next;
		}

		if ($ex_only && $crds->[$CRDS_T_NUM_EX_REPORTED] == 0) {
			# This consumer only wants to be called for exceptions
			next;
		}

		# Set up environment variables
		if ($format == $CONS_FMT_T_XML) {
			$input = _get_crds_xml($crds, $ex_only);
			$env = ();
		} elsif ($ex_only) {
			if (!defined($ex_env)) {
				# Lazy initialization
				$crds_files = _write_crds_files($crds,
								$crds_files, 1);
				$ex_env = {};
				_add_crds_env($ex_env, $crds, $crds_files, 1);
			}
			$env = $ex_env;
		} else {
			if (!defined($all_env)) {
				# Lazy initialization
				$crds_files = _write_crds_files($crds,
								$crds_files, 0);
				$all_env = {};
				_add_crds_env($all_env, $crds, $crds_files, 0);
			}
			$env = $all_env;
		}
		_add_cons_env($env, $cons, $num_insts, $num_hosts, undef,
			      $run_id_max);

		debug("Running consumer '$cons_id'\n");
		chdir($dir)
			or die("could not change to directory '$dir': $!\n");

		# Run consumer program
		($err_msg, $exit_code) =
			run_cmd(catfile($dir, $CONS_PROG_FILENAME), undef,
					undef, $input, $env, 1);

		chdir($old_dir);

		if (defined($err_msg)) {
			warn("could not run consumer '$cons_id': $err_msg\n");
		} elsif ($exit_code != 0) {
			warn("consumer '$cons_id' returned with non-zero exit ".
			     "code $exit_code\n");
		}
	}

	# Delete data files if necessary
	if (defined($crds_files)) {
		_delete_crds_files($crds_files);
	}
}


#
# Code entry
#

# Indicate successful module initialization
1;
