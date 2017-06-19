
# LNXHC::Config.pm
#   Linux Health Checker configuration functions
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

package LNXHC::Config;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#
use LNXHC::Consts qw($CHECK_CONF_T_EX_CONF_DB $CHECK_CONF_T_ID
		     $CHECK_CONF_T_PARAM_CONF_DB $CHECK_CONF_T_REPEAT
		     $CHECK_CONF_T_SI_CONF_DB $CHECK_CONF_T_STATE $CHECK_T_EX_DB
		     $CHECK_T_PARAM_DB $CHECK_T_SI_DB $CONS_CONF_T_ID
		     $CONS_CONF_T_PARAM_CONF_DB $CONS_CONF_T_STATE
		     $DEFAULT_PROFILE_DESC $EX_CONF_T_SEVERITY $EX_CONF_T_STATE
		     $PARAM_CONF_T_VALUE $PROFILE_T_CHECK_CONF_DB
		     $PROFILE_T_CONS_CONF_DB $PROFILE_T_DESC $PROFILE_T_HOSTS
		     $PROFILE_T_ID $SI_CONF_T_DATA $SI_CONF_T_TYPE
		     $SI_REC_CONF_T_DURATION $SI_TYPE_T_REC $STATE_T_ACTIVE
		     $SYSINFO_T_TYPE);
use LNXHC::DBCheck qw(db_check_exists db_check_get db_check_get_ex_severity
		      db_check_get_ex_state db_check_get_ids db_check_get_param
		      db_check_get_repeat db_check_get_si_rec_duration
		      db_check_get_state);
use LNXHC::DBCons qw(db_cons_get db_cons_get_ids db_cons_get_param
		     db_cons_get_state);
use LNXHC::DBProfile qw(db_profile_check_modify db_profile_exists db_profile_get
			db_profile_get_active_id db_profile_set_modified);
use LNXHC::Defaults qw(defaults_get_check_conf defaults_get_check_conf_db
		       defaults_get_cons_conf defaults_get_cons_conf_db);
use LNXHC::Misc qw(info);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&config_check_del &config_check_del_ex_severity
		    &config_check_del_ex_state &config_check_del_param_value
		    &config_check_del_repeat &config_check_del_si_rec_duration
		    &config_check_del_state &config_check_ex_exists
		    &config_check_exists &config_check_get_active_ids
		    &config_check_get_ex_ids &config_check_get_ex_severity
		    &config_check_get_ex_severity_or_default
		    &config_check_get_ex_state
		    &config_check_get_ex_state_or_default &config_check_get_ids
		    &config_check_get_param &config_check_get_param_ids
		    &config_check_get_param_or_default &config_check_get_repeat
		    &config_check_get_repeat_or_default &config_check_get_si_ids
		    &config_check_get_si_rec_duration
		    &config_check_get_si_rec_duration_or_default
		    &config_check_get_state &config_check_get_state_or_default
		    &config_check_param_exists &config_check_set_defaults
		    &config_check_set_ex_severity &config_check_set_ex_state
		    &config_check_set_param &config_check_set_repeat
		    &config_check_set_si_rec_duration &config_check_set_state
		    &config_check_si_exists &config_clear &config_cons_del
		    &config_cons_del_param_value &config_cons_del_state
		    &config_cons_exists &config_cons_get_active_ids
		    &config_cons_get_ids &config_cons_get_param
		    &config_cons_get_param_ids &config_cons_get_param_or_default
		    &config_cons_get_state &config_cons_get_state_or_default
		    &config_cons_param_exists &config_cons_set_defaults
		    &config_cons_set_param &config_cons_set_state
		    &config_get_desc &config_host_add &config_host_exists
		    &config_host_get_by_num &config_host_remove
		    &config_host_remove_by_num &config_host_replace_by_num
		    &config_hosts_clear &config_hosts_get &config_hosts_set
		    &config_set_defaults &config_set_desc
		    &config_specify_profile);


#
# Constants
#


#
# Global variables
#

# ID of specified profile
my $_specified_profile_id;


#
# Sub-routines
#

#
# _get_profile_id([profile_id[, check_modify]])
#
# Return ID of active profile or, if specified, profile with ID PROFILE_ID.
# If CHECK_MODIFY is non-zero, check if the profile can be modified and
# abort with an error message if it can't.
#
sub _get_profile_id(;$$)
{
	my ($profile_id, $check_modify) = @_;

	if (defined($profile_id)) {
		# Keep user-provided profile ID
	} elsif (defined($_specified_profile_id)) {
		# Use specified profile ID
		$profile_id = $_specified_profile_id;
	} else {
		# Get active profile ID
		$profile_id = db_profile_get_active_id();
	}

	if ($check_modify) {
		db_profile_check_modify($profile_id);
	}

	return $profile_id;
}

#
# _get_profile([profile_id[, check_modify]])
#
# Return active profile or, if specified, profile with ID PROFILE_ID.
# If CHECK_MODIFY is non-zero, check if the profile can be modified and
# abort with an error message if it can't.
#
sub _get_profile(;$$)
{
	my ($profile_id, $check_modify) = @_;

	return db_profile_get(_get_profile_id($profile_id, $check_modify));
}

#
# config_specify_profile(profile_id)
#
# Specify profile ID to use for sub-sequent operations.
#
sub config_specify_profile($)
{
	my ($profile_id) = @_;

	if (!db_profile_exists($profile_id)) {
		die("Profile '$profile_id' does not exist!\n");
	}
	$_specified_profile_id = $profile_id;
}

#
# config_get_desc([profile_id])
#
# Return profile description.
#
sub config_get_desc(;$)
{
	my ($profile_id) = @_;
	my $profile = _get_profile($profile_id);

	return $profile->[$PROFILE_T_DESC];
}

#
# config_set_desc(desc, [profile_id])
#
# Set profile description to DESC.
#
sub config_set_desc($;$)
{
	my ($desc, $profile_id) = @_;
	my $profile = _get_profile($profile_id, 1);

	if ($desc =~ /\n/) {
		info("Note: removing newline in description\n");
		$desc =~ s/\n/ /g;
	}

	$profile->[$PROFILE_T_DESC] = $desc;

	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_clear([profile_id])
#
# Remove configuration data from profile.
#
sub config_clear(;$)
{
	my ($profile_id) = @_;
	my $profile = _get_profile($profile_id, 1);

	$profile->[$PROFILE_T_HOSTS] = undef;
	$profile->[$PROFILE_T_CHECK_CONF_DB] = {};
	$profile->[$PROFILE_T_CONS_CONF_DB] = {};

	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_set_defaults([profile_id])
#
# Replace configuration data with default values.
#
sub config_set_defaults(;$)
{
	my ($profile_id) = @_;
	my $profile = _get_profile($profile_id, 1);

	$profile->[$PROFILE_T_DESC] = $DEFAULT_PROFILE_DESC;
	$profile->[$PROFILE_T_HOSTS] = [ ];
	$profile->[$PROFILE_T_CHECK_CONF_DB] = defaults_get_check_conf_db();
	$profile->[$PROFILE_T_CONS_CONF_DB] = defaults_get_cons_conf_db();

	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_host_exists(host_id[, profile_id])
#
# Return 1 if a host with the specified HOST_ID is already in the host list,
# zero otherwise.
#
sub config_host_exists($;$)
{
	my ($host_id, $profile_id) = @_;
	my $host_list;
	my $host;
	my $profile;

	$profile = _get_profile($profile_id);

	$host_list = $profile->[$PROFILE_T_HOSTS];
	if (!defined($host_list)) {
		return 0;
	}

	foreach $host (@$host_list) {
		if ($host eq $host_id) {
			return 1;
		}
	}

	return 0;
}

#
# config_hosts_clear([profile_id])
#
# Clear host list.
#
sub config_hosts_clear(;$)
{
	my ($profile_id) = @_;
	my $profile;

	# Get active/selected profile
	$profile = _get_profile($profile_id, 1);

	$profile->[$PROFILE_T_HOSTS] = undef;

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_hosts_set(hosts[, profile_id])
#
# Set host list. HOSTS must be an array reference.
#
sub config_hosts_set($;$)
{
	my ($hosts, $profile_id) = @_;
	my $profile;

	# Get active/selected profile
	$profile = _get_profile($profile_id, 1);

	# Set host list
	$profile->[$PROFILE_T_HOSTS] = [ @$hosts ];

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_hosts_get([profile_id])
#
# Return host list reference.
#
sub config_hosts_get(;$)
{
	my ($profile_id) = @_;
	my $profile;

	# Get active/selected profile
	$profile = _get_profile($profile_id);

	# Return host list reference
	return $profile->[$PROFILE_T_HOSTS];
}

#
# config_host_get_by_num(num, [profile_id])
#
# Return host list entry with specified NUM.
#
sub config_host_get_by_num($;$)
{
	my ($num, $profile_id) = @_;
	my $profile;
	my $hosts;

	# Get active/selected profile
	$profile = _get_profile($profile_id);

	$hosts = $profile->[$PROFILE_T_HOSTS];

	return $hosts->[$num];
}

#
# config_host_add(host[, profile_id])
#
# Add a host to the host list.
#
sub config_host_add($;$)
{
	my ($host, $profile_id) = @_;
	my $host_list;
	my $profile;

	# Get active/selected profile
	$profile = _get_profile($profile_id, 1);

	if (config_host_exists($host)) {
		die("Cannot add host '$host': already added!\n");
	}

	# Get current host list
	$host_list = $profile->[$PROFILE_T_HOSTS];
	if (!defined($host_list)) {
		# Use empty list
		$host_list = [];
		$profile->[$PROFILE_T_HOSTS] = $host_list;
	}

	# Add to host list
	push(@$host_list, $host);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_host_replace_by_num(host, num[, profile_id])
#
# Replace entry number NUM in the host list with HOST. If NUM is outside the
# range of the host list, add HOST to the end of the list instead.
#
sub config_host_replace_by_num($$$)
{
	my ($host, $num, $profile_id) = @_;
	my $hosts;
	my $profile;
	my $i;

	# Get active/selected profile
	$profile = _get_profile($profile_id, 1);

	# Get current host list
	$hosts = $profile->[$PROFILE_T_HOSTS];
	if (!defined($hosts)) {
		# Use empty list
		$hosts = [];
		$profile->[$PROFILE_T_HOSTS] = $hosts;
	}

	# Check for duplicate host IDs
	for ($i = 0; $i < scalar(@$hosts); $i++) {
		if ($i == $num) {
			next;
		}
		if ($host eq $hosts->[$i]) {
			die("Cannot add host '$host': already added!\n");
		}
	}

	if ($num >= scalar(@$hosts)) {
		# Add to end
		push(@$hosts, $host)
	} else {
		# Replace entry
		$hosts->[$num] = $host;
	}

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_host_remove(host[, profile_id])
#
# Remove a host from the host list.
#
sub config_host_remove($;$)
{
	my ($host, $profile_id) = @_;
	my $profile;
	my @new_host_list;
	my $h;

	if (!config_host_exists($host, $profile_id)) {
		die("Cannot remove host '$host': host not found!\n");
	}

	# Get active/selected profile
	$profile = _get_profile($profile_id, 1);

	# Copy all hosts which except for the specified one
	foreach $h (@{$profile->[$PROFILE_T_HOSTS]}) {
		if ($h ne $host) {
			push(@new_host_list, $h);
		}
	}

	# Set modified host list
	$profile->[$PROFILE_T_HOSTS] = \@new_host_list;

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_host_remove_by_num(num, profile_id)
#
# Remove entry number NUM in the host list.
#
sub config_host_remove_by_num($$)
{
	my ($num, $profile_id) = @_;
	my $profile;
	my $hosts;

	# Get active/selected profile
	$profile = _get_profile($profile_id, 1);
	$hosts = $profile->[$PROFILE_T_HOSTS];

	if (!defined($hosts->[$num])) {
		die("Cannot remove host entry number $num: entry not found!\n");
	}
	splice(@$hosts, $num, 1);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# _get_check_conf(check_id, create[, profile_id[, check_modify]])
#
# Return the check configuration for the specified CHECK_ID. Create an
# empty configuration if no check configuration is available and CREATE is
# non-zero. Return (profile, check_conf) on success, undef on error.
#
sub _get_check_conf($$;$$)
{
	my ($check_id, $create, $profile_id, $check_modify) = @_;
	my $profile;
	my $check_conf_db;
	my $check_conf;

	# Get active/selected profile
	$profile = _get_profile($profile_id, $check_modify);

	# Get check configuration
	$check_conf_db = $profile->[$PROFILE_T_CHECK_CONF_DB];
	$check_conf = $check_conf_db->{$check_id};

	if (!defined($check_conf)) {
		if (!$create) {
			return undef;
		}

		# Make sure check exists
		if (!db_check_exists($check_id)) {
			die("Check '$check_id' does not exist!\n");
		}
		# Add an empty data set for this check
		$check_conf = [ $check_id, undef, undef, {}, {}, {} ];
		$check_conf_db->{$check_id} = $check_conf;
	}

	return ($profile, $check_conf);
}

#
# config_check_get_ids([profile_id])
#
# Return list of check IDs for which there is configuration data available.
#
sub config_check_get_ids(;$)
{
	my ($profile_id) = @_;
	my $profile;

	# Get active/selected profile
	$profile = _get_profile($profile_id);

	return keys(%{$profile->[$PROFILE_T_CHECK_CONF_DB]});
}

#
# config_check_exists(check_id[, profile_id])
#
# Return non-zero if there is configuration data available for check CHECK_ID.
#
sub config_check_exists($;$)
{
	my ($check_id, $profile_id) = @_;
	my $check_conf;

	$check_conf = _get_check_conf($check_id, 0, $profile_id);
	if (defined($check_conf)) {
		return 1;
	}

	return 0;
}

#
# config_check_set_state(check_id, state[, profile_id])
#
# Set the activation state of check CHECK_ID in the active/selected profile to
# STATE.
#
sub config_check_set_state($$;$)
{
	my ($check_id, $state, $profile_id) = @_;
	my $check_conf;
	my $profile;

	# Get check configuration
	($profile, $check_conf) = _get_check_conf($check_id, 1, $profile_id, 1);

	# Set check state
	$check_conf->[$CHECK_CONF_T_STATE] = $state;

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_get_state(check_id[, profile_id])
#
# Return activation state for check CHECK_ID from the active/selected profile.
# Return undef if no data for check can be found.
#
sub config_check_get_state($;$)
{
	my ($check_id, $profile_id) = @_;
	my $check_conf;

	# Get check configuration
	$check_conf = _get_check_conf($check_id, 0, $profile_id);

	# No configuration for this check
	if (!defined($check_conf)) {
		return undef;
	}

	return $check_conf->[$CHECK_CONF_T_STATE];
}

#
# config_check_get_state_or_default(check_id[, profile_id])
#
# Return activation state for check CHECK_ID. Return default activation state
# if no data can be found.
#
sub config_check_get_state_or_default($;$)
{
	my ($check_id, $profile_id) = @_;
	my $state = config_check_get_state($check_id, $profile_id);

	if (!defined($state)) {
		$state = db_check_get_state($check_id);
	}

	return $state;
}

#
# config_check_set_repeat(check_id, repeat[, profile_id])
#
# Set check repeat setting.
#
sub config_check_set_repeat($$;$)
{
	my ($check_id, $repeat, $profile_id) = @_;
	my $profile;
	my $check_conf;

	# Get check configuration
	($profile, $check_conf) = _get_check_conf($check_id, 1, $profile_id, 1);

	# Set check repeat setting
	$check_conf->[$CHECK_CONF_T_REPEAT] = $repeat;

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_get_repeat(check_id[, profile_id])
#
# Get check repeat setting.
#
sub config_check_get_repeat($;$)
{
	my ($check_id, $profile_id) = @_;
	my $check_conf;

	# Get check configuration
	$check_conf = _get_check_conf($check_id, 0, $profile_id);

	# No configuration for this check
	if (!defined($check_conf)) {
		return undef;
	}

	return $check_conf->[$CHECK_CONF_T_REPEAT];
}

#
# config_check_get_repeat_or_default(check_id[, profile_id])
#
# Get check repeat setting. If no data is available, return default value.
#
sub config_check_get_repeat_or_default($;$)
{
	my ($check_id, $profile_id) = @_;
	my $repeat = config_check_get_repeat($check_id, $profile_id);

	if (!defined($repeat)) {
		$repeat = db_check_get_repeat($check_id);
	}

	return $repeat;
}

#
# _get_check_param_conf(check_id, param_id, create[, profile_id[,
#                       check_modify]])
#
# Return the parameter configuration for parameter PARAM_ID of check CHECK_ID.
# Create an empty configuration if no parameter configuration is available and
# CREATE is non-zero. Return (profile, param_conf) on success, undef or abort
# on error.
#
sub _get_check_param_conf($$$;$$)
{
	my ($check_id, $param_id, $create, $profile_id, $check_modify) = @_;
	my $check_conf;
	my $param_conf_db;
	my $param_conf;
	my $profile;

	# Get check configuration
	($profile, $check_conf) = _get_check_conf($check_id, 1, $profile_id,
						  $check_modify);

	if (!defined($check_conf)) {
		return undef;
	}

	# Get parameter configuration
	$param_conf_db = $check_conf->[$CHECK_CONF_T_PARAM_CONF_DB];
	$param_conf = $param_conf_db->{$param_id};

	if (!defined($param_conf)) {
		my $check;
		my $param_db;

		if (!$create) {
			return undef;
		}

		# Make sure exception exists
		$check = db_check_get($check_id);
		$param_db = $check->[$CHECK_T_PARAM_DB];

		if (!defined($param_db->{$param_id})) {
			die("parameter '$param_id' not found in check ".
			    "'$check_id'\n");
		}

		# Add an empty data set for this parameter
		$param_conf = [ $param_id, undef ];
		$param_conf_db->{$param_id} = $param_conf;
	}

	return ($profile, $param_conf);
}

#
# config_check_get_param_ids(check_id[, profile_id])
#
# Return list of parameter IDs of the check with the specified CHECK_ID for
# which there is configuration data available.
#
sub config_check_get_param_ids($;$)
{
	my ($check_id, $profile_id) = @_;
	my $check_conf;
	my $param_conf_db;

	$check_conf = _get_check_conf($check_id, 0, $profile_id);
	if (!defined($check_conf)) {
		return ();
	}

	$param_conf_db = $check_conf->[$CHECK_CONF_T_PARAM_CONF_DB];

	return keys(%{$param_conf_db});
}

#
# config_check_param_exists(check_id, param_id[, profile_id])
#
# Return non-zero if there is configuration data available for the specified
# CHECK_ID and PARAM_ID.
#
sub config_check_param_exists($$;$)
{
	my ($check_id, $param_id, $profile_id) = @_;
	my $param_conf;

	$param_conf = _get_check_param_conf($check_id, $param_id, 0,
					    $profile_id);
	if (defined($param_conf)) {
		return 1;
	}

	return 0;
}

#
# config_check_set_param(check_id, param_id, value[, profile_id])
#
# Set parameter PARAM_ID of check CHECK_ID in the active/selected profile to
# VALUE.
#
sub config_check_set_param($$$;$)
{
	my ($check_id, $param_id, $value, $profile_id) = @_;
	my $param_conf;
	my $profile;

	# Get parameter configuration
	($profile, $param_conf) = _get_check_param_conf($check_id, $param_id, 1,
							$profile_id, 1);

	# Set parameter value
	$param_conf->[$PARAM_CONF_T_VALUE] = $value;

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_get_param(check_id, param_id[, profile_id])
#
# Return configuration value for parameter PARAM_ID of check CHECK_ID from the
# active/selected profile. Return undef if setting could not be found.
#
sub config_check_get_param($$;$)
{
	my ($check_id, $param_id, $profile_id) = @_;
	my $param_conf;

	# Get parameter configuration
	$param_conf = _get_check_param_conf($check_id, $param_id, 0,
					    $profile_id);

	if (!defined($param_conf)) {
		return undef;
	}

	return $param_conf->[$PARAM_CONF_T_VALUE];
}

#
# config_check_get_param_or_default(check_id, param_id[, profile_id])
#
# Return parameter value. If no data is available return default parameter
# value.
#
sub config_check_get_param_or_default($$;$)
{
	my ($check_id, $param_id, $profile_id) = @_;
	my $value = config_check_get_param($check_id, $param_id, $profile_id);

	if (!defined($value)) {
		$value = db_check_get_param($check_id, $param_id);
	}

	return $value;
}

#
# _get_check_ex_conf(check_id, ex_id, create[, profile_id[, check_modify]])
#
# Return the exception configuration for exception EX_ID of check CHECK_ID.
# Create an empty configuration if no exception configuration is available and
# CREATE is non-zero.
#
sub _get_check_ex_conf($$$;$$)
{
	my ($check_id, $ex_id, $create, $profile_id, $check_modify) = @_;
	my $check_conf;
	my $ex_conf_db;
	my $ex_conf;
	my $profile;

	# Get check configuration
	($profile, $check_conf) = _get_check_conf($check_id, $create,
						  $profile_id, $check_modify);

	if (!defined($check_conf)) {
		return undef;
	}

	# Get exception configuration
	$ex_conf_db = $check_conf->[$CHECK_CONF_T_EX_CONF_DB];
	$ex_conf = $ex_conf_db->{$ex_id};

	if (!defined($ex_conf)) {
		my $check;
		my $ex_db;

		if (!$create) {
			return undef;
		}

		# Make sure exception exists
		$check = db_check_get($check_id);
		$ex_db = $check->[$CHECK_T_EX_DB];

		if (!defined($ex_db->{$ex_id})) {
			die("exception '$ex_id' not found in check ".
			    "'$check_id'\n");
		}

		# Add an empty data set for this parameter
		$ex_conf = [ $ex_id, undef, undef ];
		$ex_conf_db->{$ex_id} = $ex_conf;
	}

	return ($profile, $ex_conf);
}

#
# config_check_get_ex_ids(check_id[, profile_id])
#
# Return list of exception IDs of the check with the specified CHECK_ID for
# which there is configuration data available.
#
sub config_check_get_ex_ids($;$)
{
	my ($check_id, $profile_id) = @_;
	my $check_conf;
	my $ex_conf_db;

	$check_conf = _get_check_conf($check_id, 0, $profile_id);
	if (!defined($check_conf)) {
		return ();
	}

	$ex_conf_db = $check_conf->[$CHECK_CONF_T_EX_CONF_DB];

	return keys(%{$ex_conf_db});
}

#
# config_check_ex_exists(check_id, ex_id[, profile_id])
#
# Return non-zero if there is configuration data available for the specified
# CHECK_ID and EX_ID.
#
sub config_check_ex_exists($$;$)
{
	my ($check_id, $ex_id, $profile_id) = @_;
	my $ex_conf;

	$ex_conf = _get_check_ex_conf($check_id, $ex_id, 0, $profile_id);
	if (defined($ex_conf)) {
		return 1;
	}

	return 0;
}

#
# config_check_set_ex_severity(check_id, ex_id, severity[, profile_id])
#
# Set exception severity.
#
sub config_check_set_ex_severity($$$;$)
{
	my ($check_id, $ex_id, $severity, $profile_id) = @_;
	my $ex_conf;
	my $profile;

	# Get exception configuration
	($profile, $ex_conf) = _get_check_ex_conf($check_id, $ex_id, 1,
						  $profile_id, 1);

	# Set severity
	$ex_conf->[$EX_CONF_T_SEVERITY] = $severity;

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_get_ex_severity(check_id, ex_id[, profile_id])
#
# Return exception severity.
#
sub config_check_get_ex_severity($$;$)
{
	my ($check_id, $ex_id, $profile_id) = @_;
	my $ex_conf;

	# Get exception configuration
	$ex_conf = _get_check_ex_conf($check_id, $ex_id, 0, $profile_id);

	if (!defined($ex_conf)) {
		return undef;
	}

	return $ex_conf->[$EX_CONF_T_SEVERITY];
}

#
# config_check_get_ex_severity_or_default(check_id, ex_id[, profile_id])
#
# Return exception severity. If no data is available return default value.
#
sub config_check_get_ex_severity_or_default($$;$)
{
	my ($check_id, $ex_id, $profile_id) = @_;
	my $sev = config_check_get_ex_severity($check_id, $ex_id, $profile_id);

	if (!defined($sev)) {
		$sev = db_check_get_ex_severity($check_id, $ex_id);
	}

	return $sev;
}

#
# config_check_set_ex_state(check_id, ex_id, state[, profile_id])
#
# Set exception state.
#
sub config_check_set_ex_state($$$;$)
{
	my ($check_id, $ex_id, $state, $profile_id) = @_;
	my $ex_conf;
	my $profile;

	# Get exception configuration
	($profile, $ex_conf) = _get_check_ex_conf($check_id, $ex_id, 1,
						  $profile_id, 1);

	# Set severity
	$ex_conf->[$EX_CONF_T_STATE] = $state;

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_get_ex_state(check_id, ex_id[, profile_id])
#
# Return exception state.
#
sub config_check_get_ex_state($$;$)
{
	my ($check_id, $ex_id, $profile_id) = @_;
	my $ex_conf;

	# Get exception configuration
	$ex_conf = _get_check_ex_conf($check_id, $ex_id, 0, $profile_id);

	if (!defined($ex_conf)) {
		return undef;
	}

	return $ex_conf->[$EX_CONF_T_STATE];
}

#
# config_check_get_ex_state_or_default(check_id, ex_id[, profile_id])
#
# Return exception state. If no data is available return default value.
#
sub config_check_get_ex_state_or_default($$;$)
{
	my ($check_id, $ex_id, $profile_id) = @_;
	my $state = config_check_get_ex_state($check_id, $ex_id, $profile_id);

	if (!defined($state)) {
		$state = db_check_get_ex_state($check_id, $ex_id);
	}

	return $state;
}

#
# _get_check_si_conf(check_id, si_id, create[, profile_id[, check_modify]])
#
# Return the sysinfo item configuration for sysinfo item si_ID of check
# CHECK_ID. Create an empty configuration if no sysinfo item configuration
# is available and CREATE is non-zero.
#
sub _get_check_si_conf($$$;$$)
{
	my ($check_id, $si_id, $create, $profile_id, $check_modify) = @_;
	my $check_conf;
	my $si_conf_db;
	my $si_conf;
	my $profile;

	# Get check configuration
	($profile, $check_conf) = _get_check_conf($check_id, $create,
						  $profile_id, $check_modify);

	if (!defined($check_conf)) {
		return undef;
	}

	# Get exception configuration
	$si_conf_db = $check_conf->[$CHECK_CONF_T_SI_CONF_DB];
	$si_conf = $si_conf_db->{$si_id};

	if (!defined($si_conf)) {
		my $check;
		my $si_db;

		if (!$create) {
			return undef;
		}

		# Make sure sysinfo item exists
		$check = db_check_get($check_id);
		$si_db = $check->[$CHECK_T_SI_DB];

		if (!defined($si_db->{$si_id})) {
			die("sysinfo item '$si_id' not found in check ".
			    "'$check_id'\n");
		}

		# Add an empty data set for this parameter
		$si_conf = [ $si_id, undef, undef ];
		$si_conf_db->{$si_id} = $si_conf;
	}

	return ($profile, $si_conf);
}

#
# config_check_get_si_ids(check_id[, profile_id])
#
# Return list of sysinfo IDs of the check with the specified CHECK_ID for
# which there is configuration data available.
#
sub config_check_get_si_ids($;$)
{
	my ($check_id, $profile_id) = @_;
	my $check_conf;
	my $si_conf_db;

	$check_conf = _get_check_conf($check_id, 0, $profile_id);
	if (!defined($check_conf)) {
		return ();
	}

	$si_conf_db = $check_conf->[$CHECK_CONF_T_SI_CONF_DB];

	return keys(%{$si_conf_db});
}

#
# config_check_si_exists(check_id, si_id[, profile_id])
#
# Return non-zero if there is configuration data available for the specified
# CHECK_ID and SI_ID.
#
sub config_check_si_exists($$;$)
{
	my ($check_id, $si_id, $profile_id) = @_;
	my $si_conf;

	$si_conf = _get_check_si_conf($check_id, $si_id, 0, $profile_id);
	if (defined($si_conf)) {
		return 1;
	}

	return 0;
}

#
# config_check_set_si_rec_duration(check_id, si_id, duration[, profile_id])
#
# Set sysinfo record item duration.
#
sub config_check_set_si_rec_duration($$$;$)
{
	my ($check_id, $si_id, $duration, $profile_id) = @_;
	my $si_conf;
	my $check;
	my $si_db;
	my $si;
	my $profile;

	# Get sysinfo item configuration
	($profile, $si_conf) = _get_check_si_conf($check_id, $si_id, 1,
						  $profile_id, 1);

	$check = db_check_get($check_id);
	$si_db = $check->[$CHECK_T_SI_DB];
	$si = $si_db->{$si_id};
	if ($si->[$SYSINFO_T_TYPE] != $SI_TYPE_T_REC) {
		die("sysinfo item '$si_id' of check '$check_id' is not a ".
		    "record item\n");
	}

	# Set sysinfo item configuration type and duration
	$si_conf->[$SI_CONF_T_TYPE] = $SI_TYPE_T_REC;
	$si_conf->[$SI_CONF_T_DATA] = [ $duration ];

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_get_si_rec_duration(check_id, si_id[, profile_id])
#
# Get sysinfo record item duration.
#
sub config_check_get_si_rec_duration($$;$)
{
	my ($check_id, $si_id, $profile_id) = @_;
	my $si_conf;
	my $data;

	# Get sysinfo item configuration
	$si_conf = _get_check_si_conf($check_id, $si_id, 0, $profile_id);

	if (!defined($si_conf)) {
		return undef;
	}

	$data = $si_conf->[$SI_CONF_T_DATA];

	return $data->[$SI_REC_CONF_T_DURATION];
}

#
# config_check_get_si_rec_duration_or_default(check_id, si_id[, profile_id])
#
# Return sysinfo record item duration. If no data is available return default
# value.
#
sub config_check_get_si_rec_duration_or_default($$;$)
{
	my ($check_id, $si_id, $profile_id) = @_;
	my $duration = config_check_get_si_rec_duration($check_id, $si_id,
							$profile_id);

	if (!defined($duration)) {
		$duration = db_check_get_si_rec_duration($check_id, $si_id);
	}

	return $duration;
}

#
# config_check_set_defaults(check_id[, profile_id])
#
# Reset check configuration of check CHECK_ID to defaults.
#
sub config_check_set_defaults($;$)
{
	my ($check_id, $profile_id) = @_;
	my $profile;
	my $check_conf_db;
	my $check = db_check_get($check_id);

	# Get active/selected profile
	$profile = _get_profile($profile_id, 1);

	# Get check configuration
	$check_conf_db = $profile->[$PROFILE_T_CHECK_CONF_DB];
	$check_conf_db->{$check_id} = defaults_get_check_conf($check);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_del(check_id[, profile_id])
#
# Remove configuration for check CHECK_ID.
#
sub config_check_del($;$)
{
	my ($check_id, $profile_id) = @_;
	my $profile;
	my $check_conf_db;

	# Get active/selected profile
	$profile = _get_profile($profile_id, 1);

	# Get check configuration
	$check_conf_db = $profile->[$PROFILE_T_CHECK_CONF_DB];
	delete($check_conf_db->{$check_id});

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_get_active_ids([profile_id])
#
# Return list of IDs of active checks in database.
#
sub config_check_get_active_ids(;$)
{
	my ($profile_id) = @_;
	my @result;
	my $check_id;
	my @check_ids = db_check_get_ids();

	foreach $check_id (@check_ids) {
		my $state = config_check_get_state_or_default($check_id,
							      $profile_id);

		if ($state == $STATE_T_ACTIVE) {
			push(@result, $check_id);
		}
	}

	return @result;
}

#
# _cleanup_empty_param_conf_db(param_conf_db)
#
# Check PARAM_CONF_DB for empty param configurations and remove them. Return
# non-zero if PARAM_CONF_DB itself is empty.
#
sub _cleanup_empty_param_conf_db($)
{
	my ($param_conf_db) = @_;
	my $param_id;
	my $empty = 1;

	foreach $param_id (keys(%{$param_conf_db})) {
		my $param_conf = $param_conf_db->{$param_id};

		if (!defined($param_conf->[$PARAM_CONF_T_VALUE])) {
			delete($param_conf_db->{$param_id});
		} else {
			$empty = 0;
		}
	}

	return $empty;
}

#
# _cleanup_empty_ex_conf_db(ex_conf_db)
#
# Check EX_CONF_DB for empty exception configurations and remove them. Return
# non-zero if EX_CONF_DB itself is empty.
#
sub _cleanup_empty_ex_conf_db($)
{
	my ($ex_conf_db) = @_;
	my $ex_id;
	my $empty = 1;

	foreach $ex_id (keys(%{$ex_conf_db})) {
		my $ex_conf = $ex_conf_db->{$ex_id};

		if (!defined($ex_conf->[$EX_CONF_T_SEVERITY]) &&
		    !defined($ex_conf->[$EX_CONF_T_STATE])) {
			delete($ex_conf_db->{$ex_id});
		} else {
			$empty = 0;
		}
	}

	return $empty;
}

#
# _cleanup_empty_si_conf(si_conf_db)
#
# Check SI_CONF_DB for empty sysinfo configurations and remove them. Return
# non-zero if SI_CONF_DB itself is empty.
#
sub _cleanup_empty_si_conf($)
{
	my ($si_conf_db) = @_;
	my $si_id;
	my $empty = 1;

	foreach $si_id (keys(%{$si_conf_db})) {
		my $si_conf = $si_conf_db->{$si_id};

		if (!defined($si_conf->[$SI_CONF_T_DATA])) {
			delete($si_conf_db->{$si_id});
		} else {
			$empty = 0;
		}
	}

	return $empty;
}

#
# _cleanup_empty_check_conf(check_id, profile_id)
#
# Remove check configuration for CHECK_ID if it doesn't contain any data.
#
sub _cleanup_empty_check_conf($$)
{
	my ($check_conf, $profile_id) = @_;
	my $param_conf_db = $check_conf->[$CHECK_CONF_T_PARAM_CONF_DB];
	my $ex_conf_db = $check_conf->[$CHECK_CONF_T_EX_CONF_DB];
	my $si_conf_db = $check_conf->[$CHECK_CONF_T_SI_CONF_DB];
	my $empty;

	$empty = _cleanup_empty_param_conf_db($param_conf_db);
	$empty = _cleanup_empty_ex_conf_db($ex_conf_db) && $empty;
	$empty = _cleanup_empty_si_conf($si_conf_db) && $empty;

	# Check if there's any data remaining
	if ($empty && !defined($check_conf->[$CHECK_CONF_T_STATE]) &&
	    !defined($check_conf->[$CHECK_CONF_T_REPEAT])) {
		# Remove empty check configuration
		config_check_del($check_conf->[$CHECK_CONF_T_ID], $profile_id);
	}
}

#
# config_check_del_state(check_id[, profile_id])
#
# Remove check activation state configuration setting.
#
sub config_check_del_state($;$)
{
	my ($check_id, $profile_id) = @_;
	my $check_conf;
	my $profile;

	($profile, $check_conf) = _get_check_conf($check_id, 0, $profile_id, 1);
	if (!defined($check_conf)) {
		return;
	}
	$check_conf->[$CHECK_CONF_T_STATE] = undef;
	_cleanup_empty_check_conf($check_conf, $profile_id);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_del_repeat(check_id[, profile_id])
#
# Remove check repeat configuration setting.
#
sub config_check_del_repeat($;$)
{
	my ($check_id, $profile_id) = @_;
	my $check_conf;
	my $profile;

	($profile, $check_conf) = _get_check_conf($check_id, 0, $profile_id, 1);
	if (!defined($check_conf)) {
		return;
	}
	$check_conf->[$CHECK_CONF_T_REPEAT] = undef;
	_cleanup_empty_check_conf($check_conf, $profile_id);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_del_param_value(check_id, param_id[, profile_id])
#
# Remove check parameter value configuration setting.
#
sub config_check_del_param_value($$;$)
{
	my ($check_id, $param_id, $profile_id) = @_;
	my $check_conf;
	my $param_conf_db;
	my $profile;

	($profile, $check_conf) = _get_check_conf($check_id, 0, $profile_id, 1);
	if (!defined($check_conf)) {
		return;
	}
	$param_conf_db = $check_conf->[$CHECK_CONF_T_PARAM_CONF_DB];
	delete($param_conf_db->{$param_id});
	_cleanup_empty_check_conf($check_conf, $profile_id);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_del_ex_severity(check_id, ex_id[, profile_id])
#
# Remove check exception severity configuration setting.
#
sub config_check_del_ex_severity($$;$)
{
	my ($check_id, $ex_id, $profile_id) = @_;
	my $check_conf;
	my $ex_conf_db;
	my $ex_conf;
	my $profile;

	($profile, $check_conf) = _get_check_conf($check_id, 0, $profile_id, 1);
	if (!defined($check_conf)) {
		return;
	}
	$ex_conf_db = $check_conf->[$CHECK_CONF_T_EX_CONF_DB];
	$ex_conf = $ex_conf_db->{$ex_id};
	if (!defined($ex_conf)) {
		return;
	}
	$ex_conf->[$EX_CONF_T_SEVERITY] = undef;
	_cleanup_empty_check_conf($check_conf, $profile_id);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_del_ex_state(check_id, ex_id[, profile_id])
#
# Remove check exception activation state configuration setting.
#
sub config_check_del_ex_state($$;$)
{
	my ($check_id, $ex_id, $profile_id) = @_;
	my $check_conf;
	my $ex_conf_db;
	my $ex_conf;
	my $profile;

	($profile, $check_conf) = _get_check_conf($check_id, 0, $profile_id, 1);
	if (!defined($check_conf)) {
		return;
	}
	$ex_conf_db = $check_conf->[$CHECK_CONF_T_EX_CONF_DB];
	$ex_conf = $ex_conf_db->{$ex_id};
	if (!defined($ex_conf)) {
		return;
	}
	$ex_conf->[$EX_CONF_T_STATE] = undef;
	_cleanup_empty_check_conf($check_conf, $profile_id);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_check_del_si_rec_duration(check_id, si_id[, profile_id])
#
# Remove check sysinfo record item duration configuration setting.
#
sub config_check_del_si_rec_duration($$;$)
{
	my ($check_id, $si_id, $profile_id) = @_;
	my $check_conf;
	my $si_conf_db;
	my $si_conf;
	my $type;
	my $data;
	my $profile;

	($profile, $check_conf) = _get_check_conf($check_id, 0, $profile_id, 1);
	if (!defined($check_conf)) {
		return;
	}
	$si_conf_db = $check_conf->[$CHECK_CONF_T_SI_CONF_DB];
	$si_conf = $si_conf_db->{$si_id};
	if (!defined($si_conf)) {
		return;
	}
	(undef, $type, $data) = @$si_conf;

	if ($type != $SI_TYPE_T_REC) {
		die("Sysinfo item '$check_id.$si_id' is not a record item!\n");
	}

	delete($si_conf_db->{$si_id});
	_cleanup_empty_check_conf($check_conf, $profile_id);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# _get_cons_conf(cons_id, create[, profile_id[, check_modify]])
#
# Return the consumer configuration for the specified CONS_ID. Create an
# empty configuration if no consumer configuration is available and CREATE is
# non-zero. Return (profile, check_conf) on success, undef on error.
#
sub _get_cons_conf($$;$$)
{
	my ($cons_id, $create, $profile_id, $check_modify) = @_;
	my $profile;
	my $cons_conf_db;
	my $cons_conf;

	# Get active/selected profile
	$profile = _get_profile($profile_id, $check_modify);

	# Get consumer configuration
	$cons_conf_db = $profile->[$PROFILE_T_CONS_CONF_DB];
	$cons_conf = $cons_conf_db->{$cons_id};

	if (!defined($cons_conf)) {
		if (!$create) {
			return undef;
		}
		# Add an empty data set for this consumer
		$cons_conf = [ $cons_id, undef, {} ];
		$cons_conf_db->{$cons_id} = $cons_conf;
	}

	return ($profile, $cons_conf);
}

#
# _cleanup_empty_cons_conf(cons_id, profile_id)
#
# Remove consumer configuration for CONS_ID if it doesn't contain any data.
#
sub _cleanup_empty_cons_conf($$)
{
	my ($cons_conf, $profile_id) = @_;
	my $param_conf_db = $cons_conf->[$CONS_CONF_T_PARAM_CONF_DB];
	my $empty;

	$empty = _cleanup_empty_param_conf_db($param_conf_db);

	# Check if there's any data remaining
	if ($empty && !defined($cons_conf->[$CONS_CONF_T_STATE])) {
		# Remove empty cons configuration
		config_cons_del($cons_conf->[$CONS_CONF_T_ID], $profile_id);
	}
}

#
# config_cons_del_state(cons_id, profile_id)
#
# Remove consumer activation state configuration setting.
#
sub config_cons_del_state($$)
{
	my ($cons_id, $profile_id) = @_;
	my $cons_conf;
	my $profile;

	($profile, $cons_conf) = _get_cons_conf($cons_id, 0, $profile_id, 1);
	if (!defined($cons_conf)) {
		return;
	}
	$cons_conf->[$CONS_CONF_T_STATE] = undef;
	_cleanup_empty_cons_conf($cons_conf, $profile_id);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_cons_del_param_value(cons_id, param_id, profile_id)
#
# Remove consumer parameter value configuration setting.
#
sub config_cons_del_param_value($$$)
{
	my ($cons_id, $param_id, $profile_id) = @_;
	my $cons_conf;
	my $param_conf_db;
	my $profile;

	($profile, $cons_conf) = _get_cons_conf($cons_id, 0, $profile_id, 1);
	if (!defined($cons_conf)) {
		return;
	}
	$param_conf_db = $cons_conf->[$CONS_CONF_T_PARAM_CONF_DB];
	delete($param_conf_db->{$param_id});
	_cleanup_empty_cons_conf($cons_conf, $profile_id);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_cons_get_ids([profile_id])
#
# Return list of consumer IDs for which there is configuration data available.
#
sub config_cons_get_ids(;$)
{
	my ($profile_id) = @_;
	my $profile;

	# Get active/selected profile
	$profile = _get_profile($profile_id);

	return keys(%{$profile->[$PROFILE_T_CONS_CONF_DB]});
}

#
# config_cons_exists(cons_id[, profile_id])
#
# Return non-zero if there is configuration data available for consumer CONS_ID.
#
sub config_cons_exists($;$)
{
	my ($cons_id, $profile_id) = @_;
	my $profile;
	my $cons_conf_db;

	# Get active/selected profile
	$profile = _get_profile($profile_id);

	$cons_conf_db = $profile->[$PROFILE_T_CONS_CONF_DB];

	if (defined($cons_conf_db->{$cons_id})) {
		return 1;
	}

	return 0;
}

#
# _get_cons_param_conf(cons_id, param_id, create[, profile_id[, check_modify]])
#
# Return the parameter configuration for parameter PARAM_ID of consumer
# CONS_ID: Create an empty configuration if no parameter configuration is
# available and CREATE is non-zero.
#
sub _get_cons_param_conf($$$;$$)
{
	my ($cons_id, $param_id, $create, $profile_id, $check_modify) = @_;
	my $cons_conf;
	my $param_conf_db;
	my $param_conf;
	my $profile;

	# Get consumer configuration
	($profile, $cons_conf) = _get_cons_conf($cons_id, $create, $profile_id,
						$check_modify);

	if (!defined($cons_conf)) {
		return undef;
	}

	# Get parameter configuration
	$param_conf_db = $cons_conf->[$CONS_CONF_T_PARAM_CONF_DB];
	$param_conf = $param_conf_db->{$param_id};

	if (!defined($param_conf)) {
		if (!$create) {
			return undef;
		}
		# Add an empty data set for this parameter
		$param_conf = [ $param_id, undef ];
		$param_conf_db->{$param_id} = $param_conf;
	}

	return ($profile, $param_conf);
}

#
# config_cons_get_param_ids(cons_id[, profile_id])
#
# Return list of parameters for consumer CONS_ID.
#
sub config_cons_get_param_ids($;$)
{
	my ($cons_id, $profile_id) = @_;
	my $cons_conf;
	my $param_conf_db;

	# Get consumer configuration
	$cons_conf = _get_cons_conf($cons_id, 0, $profile_id);

	if (!defined($cons_conf)) {
		return ();
	}
	$param_conf_db = $cons_conf->[$CONS_CONF_T_PARAM_CONF_DB];

	return keys(%{$param_conf_db});
}

#
# config_cons_param_exists(cons_id, param_id[, profile_id])
#
# Return non-zero if there is configuration data available for the specified
# CONS_ID and PARAM_ID.
#
sub config_cons_param_exists($$;$)
{
	my ($cons_id, $param_id, $profile_id) = @_;
	my $param_conf;

	$param_conf = _get_cons_param_conf($cons_id, $param_id, 0,
					   $profile_id);
	if (defined($param_conf)) {
		return 1;
	}

	return 0;
}

#
# config_cons_set_state(cons_id, state[, profile_id])
#
# Set consumer state.
#
sub config_cons_set_state($$;$)
{
	my ($cons_id, $state, $profile_id) = @_;
	my $cons_conf;
	my $profile;

	# Get consumer configuration
	($profile, $cons_conf) = _get_cons_conf($cons_id, 1, $profile_id, 1);

	# Set state
	$cons_conf->[$CONS_CONF_T_STATE] = $state;

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_cons_get_state(cons_id[, profile_id])
#
# Get consumer state.
#
sub config_cons_get_state($;$)
{
	my ($cons_id, $profile_id) = @_;
	my $cons_conf;

	# Get consumer configuration
	$cons_conf = _get_cons_conf($cons_id, 0, $profile_id);

	if (!defined($cons_conf)) {
		return undef;
	}

	return $cons_conf->[$CONS_CONF_T_STATE];
}

#
# config_cons_get_state_or_default(cons_id[, profile_id])
#
# Return consumer state. If no data is available return default value.
#
sub config_cons_get_state_or_default($;$)
{
	my ($cons_id, $profile_id) = @_;
	my $state = config_cons_get_state($cons_id, $profile_id);

	if (!defined($state)) {
		$state = db_cons_get_state($cons_id);
	}

	return $state;
}

#
# config_cons_set_param(cons_id, param_id, value[, profile_id])
#
# Set parameter PARAM_ID of consumer CONS_ID in the active/selected profile to
# VALUE.
#
sub config_cons_set_param($$$;$)
{
	my ($cons_id, $param_id, $value, $profile_id) = @_;
	my $param_conf;
	my $profile;

	# Get parameter configuration
	($profile, $param_conf) = _get_cons_param_conf($cons_id, $param_id, 1,
						       $profile_id, 1);

	# Set parameter value
	$param_conf->[$PARAM_CONF_T_VALUE] = $value;

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_cons_get_param(cons_id, param_id[, profile_id])
#
# Return configuration value for parameter PARAM_ID of consumer CONS_ID from the
# active/selected profile. Return undef if setting could not be found.
#
sub config_cons_get_param($$;$)
{
	my ($cons_id, $param_id, $profile_id) = @_;
	my $param_conf;

	# Get parameter configuration
	$param_conf = _get_cons_param_conf($cons_id, $param_id, 0, $profile_id);

	if (!defined($param_conf)) {
		return undef;
	}

	return $param_conf->[$PARAM_CONF_T_VALUE];
}

#
# config_cons_get_param_or_default(cons_id, param_id[, profile_id])
#
# Return consumer parameter value. If no data is available return default value.
#
sub config_cons_get_param_or_default($$;$)
{
	my ($cons_id, $param_id, $profile_id) = @_;
	my $value = config_cons_get_param($cons_id, $param_id, $profile_id);

	if (!defined($value)) {
		$value = db_cons_get_param($cons_id, $param_id);
	}

	return $value;
}

#
# config_cons_set_defaults(cons_id[, profile_id])
#
# Reset consumer configuration of consumer CONS_ID to defaults.
#
sub config_cons_set_defaults($;$)
{
	my ($cons_id, $profile_id) = @_;
	my $profile;
	my $cons_conf_db;
	my $cons = db_cons_get($cons_id);

	# Get active/selected profile
	$profile = _get_profile($profile_id);

	# Get cons configuration
	$cons_conf_db = $profile->[$PROFILE_T_CONS_CONF_DB];
	$cons_conf_db->{$cons_id} = defaults_get_cons_conf($cons);

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_cons_del(cons_id[, profile_id])
#
# Remove configuration for consumer CONS_ID.
#
sub config_cons_del($;$)
{
	my ($cons_id, $profile_id) = @_;
	my $profile;
	my $cons_conf_db;

	# Get active/selected profile
	$profile = _get_profile($profile_id);

	# Get consumer configuration database
	$cons_conf_db = $profile->[$PROFILE_T_CONS_CONF_DB];
	delete($cons_conf_db->{$cons_id});

	# Set write marker
	db_profile_set_modified($profile->[$PROFILE_T_ID]);
}

#
# config_cons_get_active_ids([profile_id])
#
# Return list of IDs of active consumers in database.
#
sub config_cons_get_active_ids(;$)
{
	my ($profile_id) = @_;
	my @result;
	my $cons_id;
	my @cons_ids = db_cons_get_ids();

	foreach $cons_id (@cons_ids) {
		my $state = config_cons_get_state_or_default($cons_id,
							     $profile_id);

		if ($state == $STATE_T_ACTIVE) {
			push(@result, $cons_id);
		}
	}

	return @result;
}


#
# Code entry
#

# Indicate successful module initialization
1;
