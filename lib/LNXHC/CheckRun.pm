#
# LNXHC::CheckRun.pm
#   Linux Health Checker support functions for running health checks
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

package LNXHC::CheckRun;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catfile);
use Cwd qw(getcwd);


#
# Local imports
#
use LNXHC::Check qw(check_get_data_id check_get_selected_ids
		    check_selection_is_active);
use LNXHC::Config qw(config_check_get_active_ids
		     config_check_get_ex_severity_or_default
		     config_check_get_ex_state_or_default
		     config_check_get_param_or_default
		     config_cons_get_active_ids);
use LNXHC::ConsRun qw(cons_run_single cons_run_summary);
use LNXHC::Consts qw($CHECK_PROG_FAILED_DEP_CODE $CHECK_PROG_FILENAME
		     $CHECK_T_DEPS $CHECK_T_DIR $CHECK_T_EX_DB $CHECK_T_ID
		     $CHECK_T_MULTIHOST $CHECK_T_MULTITIME $CHECK_T_PARAM_DB
		     $CHECK_T_SI_DB $COLUMNS $CRDS_EX_T_SEVERITY
		     $CRDS_RUN_T_EXCEPTIONS $CRDS_RUN_T_INACTIVE_EX_IDS
		     $CRDS_RUN_T_RC $CRDS_STORED_FILENAME
		     $CRDS_SUMMARY_T_EXCEPTIONS $CRDS_SUMMARY_T_FAILED_CHKPROG
		     $CRDS_SUMMARY_T_PARAM_ERROR
		     $CRDS_SUMMARY_T_FAILED_SYSINFO
		     $CRDS_SUMMARY_T_NOT_APPLICABLE $CRDS_SUMMARY_T_SUCCESS
		     $CRDS_T_NUM_HOSTS $CRDS_T_NUM_INSTS
		     $CRDS_T_NUM_RUNS_EXCEPTIONS $CRDS_T_NUM_RUNS_FAILED_CHKPROG
		     $CRDS_T_NUM_RUNS_FAILED_SYSINFO $CRDS_T_RUNS $CRDS_T_START
		     $EXCEPTION_T_EXPLANATION $EXCEPTION_T_REFERENCE
		     $EXCEPTION_T_SOLUTION $EXCEPTION_T_SUMMARY $MATCH_ID
		     $RC_T_FAILED $RC_T_OK $SEVERITY_T_HIGH $SEVERITY_T_LOW
		     $SEVERITY_T_MEDIUM $SIDS_ITEM_T_DATA $SIDS_ITEM_T_DATA_ID
		     $SIDS_ITEM_T_END_TIME $SIDS_ITEM_T_EXIT_CODE
		     $SIDS_ITEM_T_START_TIME $SIDS_T_INSTS
		     $SI_PROG_DATA_T_IGNORERC $SI_TYPE_T_PROG $STATE_T_ACTIVE
		     $SYSINFO_T_DATA $SYSINFO_T_TYPE
		     $CHECK_PROG_PARAM_ERROR_CODE
		     $CRDS_T_NUM_RUNS_PARAM_ERROR);
use LNXHC::DBCheck qw(db_check_get);
use LNXHC::DBSIDS qw(db_sids_get);
use LNXHC::Expr qw(expr_evaluate);
use LNXHC::Ini qw(ini_format_single);
use LNXHC::Misc qw($opt_debug $opt_verbose create_temp_file debug get_timestamp
		   info info2 info3 quiet_retrieve quiet_store resolve_entities
		   run_cmd timestamp_to_str unquote_nodie);
use LNXHC::Stats qw(stats_add_run);
use LNXHC::UData qw(udata_get_path);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&check_run &check_run_replay);


#
# Constants
#


#
# Global variables
#

# Last check results
my $_crds;

# Flag indicating whether check result data has been modified
my $_crds_modified;


#
# Sub-routines
#

#
# _write_crds()
#
# Write check result data.
#
sub _write_crds()
{
	my $filename = udata_get_path($CRDS_STORED_FILENAME);

	quiet_store($_crds, $filename) or
		warn("Could not write check result data file '$filename'!\n");
}

#
# _read_crds()
#
# Read check result data.
#
sub _read_crds()
{
	my $filename = udata_get_path($CRDS_STORED_FILENAME);

	if (-e $filename) {
		# Read data file
		info2("Reading check result data.\n");
		$_crds = quiet_retrieve($filename);
	}
}

#
# _resolve_ex_var(check, text, ex_var_db)
#
# Resolve exception variables found in TEXT.
#
sub _resolve_ex_var($$$)
{
	my ($check, $text, $ex_var_db) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $param_db = $check->[$CHECK_T_PARAM_DB];
	my $param_id;
	my $ex_var_id;
	my %entities;

	# Implicit parameter variables
	foreach $param_id (keys(%{$param_db})) {
		my $value = config_check_get_param_or_default($check_id,
							      $param_id);
		$entities{"param_$param_id"} = $value;
	}

	# Reported exception variables
	foreach $ex_var_id (keys(%{$ex_var_db})) {
		my $value = $ex_var_db->{$ex_var_id};

		$entities{$ex_var_id} = $value;
	}

	$text = resolve_entities($text, \%entities);

	return $text;
}

#
# _create_ex_result(check, ex_ids, ex_var_db)
#
# Create exception result. Return (inactive_ex_ids, exs)
# inactive_ex_ids: list of IDs of inactive exceptions that were identified
# exs: [ ex1, ex2, ... ]
# ex:  [ id, severity, summary, explanation, solution, reference ]
#
sub _create_ex_result($$$)
{
	my ($check, $ex_ids, $ex_var_db) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $ex_db = $check->[$CHECK_T_EX_DB];
	my @inactive_ex_ids;
	my @exs;
	my $ex_id;

	foreach $ex_id (@$ex_ids) {
		my $ex = $ex_db->{$ex_id};
		my $severity;
		my $state;
		my $summary;
		my $explanation;
		my $solution;
		my $reference;

		if (!defined($ex)) {
			warn("$check_id: Check program reported undefined ".
			     "exception '$ex_id'\n");
			next;
		}
		$state = config_check_get_ex_state_or_default($check_id,
							      $ex_id);
		if ($state != $STATE_T_ACTIVE) {
			push(@inactive_ex_ids, $ex_id);
			next;
		}
		$severity = config_check_get_ex_severity_or_default($check_id,
								    $ex_id);
		$summary	= $ex->[$EXCEPTION_T_SUMMARY];
		$summary	= _resolve_ex_var($check, $summary, $ex_var_db);
		$summary	= ini_format_single($summary);
		$explanation	= $ex->[$EXCEPTION_T_EXPLANATION];
		$explanation	= _resolve_ex_var($check, $explanation,
						  $ex_var_db);
		$solution	= $ex->[$EXCEPTION_T_SOLUTION];
		$solution	= _resolve_ex_var($check, $solution,
						  $ex_var_db);
		$reference	= $ex->[$EXCEPTION_T_REFERENCE];
		$reference	= _resolve_ex_var($check, $reference,
						  $ex_var_db);

		# Create struct crds_ex_t
		push(@exs, [ $ex_id, $severity, $summary, $explanation,
			     $solution, $reference ]);
	}

	return (\@inactive_ex_ids, \@exs);
}

#
# _read_ex_file(check_id, filename)
#
# Read and parse the contents of the exceptions file output of a check
# program. Return (ex_ids, ex_var_db).
#
# ex_ids:    [ ex_id1, ex_id2, ... ]
# ex_var_db: var_id => value
#
sub _read_ex_file($$)
{
	my ($check_id, $filename) = @_;
	my @ex_ids;
	my %ex_id_reported;
	my %ex_var_db;
	my $handle;

	open($handle, "<", $filename) or
		die("could not open '$filename': $!\n");
	while (<$handle>) {
		debug("Exception file line: '$_'\n");
		if (/^\s*($MATCH_ID)\s*$/) {
			my $ex_id = $1;

			# Intercept exception being reported multiple times
			next if (++$ex_id_reported{$ex_id} > 1);

			push(@ex_ids, $ex_id);
		} elsif (/^\s*($MATCH_ID)\s*=(.*)$/) {
			my ($var, $value) = ($1, $2);
			my $oldval = $ex_var_db{$var};
			my $newval;
			my $err;

			# Check quoting
			($err, $value) = unquote_nodie($value);
			if (defined($err)) {
				warn("$check_id: check program produced ".
				     "unrecognized exception data: $err\n");
				next;
			}

			# Add exception variable value
			if (defined($oldval)) {
				if ($oldval =~ /\n/) {
					$newval = $oldval.$value."\n";
				} else {
					$newval = $oldval."\n".$value."\n";
				}
			} else {
				$newval = $value;
			}
			$ex_var_db{$var} = $newval;
		} else {
			chomp();
			warn("$check_id: check program produced ".
			     "unrecognized exception data: '$_'\n");
		}
	}
	close($handle);

	# Print occurrences of repeated exception reporting
	foreach my $ex_id (@ex_ids) {
		if ($ex_id_reported{$ex_id} > 1) {
			warn("$check_id: check program reported exception ".
			     "'$ex_id' multiple times\n");
		}
	}

	return (\@ex_ids, \%ex_var_db);
}

#
# _eval_deps(check, src_data)
#
# Evaluate if dependencies of CHECK are fulfilled by SRC_DATA.
# Return (deps_rc, deps_result).
#
# deps_rc:     RC_T_OK or RC_T_FAILED depending on evaluation result
# deps_result: [inst_num][host_num] = deps_list
# deps_list:   [ statement, result ]
#
sub _eval_deps($$)
{
	my ($check, $src_data) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $deps = $check->[$CHECK_T_DEPS];
	my ($inst_ids, $host_ids, $data_matrix, $bool_matrix) = @$src_data;
	my $deps_result;
	my $inst_id;
	my $inst_num;
	my $deps_rc = $RC_T_OK;

	$inst_num = 0;
	foreach $inst_id (@$inst_ids) {
		my $host_id;
		my $host_num;

		$host_num = 0;
		foreach $host_id (@$host_ids) {
			my $data = $data_matrix->{$inst_id}->{$host_id};
			my $sysvar_db;
			my $dep;
			my $dep_num;

			if (!defined($data)) {
				next;
			}

			$sysvar_db = $data->[0];
			$dep_num = 0;
			foreach $dep (@$deps) {
				my ($statement, $expr) = @$dep;
				my $rc;

				if (expr_evaluate($check_id, $expr,
						  $sysvar_db)) {
					$rc = $RC_T_OK;
				} else {
					$rc = $RC_T_FAILED;
					$deps_rc = $RC_T_FAILED;
				}
				$deps_result->[$inst_num]->[$host_num]->
					      [$dep_num] = [ $statement, $rc ];
				$dep_num++;
			}
			$host_num++;
		}
		$inst_num++;
	}

	return ($deps_rc, $deps_result);
}

#
# _get_ignorerc(si)
#
# Return non-zero if the specified sysinfo item SI indicates that the check
# should run, even if the exit code of a sysinfo item was non-zero.
#
sub _get_ignorerc($)
{
	my ($si) = @_;
	my $type = $si->[$SYSINFO_T_TYPE];
	my $data = $si->[$SYSINFO_T_DATA];

	if ($type == $SI_TYPE_T_PROG) {
		return $data->[$SI_PROG_DATA_T_IGNORERC];
	}

	return 0;
}

#
# _prepare_sysinfo(check, src_data)
#
# Write all sysinfo data files of SRC_DATA. Return (si_rc, si_datas).
# si_rc:    RC_T_OK or RC_T_FAILED depending on availability of required sysinfo
# si_datas: [ si_data1, si_data2, ...]
# si_data:  [ inst_id, inst_num, host_id, host_num, si_id, filename, start,
#             end, rc ]
#
sub _prepare_sysinfo($$)
{
	my ($check, $src_data) = @_;
	my ($inst_ids, $host_ids, $data_matrix, $bool_matrix) = @$src_data;
	my $check_id = $check->[$CHECK_T_ID];
	my $si_db = $check->[$CHECK_T_SI_DB];
	my $si_id;
	my @todos;
	my $todo;
	my @si_datas;

	foreach $si_id (keys(%{$si_db})) {
		my ($err, $data_id) = check_get_data_id($check_id, $si_id, 1);
		my $inst_id;
		my $inst_num;
		my $ignorerc;

		if (defined($err)) {
			goto err;
		}
		$ignorerc = _get_ignorerc($si_db->{$si_id});
		$inst_num = 0;
		foreach $inst_id (@$inst_ids) {
			my $host_id;
			my $host_num;

			$host_num = 0;
			foreach $host_id (@$host_ids) {
				my $data = $data_matrix->{$inst_id}->{$host_id};
				my $sysvar_db;
				my $item_db;
				my $item;
				my $filename;
				my $exit_code;
				my $start;
				my $end;
				my $item_data;
				my $si_data;

				if (!defined($data)) {
					next;
				}
				($sysvar_db, $item_db) = @$data;
				$item = $item_db->{$data_id};
				if (!defined($item)) {
					info3("  Missing data for sysinfo ".
					      "item '$check_id.$si_id' for ".
					      "host '$host_id' instance ".
					      "'$inst_id'\n");
					goto err;
				}
				$exit_code = $item->[$SIDS_ITEM_T_EXIT_CODE];
				if ($exit_code != 0 && !$ignorerc) {
					info3(" Failed sysinfo item ".
					      "'$check_id.$si_id' for host ".
					      "'$host_id' instance ".
					      "'$inst_id'\n");
					goto err;
				}
				$filename = "";
				$start = $item->[$SIDS_ITEM_T_START_TIME];
				$end = $item->[$SIDS_ITEM_T_END_TIME];
				$item_data = $item->[$SIDS_ITEM_T_DATA];

				$si_data = [ $inst_id, $inst_num, $host_id,
					     $host_num, $si_id, $filename,
					     $start, $end, $exit_code ];
				push(@si_datas, $si_data);

				# Filename will be filled in later
				push(@todos, [ \$si_data->[5], $item_data ]);
				$host_num++;
			}
			$inst_num++;
		}
	}

	# Write files
	foreach $todo (@todos) {
		my ($filename, $data) = @$todo;

		$$filename = create_temp_file($data);
	}

	return ($RC_T_OK, \@si_datas);

err:
	return ($RC_T_FAILED, undef);
}

#
# _delete_sysinfo_files(si_datas)
#
# Remove all sysinfo data files specified by SI_DATAS.
#
sub _delete_sysinfo_files($)
{
	my ($si_datas) = @_;
	my $si_data;

	foreach $si_data (@$si_datas) {
		my $filename = $si_data->[5];

		unlink($filename) or
			warn("Could not delete temporary file '$filename': ".
			     "$!\n");
	}
}

#
# _set_env(env, check, src_data, si_datas, multihost, multitime)
#
# Add check program environment variables according to SRC_DATA and SI_DATA
# to ENV.
#
sub _set_env($$$$$$)
{
	my ($env, $check, $src_data, $si_datas, $multihost, $multitime) = @_;
	my ($inst_ids, $host_ids, $data_matrix, $bool_matrix) = @$src_data;
	my $check_id = $check->[$CHECK_T_ID];
	my $check_dir = $check->[$CHECK_T_DIR];
	my $param_db = $check->[$CHECK_T_PARAM_DB];
	my $param_id;
	my $si_data;

	# C Locale - set this to ensure that check programs don't need to
	# implement locale-specific parsing of locale-aware helper program
	# output.
	$env->{"LC_ALL"} = "C";
	# Number of columns
	$env->{"COLUMNS"} = $COLUMNS;
	# Tool library directory
	$env->{"LNXHC_LIBDIR"}		= $main::lib_dir;
	# Tool invocation
	$env->{"LNXHC_INVOCATION"}	= $main::tool_inv;
	# Check name
	$env->{"LNXHC_CHECK_ID"}	= $check_id;
	# Check directory
	$env->{"LNXHC_CHECK_DIR"}	= $check_dir;
	# Debugging level
	$env->{"LNXHC_DEBUG"}		= $opt_debug;
	# Verbosity level
	$env->{"LNXHC_VERBOSE"}		= $opt_verbose;

	# Parameters
	foreach $param_id (keys(%{$param_db})) {
		my $value;

		# Get parameter from profile
		$value = config_check_get_param_or_default($check_id,
							   $param_id);
		$env->{"LNXHC_PARAM_$param_id"} = $value;
	}

	# Sysinfo data
	if (!$multihost && !$multitime) {
		my $inst_id = $inst_ids->[0];
		my $host_id = $host_ids->[0];
		my $data = $data_matrix->{$inst_id}->{$host_id};
		my $sysvar_db = $data->[0];
		my $sysvar_id;

		$env->{"LNXHC_INST"} = $inst_id;
		$env->{"LNXHC_HOST"} = $host_id;

		# System variables
		foreach $sysvar_id (keys(%{$sysvar_db})) {
			my $value = $sysvar_db->{$sysvar_id};

			$env->{"LNXHC_SYS_$sysvar_id"} = $value;
		}

		# Sysinfo items
		foreach $si_data (@$si_datas) {
			my ($inst_id, $inst_num, $host_id, $host_num, $si_id,
			    $filename, $start, $end, $exit_code) = @$si_data;
			my $prefix = "LNXHC_SYSINFO_";

			$env->{$prefix."START_$si_id"} = $start;
			$env->{$prefix."END_$si_id"} = $end;
			$env->{$prefix."EXIT_CODE_$si_id"} = $exit_code;
			$env->{$prefix."$si_id"} = $filename;
		}
	} elsif ($multihost && !$multitime) {
		my $inst_id = $inst_ids->[0];
		my $host_id;
		my $host_num;

		$env->{"LNXHC_INST"} = $inst_id;
		$env->{"LNXHC_NUM_HOSTS"} = scalar(@$host_ids);

		# Per host data
		$host_num = 0;
		foreach $host_id (@$host_ids) {
			my $data = $data_matrix->{$inst_id}->{$host_id};
			my $sysvar_db = $data->[0];
			my $sysvar_id;
			my $prefix = "LNXHC_HOST_".$host_num."_";

			# Host ID
			$env->{$prefix."ID"} = $host_id;

			# System variables
			foreach $sysvar_id (keys(%{$sysvar_db})) {
				my $value = $sysvar_db->{$sysvar_id};

				$env->{$prefix."SYS_$sysvar_id"} = $value;
			}
			$host_num++;
		}

		# Per sysinfo data
		foreach $si_data (@$si_datas) {
			my ($inst_id, $inst_num, $host_id, $host_num, $si_id,
			    $filename, $start, $end, $exit_code) = @$si_data;
			my $prefix = "LNXHC_HOST_".$host_num."_SYSINFO_";

			$env->{$prefix."START_$si_id"} = $start;
			$env->{$prefix."END_$si_id"} = $end;
			$env->{$prefix."EXIT_CODE_$si_id"} = $exit_code;
			$env->{$prefix."$si_id"} = $filename;
		}
	} elsif (!$multihost && $multitime) {
		my $host_id = $host_ids->[0];
		my $inst_id;
		my $inst_num;

		$env->{"LNXHC_HOST"} = $host_id;
		$env->{"LNXHC_NUM_INSTS"} = scalar(@$inst_ids);

		# Per instance data
		$inst_num = 0;
		foreach $inst_id (@$inst_ids) {
			my $data = $data_matrix->{$inst_id}->{$host_id};
			my $sysvar_db = $data->[0];
			my $sysvar_id;
			my $prefix = "LNXHC_INST_".$inst_num."_";

			# Instance ID
			$env->{$prefix."ID"} = $inst_id;

			# System variables
			foreach $sysvar_id (keys(%{$sysvar_db})) {
				my $value = $sysvar_db->{$sysvar_id};

				$env->{$prefix."SYS_$sysvar_id"} = $value;
			}
			$inst_num++;
		}

		# Per sysinfo data
		foreach $si_data (@$si_datas) {
			my ($inst_id, $inst_num, $host_id, $host_num, $si_id,
			    $filename, $start, $end, $exit_code) = @$si_data;
			my $prefix = "LNXHC_INST_".$inst_num."_SYSINFO_";

			$env->{$prefix."START_$si_id"} = $start;
			$env->{$prefix."END_$si_id"} = $end;
			$env->{$prefix."EXIT_CODE_$si_id"} = $exit_code;
			$env->{$prefix."$si_id"} = $filename;
		}
	} else {
		my $inst_id;
		my $inst_num;
		my $host_id;
		my $host_num;

		# Instance ID list
		$env->{"LNXHC_NUM_INSTS"} = scalar(@$inst_ids);
		$inst_num = 0;
		foreach $inst_id (@$inst_ids) {
			$env->{"LNXHC_INST_".$inst_num."_ID"} = $inst_id;
			$inst_num++;
		}

		# Host ID list
		$env->{"LNXHC_NUM_HOSTS"} = scalar(@$host_ids);
		$host_num = 0;
		foreach $host_id (@$host_ids) {
			$env->{"LNXHC_HOST_".$host_num."_ID"} = $host_id;
			$host_num++;
		}

		# Per instance/host combination data
		$inst_num = 0;
		foreach $inst_id (@$inst_ids) {
			$host_num = 0;
			foreach $host_id (@$host_ids) {
				my $data = $data_matrix->{$inst_id}->{$host_id};
				my $sysvar_db;
				my $sysvar_id;
				my $prefix;

				if (!defined($data)) {
					$host_num++;
					next;
				}
				$prefix = "LNXHC_INST_".$inst_num.
					  "_HOST_".$host_num."_";
				$env->{$prefix."VALID"} = 1;
				$sysvar_db = $data->[0];
				foreach $sysvar_id (keys(%{$sysvar_db})) {
					my $value = $sysvar_db->{$sysvar_id};

					$env->{$prefix."SYS_$sysvar_id"} =
						$value;
				}
				$host_num++;
			}
			$inst_num++;
		}

		# Per sysinfo data
		foreach $si_data (@$si_datas) {
			my ($inst_id, $inst_num, $host_id, $host_num, $si_id,
			    $filename, $start, $end, $exit_code) = @$si_data;
			my $prefix = "LNXHC_INST_".$inst_num."_HOST_".
				     $host_num."_SYSINFO_";

			$env->{$prefix."START_$si_id"} = $start;
			$env->{$prefix."END_$si_id"} = $end;
			$env->{$prefix."EXIT_CODE_$si_id"} = $exit_code;
			$env->{$prefix."$si_id"} = $filename;
		}
	}
}

#
# _run_check_program(check, env)
#
# Return (rc, prog_exit_code, prog_info, prog_err, inactive_ex_ids, exs)
#
sub _run_check_program($$)
{
	my ($check, $env) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $dir = $check->[$CHECK_T_DIR];
	my $err_msg;
	my $output;
	my $rc;
	my $prog_exit_code;
	my $prog_info;
	my $prog_err;
	my $inactive_ex_ids;
	my $exs;
	my $ex_file;
	my $old_dir = getcwd();

	# Create exceptions file
	$ex_file = create_temp_file();
	$env->{"LNXHC_EXCEPTION"} = $ex_file;

	# Change working directory
	chdir($dir) or die("Could not change to directory '$dir': $!\n");

	# Run check program
	($err_msg, $prog_exit_code, $output) =
		run_cmd(catfile($dir, $CHECK_PROG_FILENAME), undef, undef,
			undef, $env);

	# Get back to old working directory
	chdir($old_dir);

	# Generate summary result
	if (defined($err_msg)) {
		# Check program could not be stated
		$rc = $CRDS_SUMMARY_T_FAILED_CHKPROG;
		$prog_err = $err_msg;
	} elsif ($prog_exit_code == $CHECK_PROG_FAILED_DEP_CODE) {
		# Check program ran but returned exit code indicating failed
		# run-time dependency
		info2("Check program reported failed run-time dependency ".
		     "(exit code $CHECK_PROG_FAILED_DEP_CODE)\n");
		$rc = $CRDS_SUMMARY_T_NOT_APPLICABLE;
		$prog_info = $output;
	} elsif ($prog_exit_code == $CHECK_PROG_PARAM_ERROR_CODE) {
		# Check program ran but returned exit code indicating an
		# invalid parameter and/or value
		info2("Check program reported a check parameter that is not ".
		      "valid (exit code $CHECK_PROG_PARAM_ERROR_CODE)\n");
		$rc = $CRDS_SUMMARY_T_PARAM_ERROR;
		$prog_info = $output;
	} elsif ($prog_exit_code != 0) {
		# Check program ran but returned exit code indicating error
		$rc = $CRDS_SUMMARY_T_FAILED_CHKPROG;
		$prog_err = $output;
	} else {
		my $ex_ids;
		my $ex_var_db;

		# Program completed successfully
		$prog_info = $output;
		($ex_ids, $ex_var_db) = _read_ex_file($check_id, $ex_file);
		($inactive_ex_ids, $exs) =
			_create_ex_result($check, $ex_ids, $ex_var_db);
		if (@$exs) {
			# Check program ran and identified exceptions
			$rc = $CRDS_SUMMARY_T_EXCEPTIONS;
		} else {
			# Check program ran without exceptions
			$rc = $CRDS_SUMMARY_T_SUCCESS;
		}
	}

	# Remove exceptions file
	unlink($ex_file);

	return ($rc, $prog_exit_code, $prog_info, $prog_err, $inactive_ex_ids,
		$exs)
}

#
# _run_check(run_data, run_id, run_id_max)
#
# Perform one check run. Return resulting struct crds_run_t
#
sub _run_check($$$)
{
	my ($run_data, $run_id, $run_id_max) = @_;
	my ($check_id, $src_data) = @$run_data;
	my ($inst_ids, $host_ids, $data_matrix, $bool_matrix) = @$src_data;
	my $check = db_check_get($check_id);
	my $run;
	my $rc;
	my $deps_result;
	my $multihost = $check->[$CHECK_T_MULTIHOST];
	my $multitime = $check->[$CHECK_T_MULTITIME];
	my $start;
	my $end;
	my $prog_exit_code;
	my $prog_info;
	my $prog_err;
	my $inactive_ex_ids;
	my $exs;
	my %env;
	my $deps_rc;
	my $si_rc;
	my $si_datas;

	# Evaluate dependencies
	($deps_rc, $deps_result) = _eval_deps($check, $src_data);
	if ($deps_rc != $RC_T_OK) {
		# Check cannot run - a dependency is not met
		$rc = $CRDS_SUMMARY_T_NOT_APPLICABLE;
		goto out;
	}
	# Check if required sysinfo items are available and write data files
	($si_rc, $si_datas) = _prepare_sysinfo($check, $src_data);
	if ($si_rc != $RC_T_OK) {
		# Check cannot run - a required system information item is
		# missing
		$rc = $CRDS_SUMMARY_T_FAILED_SYSINFO;
		goto out;
	}
	# Generate environment variables for check program
	_set_env(\%env, $check, $src_data, $si_datas, $multihost, $multitime);

	# Run program
	$start = get_timestamp();
	($rc, $prog_exit_code, $prog_info, $prog_err, $inactive_ex_ids, $exs) =
		_run_check_program($check, \%env);
	$end = get_timestamp();

	# Remove files again
	_delete_sysinfo_files($si_datas);

out:
	# Ensure default values
	if (!defined($exs)) {
		$exs = [];
	}
	if (!defined($inactive_ex_ids)) {
		$inactive_ex_ids = [];
	}
	# Create struct crds_run_t
	$run = [ $run_id, $run_id_max, $check_id, $inst_ids, $host_ids,
		 $bool_matrix, $rc, $deps_result, $multihost, $multitime,
		 $start, $end, $prog_exit_code, $prog_info, $prog_err,
		 $inactive_ex_ids, $exs ];

	return $run;
}

#
# _get_all_data()
#
# Create a two-dimensional hash which contains sids data for all combinations
# of inst_id and host_id. Also return overall list of inst_ids and host_ids.
#
# Return ( inst_ids, host_ids, data_matrix )
# data_matrix->{inst_id}->{host_id} = [ sysvar_db, item_db ]
#
sub _get_all_data()
{
	my $sids = db_sids_get();
	my $insts = $sids->[$SIDS_T_INSTS];
	my $inst;
	my @inst_ids;
	my @host_ids;
	my %known_host;
	my %data_matrix;

	foreach $inst (@$insts) {
		my ($inst_id, $hosts) = @$inst;
		my $host;

		push(@inst_ids, $inst_id);
		foreach $host (@$hosts) {
			my ($host_id, $sysvar_db, $items) = @$host;
			my %item_db;
			my $item;
			my $data;

			# Convert to hash for lower overhead access during run
			foreach $item (@$items) {
				my $data_id = $item->[$SIDS_ITEM_T_DATA_ID];

				$item_db{$data_id} = $item;
			}
			$data = [ $sysvar_db, \%item_db ];
			if (!$known_host{$host_id}) {
				# Maintain host order across instances
				push(@host_ids, $host_id);
				$known_host{$host_id} = 1;
			}
			$data_matrix{$inst_id}->{$host_id} = $data;
		}
	}

	return (\@inst_ids, \@host_ids, \%data_matrix);
}

#
# _get_ss_datas(all_inst_ids, all_host_ids, data_matrix)
#
# Calculate list of source data structures for single host+single time checks.
#
# src_datas:   [ src_data1, src_data2, ... ]
# src_data:    [ inst_ids, host_ids, data_matrix, bool_matrix ]
# inst_ids:    [ inst_id1, inst_id2, ... ]
# host_ids:    [ host_id2, host_id2, ... ]
# data_matrix: ->{inst_id}->{host_id}=[ sysvar_db, item_db ]
# bool_matrix: [inst_num][host_num]=1|0
#
sub _get_ss_datas($$$)
{
	my ($all_inst_ids, $all_host_ids, $all_data_matrix) = @_;
	my $inst_id;
	my @src_datas;

	foreach $inst_id (@$all_inst_ids) {
		my $host_id;

		foreach $host_id (@$all_host_ids) {
			my $data = $all_data_matrix->{$inst_id}->{$host_id};
			my $src_data;
			my %data_matrix;
			my @bool_matrix;

			if (!defined($data)) {
				next;
			}
			$data_matrix{$inst_id}->{$host_id} = $data;
			$bool_matrix[0][0] = 1;
			$src_data = [ [ $inst_id ], [ $host_id], \%data_matrix,
				      \@bool_matrix ];
			push(@src_datas, $src_data);
		}
	}

	return \@src_datas;
}

#
# _get_mh_datas(all_inst_ids, all_host_ids, data_matrix)
#
# Calculate list of source data structures for multi host+single time checks.
#
# src_datas:   [ src_data1, src_data2, ... ]
# src_data:    [ inst_ids, host_ids, data_matrix, bool_matrix ]
# inst_ids:    [ inst_id1, inst_id2, ... ]
# host_ids:    [ host_id2, host_id2, ... ]
# data_matrix: ->{inst_id}->{host_id}=[ sysvar_db, item_db ]
# bool_matrix: [inst_num][host_num]=1|0
#
sub _get_mh_datas($$$)
{
	my ($all_inst_ids, $all_host_ids, $all_data_matrix) = @_;
	my $inst_id;
	my @src_datas;

	foreach $inst_id (@$all_inst_ids) {
		my $host_id;
		my @host_ids;
		my %data_matrix;
		my @bool_matrix;
		my $host_num = 0;
		my $src_data;

		foreach $host_id (@$all_host_ids) {
			my $data = $all_data_matrix->{$inst_id}->{$host_id};

			if (!defined($data)) {
				next;
			}
			push(@host_ids, $host_id);
			$data_matrix{$inst_id}->{$host_id} = $data;
			$bool_matrix[0][$host_num] = 1;
			$host_num++;
		}
		$src_data = [ [ $inst_id ], \@host_ids, \%data_matrix,
			      \@bool_matrix ];
		push(@src_datas, $src_data);
	}

	return \@src_datas;
}

#
# _get_mt_datas(all_inst_ids, all_host_ids, data_matrix)
#
# Calculate list of source data structures for single host+multi time checks.
#
# src_datas:   [ src_data1, src_data2, ... ]
# src_data:    [ inst_ids, host_ids, data_matrix, bool_matrix ]
# inst_ids:    [ inst_id1, inst_id2, ... ]
# host_ids:    [ host_id2, host_id2, ... ]
# data_matrix: ->{inst_id}->{host_id}=[ sysvar_db, item_db ]
# bool_matrix: [inst_num][host_num]=1|0
#
sub _get_mt_datas($$$)
{
	my ($all_inst_ids, $all_host_ids, $all_data_matrix) = @_;
	my $host_id;
	my @src_datas;

	foreach $host_id (@$all_host_ids) {
		my $inst_id;
		my @inst_ids;
		my %data_matrix;
		my @bool_matrix;
		my $inst_num = 0;
		my $src_data;

		foreach $inst_id (@$all_inst_ids) {
			my $data = $all_data_matrix->{$inst_id}->{$host_id};

			if (!defined($data)) {
				next;
			}
			push(@inst_ids, $inst_id);
			$data_matrix{$inst_id}->{$host_id} = $data;
			$bool_matrix[$inst_num][0] = 1;
			$inst_num++;
		}
		$src_data = [ \@inst_ids, [ $host_id ], \%data_matrix,
			      \@bool_matrix ];
		push(@src_datas, $src_data);
	}

	return \@src_datas;
}

#
# _get_mm_datas(all_inst_ids, all_host_ids, data_matrix)
#
# Calculate list of source data structures for multi host+multi time checks.
#
# src_datas:   [ src_data1, src_data2, ... ]
# src_data:    [ inst_ids, host_ids, data_matrix, bool_matrix ]
# inst_ids:    [ inst_id1, inst_id2, ... ]
# host_ids:    [ host_id2, host_id2, ... ]
# data_matrix: ->{inst_id}->{host_id}=[ sysvar_db, item_db ]
# bool_matrix: [inst_num][host_num]=1|0
#
sub _get_mm_datas($$$)
{
	my ($all_inst_ids, $all_host_ids, $all_data_matrix) = @_;
	my $src_data;
	my @src_datas;
	my $inst_id;
	my $inst_num = 0;
	my @bool_matrix;

	# Derive bool_matrix from data_matrix
	foreach $inst_id (@$all_inst_ids) {
		my $host_id;
		my $host_num = 0;

		foreach $host_id (@$all_host_ids) {
			my $data = $all_data_matrix->{$inst_id}->{$host_id};

			if (defined($data)) {
				$bool_matrix[$inst_num][$host_num] = 1;
			}
			$host_num++;
		}
		$inst_num++;
	}

	# Create source data and add to list
	$src_data = [ $all_inst_ids, $all_host_ids, $all_data_matrix,
		      \@bool_matrix ];
	push(@src_datas, $src_data);

	return \@src_datas;
}

#
# _get_run_data(check_ids)
#
# Get all combinations of check IDs and source data instances.
# Return (total_insts, total_hosts, run_datas)
#
# total_insts: total number of instances
# total_hosts: total number of hosts
# run_datas:   [ run_data1, run_data2, ... ]
# run_data:    [ check_id, src_data ]
# src_data:    [ inst_ids, host_ids, data_matrix, bool_matrix ]
# inst_ids:    [ inst_id1, inst_id2, ... ]
# host_ids:    [ host_id2, host_id2, ... ]
# data_matrix: ->{inst_id}->{host_id}=[ sysvar_db, item_db ]
# bool_matrix: [inst_num][host_num]=1|0
#
sub _get_run_data($)
{
	my ($check_ids) = @_;
	my ($all_inst_ids, $all_host_ids, $all_data_matrix) = _get_all_data();
	my $ss_datas =  _get_ss_datas($all_inst_ids, $all_host_ids,
				      $all_data_matrix);
	my $mh_datas;
	my $mt_datas;
	my $mm_datas;
	my $check_id;
	my @run_sources;

	foreach $check_id (@$check_ids) {
		my $check = db_check_get($check_id);
		my $multihost = $check->[$CHECK_T_MULTIHOST];
		my $multitime = $check->[$CHECK_T_MULTITIME];
		my $datas;
		my $data;

		if (!$multihost && !$multitime) {
			# Input comes from single host at one point in time
			$datas = $ss_datas;
		} elsif ($multihost && !$multitime) {
			# Input comes from several hosts at one point in time
			if (!defined($mh_datas)) {
				# Lazy calculation
				$mh_datas = _get_mh_datas($all_inst_ids,
							  $all_host_ids,
							  $all_data_matrix);
			}
			$datas = $mh_datas;
		} elsif (!$multihost && $multitime) {
			# Input comes from single host at several points in time
			if (!defined($mt_datas)) {
				# Lazy calculation
				$mt_datas = _get_mt_datas($all_inst_ids,
							  $all_host_ids,
							  $all_data_matrix);
			}
			$datas = $mt_datas;
		} else {
			# Input comes from multiple hosts and points in time
			if (!defined($mm_datas)) {
				# Lazy calculation
				$mm_datas = _get_mm_datas($all_inst_ids,
							  $all_host_ids,
							  $all_data_matrix);
			}
			$datas = $mm_datas;
		}

		# Combine with check_id
		foreach $data (@$datas) {
			push(@run_sources, [ $check_id, $data ]);
		}
	}

	return (scalar(@$all_inst_ids), scalar(@$all_host_ids), \@run_sources);
}

#
# _run_exitcode()
#
# Return an exit code depending on the specified run results.
#
sub _run_exitcode($)
{
	my $crds = shift();
	my $exitcode = 0;

	# Set exit code for successful run with exceptions
	if ($crds->[$CRDS_T_NUM_RUNS_EXCEPTIONS]) {
		$exitcode = 1;
	}

	# Set exit code for missing or failed system information and
	# for check program run-time errors
	if ($crds->[$CRDS_T_NUM_RUNS_FAILED_SYSINFO] ||
	    $crds->[$CRDS_T_NUM_RUNS_PARAM_ERROR] ||
	    $crds->[$CRDS_T_NUM_RUNS_FAILED_CHKPROG]) {
		$exitcode = 2;
	}

	return $exitcode;
}

#
# check_run()
#
# Run all selected or active checks with data from the current sysinfo data set.
#
sub check_run()
{
	my @check_ids;
	my $num_insts;
	my $num_hosts;
	my $run_datas;
	my $run_data;
	my $num_checks_scheduled;
	my $start;
	my $end;
	my $num_runs_scheduled;
	my $num_runs_success = 0;
	my $num_runs_exceptions = 0;
	my $num_runs_not_applicable = 0;
	my $num_runs_failed_sysinfo = 0;
	my $num_runs_failed_chkprog = 0;
	my $num_runs_param_error = 0;
	my $num_ex_reported = 0;
	my $num_ex_low = 0;
	my $num_ex_medium = 0;
	my $num_ex_high = 0;
	my $num_ex_inactive = 0;
	my $run_id;
	my $run_id_max;
	my @runs;
	my $crds;

	if (check_selection_is_active()) {
		@check_ids = check_get_selected_ids();
		if (!@check_ids) {
			die("Cannot run checks: no checks selected!\n");
		}
	} else {
		@check_ids = config_check_get_active_ids();
		if (!@check_ids) {
			die("Cannot run checks: no active checks!\n");
		}
	}

	@check_ids = sort(@check_ids);

	($num_insts, $num_hosts, $run_datas) = _get_run_data(\@check_ids);
	$num_checks_scheduled = scalar(@check_ids);
	$num_runs_scheduled = scalar(@$run_datas);

	if ($num_checks_scheduled == $num_runs_scheduled) {
		info("Running checks ($num_checks_scheduled checks)\n");
	} else {
		info("Running checks ($num_checks_scheduled checks, ".
		     "$num_runs_scheduled runs)\n");
	}

	# Make sure user gets informed if no consumer is active
	if (!config_cons_get_active_ids()) {
		info("Note: there are no active consumers!\n");
		# Note: we don't return here because even without consumers
		# we're still modifying our database
	}

	# Get starting timestamp
	$start = get_timestamp();

	# Perform runs
	$run_id = 0;
	$run_id_max = $num_runs_scheduled - 1;
	foreach $run_data (@$run_datas) {
		my $run = _run_check($run_data, $run_id, $run_id_max);
		my $rc = $run->[$CRDS_RUN_T_RC];
		my $inactive_ex_ids = $run->[$CRDS_RUN_T_INACTIVE_EX_IDS];
		my $exs = $run->[$CRDS_RUN_T_EXCEPTIONS];
		my $ex;

		# Update summary statistics
		if ($rc == $CRDS_SUMMARY_T_SUCCESS) {
			$num_runs_success++;
		} elsif ($rc == $CRDS_SUMMARY_T_EXCEPTIONS) {
			$num_runs_exceptions++;
		} elsif ($rc == $CRDS_SUMMARY_T_NOT_APPLICABLE) {
			$num_runs_not_applicable++;
		} elsif ($rc == $CRDS_SUMMARY_T_FAILED_SYSINFO) {
			$num_runs_failed_sysinfo++;
		} elsif ($rc == $CRDS_SUMMARY_T_FAILED_CHKPROG) {
			$num_runs_failed_chkprog++;
		} elsif ($rc == $CRDS_SUMMARY_T_PARAM_ERROR) {
			$num_runs_param_error++
		}
		$num_ex_reported += scalar(@$exs);
		foreach $ex (@$exs) {
			my $severity = $ex->[$CRDS_EX_T_SEVERITY];

			if ($severity == $SEVERITY_T_LOW) {
				$num_ex_low++;
			} elsif ($severity == $SEVERITY_T_MEDIUM) {
				$num_ex_medium++;
			} elsif ($severity == $SEVERITY_T_HIGH) {
				$num_ex_high++;
			}
		}
		$num_ex_inactive += scalar(@$inactive_ex_ids);

		stats_add_run($run);

		# Call consumers with single check run data
		cons_run_single($run, $num_insts, $num_hosts);

		push(@runs, $run);
		$run_id++;
	}

	# Get ending timestamp
	$end = get_timestamp();

	# Create struct crds_t
	$crds = [ $start, $end, $num_insts, $num_hosts, $num_runs_scheduled,
		  $num_runs_success, $num_runs_exceptions,
		  $num_runs_not_applicable, $num_runs_failed_sysinfo,
		  $num_runs_failed_chkprog, $num_runs_param_error,
		  $num_ex_reported, $num_ex_low, $num_ex_medium, $num_ex_high,
		  $num_ex_inactive, \@runs ];

	# Call consumers with summary check run data
	cons_run_summary($crds);

	# Store for replay
	$_crds = $crds;

	# Set modified marker
	$_crds_modified = 1;

	# Create return code based on run results
	return _run_exitcode($crds);
}

#
# check_run_replay()
#
# Replay check results to consumers.
#
sub check_run_replay()
{
	my $start;
	my $runs;
	my $num_insts;
	my $num_hosts;
	my $run;

	# Lazy initialization
	_read_crds() if (!defined($_crds));

	if (!defined($_crds)) {
		die("No data available for replay\n".
		    "Use 'lnxhc run' to generate check result data\n");
	}
	$start		= $_crds->[$CRDS_T_START];
	$num_insts	= $_crds->[$CRDS_T_NUM_INSTS];
	$num_hosts	= $_crds->[$CRDS_T_NUM_HOSTS];
	$runs		= $_crds->[$CRDS_T_RUNS];

	info("Replaying check results generated on ".timestamp_to_str($start).
	     "\n");

	# Make sure user gets informed if no consumer is active
	if (!config_cons_get_active_ids()) {
		info("Note: there are no active consumers!\n");
		# There's no effect without active consumers, so we might as
		# well skip it but return an exit code
		return _run_exitcode($_crds);
	}

	foreach $run (@$runs) {
		cons_run_single($run, $num_insts, $num_hosts);
	}

	cons_run_summary($_crds);
	return _run_exitcode($_crds);
}


#
# Code entry
#

# Ensure that check result data is written at program termination
END {
	if ($_crds_modified) {
		_write_crds();
		$_crds_modified = undef;
	}
};

# Indicate successful module initialization
1;
