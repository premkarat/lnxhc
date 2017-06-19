#
# LNXHC::Profile.pm
#   Linux Health Checker profile handling functions
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

package LNXHC::Profile;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#
use LNXHC::Config qw(config_check_del_ex_severity config_check_del_ex_state
		     config_check_del_param_value config_check_del_repeat
		     config_check_del_si_rec_duration config_check_del_state
		     config_check_ex_exists config_check_exists
		     config_check_get_ex_ids config_check_get_ex_severity
		     config_check_get_ex_state config_check_get_ids
		     config_check_get_param config_check_get_param_ids
		     config_check_get_repeat config_check_get_si_ids
		     config_check_get_si_rec_duration config_check_get_state
		     config_check_param_exists config_check_set_ex_severity
		     config_check_set_ex_state config_check_set_param
		     config_check_set_repeat config_check_set_si_rec_duration
		     config_check_set_state config_check_si_exists config_clear
		     config_cons_del_param_value config_cons_del_state
		     config_cons_exists config_cons_get_ids
		     config_cons_get_param config_cons_get_param_ids
		     config_cons_get_state config_cons_param_exists
		     config_cons_set_param config_cons_set_state config_get_desc
		     config_host_get_by_num config_host_remove
		     config_host_remove_by_num config_host_replace_by_num
		     config_hosts_get config_set_defaults config_set_desc);
use LNXHC::Consts qw($CHECK_T_SI_DB $EX_CONF_T_SEVERITY $EX_CONF_T_STATE
		     $MATCH_ID $MATCH_ID_CHAR $MATCH_ID_WILDCARD
		     $PARAM_CONF_T_VALUE $PROFILE_T_CHECK_CONF_DB
		     $PROFILE_T_CONS_CONF_DB $PROFILE_T_DESC $PROFILE_T_FILENAME
		     $PROFILE_T_ID $PROFILE_T_SYSTEM $PROP_EXP_ALWAYS
		     $PROP_EXP_NEVER $SI_CONF_T_DATA $SI_CONF_T_TYPE
		     $SI_REC_CONF_T_DURATION $SI_TYPE_T_REC $SPEC_T_ID
		     $SPEC_T_KEY $SPEC_T_WILDCARD $SYSINFO_T_TYPE);
use LNXHC::DBCheck qw(db_check_ex_exists db_check_exists db_check_get
		      db_check_get_ex_ids db_check_get_ids
		      db_check_get_param_ids db_check_param_exists
		      db_check_si_exists);
use LNXHC::DBCons qw(db_cons_exists db_cons_get_ids db_cons_get_param_ids
		     db_cons_param_exists);
use LNXHC::DBProfile qw(db_profile_copy db_profile_exists db_profile_export
			db_profile_get db_profile_get_active_id
			db_profile_get_ids db_profile_import db_profile_merge
			db_profile_new db_profile_rename
			db_profile_set_active_id db_profile_uninstall);
use LNXHC::Misc qw($opt_debug check_opt_system debug get_db_scope get_indented
		   get_spec_type info info2 match_wildcard normalize_duration
		   print_padded sec_to_duration sev_to_str state_to_str
		   str_to_sev str_to_state system_to_str validate_duration
		   validate_id);
use LNXHC::Prop qw(prop_parse_key);
use LNXHC::Util qw($ALIGN_T_LEFT layout_get_width lprintf);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&profile_activate &profile_clear &profile_copy
		    &profile_delete &profile_export &profile_get_num_selected
		    &profile_get_selected_ids &profile_import &profile_list
		    &profile_merge &profile_new &profile_remove_properties
		    &profile_rename &profile_select &profile_select_all
		    &profile_select_none &profile_selection_is_empty
		    &profile_set_defaults &profile_set_desc
		    &profile_set_property &profile_show &profile_show_property);


#
# Constants
#

# Profile property tags
# <profile_id>.id
my $_PROP_ID				= 0;
# <profile_id>.desc
my $_PROP_DESC				= 1;
# <profile_id>.host.<num>
my $_PROP_HOST				= 2;
# <profile_id>.check.<check_id>.state
my $_PROP_CHECK_STATE			= 3;
# <profile_id>.check.<check_id>.repeat
my $_PROP_CHECK_REPEAT			= 4;
# <profile_id>.check.<check_id>.param.<param_id>.value
my $_PROP_CHECK_PARAM_VALUE		= 5;
# <profile_id>.check.<check_id>.si.<si_id>.rec_duration
my $_PROP_CHECK_SI_REC_DURATION		= 6;
# <profile_id>.check.<check_id>.ex.<ex_id>.sev
my $_PROP_CHECK_EX_SEVERITY		= 7;
# <profile_id>.check.<check_id>.ex.<ex_id>.state
my $_PROP_CHECK_EX_STATE		= 8;
# <profile_id>.cons.<cons_id>.state
my $_PROP_CONS_STATE			= 9;
# <profile_id>.cons.<cons_id>.param.<param_id>.value
my $_PROP_CONS_PARAM_VALUE		= 10;
# <profile_id>.filename
my $_PROP_FILENAME			= 11;
# <profile_id>.system
my $_PROP_SYSTEM			= 12;

# Profile property classes (also determine sort order)
my $_PROP_CLASS_PROFILE			= 0;
my $_PROP_CLASS_HOST			= 1;
my $_PROP_CLASS_CHECK			= 2;
my $_PROP_CLASS_CHECK_PARAM		= 3;
my $_PROP_CLASS_CHECK_SI		= 4;
my $_PROP_CLASS_CHECK_EX		= 5;
my $_PROP_CLASS_CONS			= 6;
my $_PROP_CLASS_CONS_PARAM		= 7;

# Profile property class map
my %_PROP_CLASS = (
	$_PROP_ID			=> $_PROP_CLASS_PROFILE,
	$_PROP_DESC			=> $_PROP_CLASS_PROFILE,
	$_PROP_FILENAME			=> $_PROP_CLASS_PROFILE,
	$_PROP_SYSTEM			=> $_PROP_CLASS_PROFILE,
	$_PROP_HOST			=> $_PROP_CLASS_HOST,
	$_PROP_CHECK_STATE		=> $_PROP_CLASS_CHECK,
	$_PROP_CHECK_REPEAT		=> $_PROP_CLASS_CHECK,
	$_PROP_CHECK_PARAM_VALUE	=> $_PROP_CLASS_CHECK_PARAM,
	$_PROP_CHECK_SI_REC_DURATION	=> $_PROP_CLASS_CHECK_SI,
	$_PROP_CHECK_EX_SEVERITY	=> $_PROP_CLASS_CHECK_EX,
	$_PROP_CHECK_EX_STATE		=> $_PROP_CLASS_CHECK_EX,
	$_PROP_CONS_STATE		=> $_PROP_CLASS_CONS,
	$_PROP_CONS_PARAM_VALUE		=> $_PROP_CLASS_CONS_PARAM,
);

# Profile property meta-classes (used for sort order)
my $_PROP_METACLASS_PROFILE		= 0;
my $_PROP_METACLASS_HOST		= 1;
my $_PROP_METACLASS_CHECK		= 2;
my $_PROP_METACLASS_CONS		= 3;

my %_PROP_METACLASS = (
	$_PROP_ID			=> $_PROP_METACLASS_PROFILE,
	$_PROP_DESC			=> $_PROP_METACLASS_PROFILE,
	$_PROP_FILENAME			=> $_PROP_METACLASS_PROFILE,
	$_PROP_SYSTEM			=> $_PROP_METACLASS_PROFILE,
	$_PROP_HOST			=> $_PROP_METACLASS_HOST,
	$_PROP_CHECK_STATE		=> $_PROP_METACLASS_CHECK,
	$_PROP_CHECK_REPEAT		=> $_PROP_METACLASS_CHECK,
	$_PROP_CHECK_PARAM_VALUE	=> $_PROP_METACLASS_CHECK,
	$_PROP_CHECK_SI_REC_DURATION	=> $_PROP_METACLASS_CHECK,
	$_PROP_CHECK_EX_SEVERITY	=> $_PROP_METACLASS_CHECK,
	$_PROP_CHECK_EX_STATE		=> $_PROP_METACLASS_CHECK,
	$_PROP_CONS_STATE		=> $_PROP_METACLASS_CONS,
	$_PROP_CONS_PARAM_VALUE		=> $_PROP_METACLASS_CONS,
);

# Profile property definition map
# key_def => prop_tag
my %_PDEF_MAP = (
	"<profile_id>.id"
		=> $_PROP_ID,
	"<profile_id>.desc"
		=> $_PROP_DESC,
	"<profile_id>.host.<num>"
		=> $_PROP_HOST,
	"<profile_id>.check.<check_id>.state"
		=> $_PROP_CHECK_STATE,
	"<profile_id>.check.<check_id>.repeat"
		=> $_PROP_CHECK_REPEAT,
	"<profile_id>.check.<check_id>.param.<param_id>.value"
		=> $_PROP_CHECK_PARAM_VALUE,
	"<profile_id>.check.<check_id>.ex.<ex_id>.sev"
		=> $_PROP_CHECK_EX_SEVERITY,
	"<profile_id>.check.<check_id>.ex.<ex_id>.state"
		=> $_PROP_CHECK_EX_STATE,
	"<profile_id>.check.<check_id>.si.<si_id>.rec_duration"
		=> $_PROP_CHECK_SI_REC_DURATION,
	"<profile_id>.cons.<cons_id>.state"
		=> $_PROP_CONS_STATE,
	"<profile_id>.cons.<cons_id>.param.<param_id>.value"
		=> $_PROP_CONS_PARAM_VALUE,
	"<profile_id>.filename"
		=> $_PROP_FILENAME,
	"<profile_id>.system"
		=> $_PROP_SYSTEM,
);

# Forward declaration
sub _ns_profile_ids_get($$$);
sub _ns_profile_ids_get_selected($$$);
sub _ns_profile_id_is_valid($$$);
sub _ns_host_nums_get($$$);
sub _ns_host_num_exists($$$);
sub _ns_check_ids_get($$$);
sub _ns_check_id_is_valid($$$);
sub _ns_param_ids_get($$$);
sub _ns_param_id_is_valid($$$);
sub _ns_ex_ids_get($$$);
sub _ns_ex_id_is_valid($$$);
sub _ns_si_ids_get($$$);
sub _ns_si_id_is_valid($$$);
sub _ns_cons_ids_get($$$);
sub _ns_cons_id_is_valid($$$);

# Profile property namespace map
# ns_id => [ type, regexp, fn_get_ids, fn_id_is_valid ]
my %_PDEF_NS = (
	"<profile_id>" =>
		[ "profile name", "(".$MATCH_ID_WILDCARD.")|",
		  \&_ns_profile_ids_get, \&_ns_profile_ids_get_selected,
		  \&_ns_profile_id_is_valid],
	"<num>" =>
		[ "host number", '[\d\?\*]+',
		  \&_ns_host_nums_get, undef, \&_ns_host_num_exists ],
	"<check_id>" =>
		[ "check name", $MATCH_ID_WILDCARD,
		  \&_ns_check_ids_get, undef, \&_ns_check_id_is_valid ],
	"<param_id>" =>
		[ "parameter ID", $MATCH_ID_WILDCARD,
		  \&_ns_param_ids_get, undef, \&_ns_param_id_is_valid ],
	"<si_id>" =>
		[ "sysinfo ID", $MATCH_ID_WILDCARD,
		  \&_ns_si_ids_get, undef, \&_ns_si_id_is_valid ],
	"<ex_id>" =>
		[ "exception ID", $MATCH_ID_WILDCARD,
		  \&_ns_ex_ids_get, undef, \&_ns_ex_id_is_valid ],
	"<cons_id>" =>
		[ "consumer name", $MATCH_ID_WILDCARD,
		  \&_ns_cons_ids_get, undef, \&_ns_cons_id_is_valid ],
);

# Property ID type definition
my $_PROP_ID_T_TAG		= 0;
my $_PROP_ID_T_PROFILE_ID	= 1;
my $_PROP_ID_T_HOST_NUM		= 2;
my $_PROP_ID_T_CHECK_ID		= 2;
my $_PROP_ID_T_CONS_ID		= 2;
my $_PROP_ID_T_PARAM_ID		= 3;
my $_PROP_ID_T_EX_ID		= 3;
my $_PROP_ID_T_SI_ID		= 3;


#
# Global variables
#

# IDs of selected profiles
my %_selected_profile_ids;

# Flag indicating if a selection is active
my $_selection_active;


#
# Sub-routines
#

#
# profile_get_selected_ids()
#
# Return list of selected profile IDs.
#
sub profile_get_selected_ids()
{
	return sort(keys(%_selected_profile_ids));
}

#
# profile_get_num_selected()
#
# Return number of selected profile IDs.
#
sub profile_get_num_selected()
{
	return scalar(keys(%_selected_profile_ids));
}

#
# _get_ids([do_die, use_all])
#
# Return list of selected profile IDs or of active ID if no profile was
# selected.
#
sub _get_ids(;$$)
{
	my ($do_die, $use_all) = @_;
	my @profile_ids;

	if ($_selection_active) {
		@profile_ids = profile_get_selected_ids();
		if (!@profile_ids && $do_die) {
			die("No profile was selected!\n");
		}
	} elsif ($use_all) {
		@profile_ids = db_profile_get_ids();
	} else {
		@profile_ids = ( db_profile_get_active_id() );
	}

	return @profile_ids;
}

#
# _get_id()
#
# Return ID of selected or active profile.
#
sub _get_id()
{
	my @profile_ids = _get_ids();

	return $profile_ids[0];
}

#
# _ns_profile_ids_get(subkeys, level, create)
#
# Return list of profile IDs.
#
sub _ns_profile_ids_get($$$)
{
	my ($subkeys, $level, $create) = @_;

	return db_profile_get_ids();
}

#
# _ns_profile_ids_get_selected(subkeys, level, create)
#
# Return list of selected profile IDs.
#
sub _ns_profile_ids_get_selected($$$)
{
	my ($subkeys, $level, $create) = @_;

	return _get_ids();
}

#
# _ns_profile_id_is_valid(subkeys, level, create)
#
# Return non-zero if profile ID specified by SUBKEYS and LEVEL exists.
#
sub _ns_profile_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[$level];

	if ($create) {
		# Check if this ID can be created instead
		if ($profile_id =~ /^$MATCH_ID$/) {
			return 1;
		}
		return 0;
	} else {
		return db_profile_exists($profile_id);
	}
}

#
# _ns_host_nums_get(subkeys, level, create)
#
# Return list of host numbers.
#
sub _ns_host_nums_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];
	my $hosts = config_hosts_get($profile_id);

	if (!defined($hosts)) {
		return ();
	}
	return 0..(scalar(@$hosts) - 1);
}

#
# _ns_host_num_exists(subkeys, level, create)
#
# Return non-zero if host number specified by SUBKEYS and LEVEL exists.
#
sub _ns_host_num_exists($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];
	my $hosts;
	my $num = $subkeys->[$level];

	# Check if this is a number, also remove leading zeros
	if (!($num =~ s/^0*(\d+)$/$1/)) {
		return 0;
	}

	if ($create) {
		# For IDs that should be created, this is enough testing
		return 1;
	}

	$hosts = config_hosts_get($profile_id);

	# Check number against host list
	if (!defined($hosts) || $num >= scalar(@$hosts)) {
		return 0;
	}

	return 1;
}

#
# _ns_check_ids_get(subkeys, level, create)
#
# Return list of check IDs.
#
sub _ns_check_ids_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];

	if ($create) {
		# Return list of installed check IDs
		return db_check_get_ids();
	} else {
		# Return list of check IDs for which there is configuration
		# data available
		return config_check_get_ids($profile_id);
	}
}

#
# _ns_check_id_is_valid(subkeys, level, create)
#
# Return non-zero if check ID specified by SUBKEYS and LEVEL exists.
#
sub _ns_check_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];
	my $check_id = $subkeys->[$level];

	if ($create) {
		# Check if check with specified ID is installed
		return db_check_exists($check_id) ||
		       config_check_exists($check_id, $profile_id);
	} else {
		# Check if there is configuration data available for check
		# with specified ID
		return config_check_exists($check_id, $profile_id);
	}
}

#
# _ns_param_ids_get(subkeys, level, create)
#
# Return list of parameter IDs.
#
sub _ns_param_ids_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];
	my $type = $subkeys->[1];
	my $id = $subkeys->[2];

	if ($create) {
		if ($type eq "check") {
			return db_check_get_param_ids($id);
		} elsif ($type eq "cons") {
			return db_cons_get_param_ids($id);
		}
	} else {
		if ($type eq "check") {
			return config_check_get_param_ids($id, $profile_id);
		} elsif ($type eq "cons") {
			return config_cons_get_param_ids($id, $profile_id);
		}
	}
}

#
# _ns_param_id_is_valid(subkeys, level, create)
#
# Return non-zero if parameter ID specified by SUBKEYS and LEVEL exists.
#
sub _ns_param_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];
	my $type = $subkeys->[1];
	my $id = $subkeys->[2];
	my $param_id = $subkeys->[4];

	if ($create) {
		if ($type eq "check") {
			return db_check_param_exists($id, $param_id) ||
			       config_check_param_exists($id, $param_id,
							 $profile_id);
		} elsif ($type eq "cons") {
			return db_cons_param_exists($id, $param_id) ||
			       config_cons_param_exists($id, $param_id,
							$profile_id);
		}
	} else {
		if ($type eq "check") {
			return config_check_param_exists($id, $param_id,
							 $profile_id);
		} elsif ($type eq "cons") {
			return config_cons_param_exists($id, $param_id,
							$profile_id);
		}
	}
}

#
# _check_get_rec_si_ids(check_id)
#
# Return list of records sysinfo IDS for check CHECK_ID.
#
sub _check_get_rec_si_ids($)
{
	my ($check_id) = @_;
	my $check = db_check_get($check_id);
	my $si_db;
	my $si_id;
	my @result;

	if (!defined($check)) {
		return ();
	}
	$si_db = $check->[$CHECK_T_SI_DB];

	foreach $si_id (keys(%{$si_db})) {
		my $sysinfo = $si_db->{$si_id};
		my $si_type = $sysinfo->[$SYSINFO_T_TYPE];

		if ($si_type == $SI_TYPE_T_REC) {
			push(@result, $si_id);
		}
	}

	return @result;
}

#
# _ns_si_ids_get(subkeys, level, create)
#
# Return list of sysinfo IDs of record type sysinfo items.
#
sub _ns_si_ids_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];
	my $check_id = $subkeys->[2];

	if ($create) {
		return _check_get_rec_si_ids($check_id);
	} else {
		return config_check_get_si_ids($check_id, $profile_id);
	}
}

#
# _ns_si_id_is_valid(subkeys, level, create)
#
# Return non-zero if sysinfo ID specified by SUBKEYS and LEVEL exists.
#
sub _ns_si_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];
	my $check_id = $subkeys->[2];
	my $si_id = $subkeys->[4];

	if ($create) {
		return db_check_si_exists($check_id, $si_id) ||
		       config_check_si_exists($check_id, $si_id, $profile_id);
	} else {
		return config_check_si_exists($check_id, $si_id, $profile_id);
	}
}

#
# _ns_ex_ids_get(subkeys, level, create)
#
# Return list of exception IDs.
#
sub _ns_ex_ids_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];
	my $check_id = $subkeys->[2];

	if ($create) {
		return db_check_get_ex_ids($check_id);
	} else {
		return config_check_get_ex_ids($check_id, $profile_id);
	}
}

#
# _ns_ex_id_is_valid(subkeys, level, create)
#
# Return non-zero if exception ID specified by SUBKEYS and LEVEL exists.
#
sub _ns_ex_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];
	my $check_id = $subkeys->[2];
	my $ex_id = $subkeys->[4];

	if ($create) {
		return db_check_ex_exists($check_id, $ex_id) ||
		       config_check_ex_exists($check_id, $ex_id, $profile_id);
	} else {
		return config_check_ex_exists($check_id, $ex_id, $profile_id);
	}
}

#
# _ns_cons_ids_get(subkeys, level, create)
#
# Return list of consumer IDs.
#
sub _ns_cons_ids_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];

	if ($create) {
		# Return list of installed consumer IDs
		return db_cons_get_ids();
	} else {
		# Return list of consumer IDs for which there is configuration
		# data available
		return config_cons_get_ids($profile_id);
	}
}

#
# _ns_cons_id_is_valid(subkeys, level, create)
#
# Return non-zero if consumer ID specified by SUBKEYS and LEVEL exists.
#
sub _ns_cons_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $profile_id = $subkeys->[0];
	my $cons_id = $subkeys->[$level];

	if ($create) {
		# Check if consumer with specified ID is installed
		return db_cons_exists($cons_id) ||
		       config_cons_exists($cons_id, $profile_id);
	} else {
		# Check if there is configuration data available for consumer
		# with specified ID
		return config_cons_exists($cons_id, $profile_id);
	}
}

#
# _get_property_ids(key[, expand[,create[, skip_invalid[, err_prefix]]]])
#
# Return list of IDs of the properties specified by KEY.
#
sub _get_property_ids($;$$$$)
{
	my ($key, $expand, $create, $skip_invalid, $err_prefix) = @_;
	my ($err_msg, $result);

	$expand = $PROP_EXP_NEVER if (!defined($expand));
	($err_msg, $result) = prop_parse_key(\%_PDEF_MAP, \%_PDEF_NS, $expand,
					     $create, $skip_invalid, $key);
	if (defined($err_msg)) {
		if (!defined($err_prefix)) {
			$err_prefix = "Property key '$key': ";
		}
		die($err_prefix.$err_msg."\n");
	}

	if ($opt_debug) {
		my $prop_id;

		foreach $prop_id (@$result) {
			my ($tag, @sub_ids) = @$prop_id;
			debug("tag=$tag sub_ids=".join(",", @sub_ids)."\n");
		}
	}
	return @$result;
}

#
# _get_property_value(prop_id)
#
# Return value of property PROP_ID.
#
sub _get_property_value($)
{
	my ($prop_id) = @_;
	my ($tag, @subids) = @$prop_id;
	my $profile_id = $subids[0];
	my $profile = db_profile_get($profile_id);

	if ($tag == $_PROP_ID) {
		return $profile_id;
	} elsif ($tag == $_PROP_DESC) {
		return config_get_desc($profile_id);
	} elsif ($tag == $_PROP_HOST) {
		my $host_num = $subids[1];
		my $hosts = config_hosts_get($profile_id);

		return $hosts->[$host_num];
	} elsif ($tag == $_PROP_CHECK_STATE) {
		my $check_id = $subids[1];

		return config_check_get_state($check_id, $profile_id);
	} elsif ($tag == $_PROP_CHECK_REPEAT) {
		my $check_id = $subids[1];

		return config_check_get_repeat($check_id, $profile_id);
	} elsif ($tag == $_PROP_CHECK_PARAM_VALUE) {
		my $check_id = $subids[1];
		my $param_id = $subids[2];

		return config_check_get_param($check_id, $param_id,
					     $profile_id);
	} elsif ($tag == $_PROP_CHECK_EX_SEVERITY) {
		my $check_id = $subids[1];
		my $ex_id = $subids[2];

		return config_check_get_ex_severity($check_id, $ex_id,
						    $profile_id);
	} elsif ($tag == $_PROP_CHECK_EX_STATE) {
		my $check_id = $subids[1];
		my $ex_id = $subids[2];

		return config_check_get_ex_state($check_id, $ex_id,
						 $profile_id);
	} elsif ($tag == $_PROP_CHECK_SI_REC_DURATION) {
		my $check_id = $subids[1];
		my $si_id = $subids[2];

		return config_check_get_si_rec_duration($check_id, $si_id,
							$profile_id);
	} elsif ($tag == $_PROP_CONS_STATE) {
		my $cons_id = $subids[1];

		return config_cons_get_state($cons_id, $profile_id);
	} elsif ($tag == $_PROP_CONS_PARAM_VALUE) {
		my $cons_id = $subids[1];
		my $param_id = $subids[2];

		return config_cons_get_param($cons_id, $param_id, $profile_id);
	} elsif ($tag == $_PROP_FILENAME) {
		return $profile->[$PROFILE_T_FILENAME];
	} elsif ($tag == $_PROP_SYSTEM) {
		return $profile->[$PROFILE_T_SYSTEM];
	}

	# Should not happen
	return undef;
}

#
# _get_property_key(prop_id)
#
# Return key corresponding to property PROP_ID.
#
sub _get_property_key($)
{
	my ($prop_id) = @_;
	my ($tag, @subids) = @$prop_id;
	my $profile_id = $subids[0];

	if ($tag == $_PROP_ID) {
		return $profile_id.".id";
	} elsif ($tag == $_PROP_DESC) {
		return $profile_id.".desc";
	} elsif ($tag == $_PROP_HOST) {
		my $host_num = $subids[1];

		return $profile_id.".host.".$host_num;
	} elsif ($tag == $_PROP_CHECK_STATE) {
		my $check_id = $subids[1];

		return $profile_id.".check.".$check_id.".state";
	} elsif ($tag == $_PROP_CHECK_REPEAT) {
		my $check_id = $subids[1];

		return $profile_id.".check.".$check_id.".repeat";
	} elsif ($tag == $_PROP_CHECK_PARAM_VALUE) {
		my $check_id = $subids[1];
		my $param_id = $subids[2];

		return $profile_id.".check.".$check_id.".param.".$param_id.
		       ".value";
	} elsif ($tag == $_PROP_CHECK_EX_SEVERITY) {
		my $check_id = $subids[1];
		my $ex_id = $subids[2];

		return $profile_id.".check.".$check_id.".ex.".$ex_id.".sev";
	} elsif ($tag == $_PROP_CHECK_EX_STATE) {
		my $check_id = $subids[1];
		my $ex_id = $subids[2];

		return $profile_id.".check.".$check_id.".ex.".$ex_id.".state";
	} elsif ($tag == $_PROP_CHECK_SI_REC_DURATION) {
		my $check_id = $subids[1];
		my $si_id = $subids[2];

		return $profile_id.".check.".$check_id.".si.".$si_id.
		       ".rec_duration";
	} elsif ($tag == $_PROP_CONS_STATE) {
		my $cons_id = $subids[1];

		return $profile_id.".cons.".$cons_id.".state";
	} elsif ($tag == $_PROP_CONS_PARAM_VALUE) {
		my $cons_id = $subids[1];
		my $param_id = $subids[2];

		return $profile_id.".cons.".$cons_id.".param.".$param_id.
		       ".value";
	} elsif ($tag == $_PROP_FILENAME) {
		return $profile_id.".filename";
	} elsif ($tag == $_PROP_SYSTEM) {
		return $profile_id.".system";
	}

	# Should not happen
	return undef;
}

#
# profile_select_all()
#
# Select all profiles.
#
sub profile_select_all()
{
	my @profile_ids = db_profile_get_ids();
	my $profile_id;

	foreach $profile_id (@profile_ids) {
		$_selected_profile_ids{$profile_id} = 1;
	}
	$_selection_active = 1;
}

#
# profile_select_none()
#
# Clear profile selection.
#
sub profile_select_none()
{
	%_selected_profile_ids = ();
	$_selection_active = 1;
}

#
# _wildcard_to_profile_ids(wildcard)
#
# Return list of profile IDs which match WILDCARD.
#
sub _wildcard_to_profile_ids($)
{
	my ($wildcard) = @_;
	my $re = $wildcard;
	my @profile_ids;
	my $profile_id;

	$re =~ s/\?/\.\?/g;
	$re =~ s/\*/\.\*/g;

	foreach $profile_id (db_profile_get_ids()) {
		if ($profile_id =~ /^$re$/) {
			push(@profile_ids, $profile_id);
			info2("Profile name '$profile_id' matches ".
			      "'$wildcard'\n");
		}
	}
	info2("Wildcard pattern '$wildcard' matched ".scalar(@profile_ids).
	      " profiles\n");

	return @profile_ids;
}

#
# _match_property_value(prop_id, op, value)
#
# If current value of property PROP_ID matches VALUE according to OP, return
# non-zero. Return zero otherwise.
#
sub _match_property_value($$$)
{
	my ($prop_id, $op, $value) = @_;
	my $actual = _get_property_value($prop_id);
	my ($tag) = @$prop_id;

	# Adjust property name if necessary
	if ($value =~ /^\d+$/) {
		# User specified number format, nothing to do
	} elsif ($tag == $_PROP_CHECK_STATE || $tag == $_PROP_CONS_STATE ||
		 $tag == $_PROP_CHECK_EX_STATE) {
		$actual = state_to_str($actual);
	} elsif ($tag == $_PROP_CHECK_EX_SEVERITY) {
		$actual = sev_to_str($actual);
	}

	info2("Matching '$value' $op '$actual'\n");
	if ($op eq "=") {
		return match_wildcard($actual, $value);
	} elsif ($op eq "!=") {
		return !match_wildcard($actual, $value);
	}

	# Handle unknown operators gracefully
	return 0;
}

#
# _key_to_profile_ids(spec)
#
# Return list of profile IDs for which boolean condition defined by SPEC
# evaluates as true.
#
sub _key_to_profile_ids($)
{
	my ($spec) = @_;
	my $key;
	my $op;
	my $value;
	my $prop_id;
	my $err_prefix;
	my @profile_ids;
	my $profile_id;

	if (!($spec =~ /^([$MATCH_ID_CHAR\.\*]+)(=|!=)(.*)$/)) {
		die("Profile specification '$spec': unrecognized format!\n");
	}
	($key, $op, $value) = ($1, $2, $3);

	# Convert keys into list of property IDs
	$err_prefix = "Profile specification '$key': ";
	foreach $prop_id (_get_property_ids("*.$key", undef, undef, 1,
					    $err_prefix)) {
		if (!_match_property_value($prop_id, $op, $value)) {
			next;
		}
		$profile_id = $prop_id->[$_PROP_ID_T_PROFILE_ID];
		push(@profile_ids, $profile_id);

		info2("Profile '$profile_id' matches '$key$op$value'\n");
	}

	info2("Keyword $key$op$value matched ".scalar(@profile_ids).
	      " profiles\n");

	return @profile_ids;
}

#
# profile_select(spec, intersect, nonex)
#
# Select profiles specified by SPEC. If INTERSECT is non-zero, change selection
# to include only those profiles which have been selected before and would be
# selected by SPEC. If NONEX is non-zero, allow selecting profiles which do
# not exist.
#
sub profile_select($$$)
{
	my ($spec, $intersect, $nonex) = @_;
	my @profile_ids;
	my $profile_id;
	my $type = get_spec_type($spec);

	if ($type == $SPEC_T_ID) {
		# This specification is a ID
		if (!db_profile_exists($spec) && !$nonex) {
			warn("Profile '$spec' does not exist - skipping\n");
			return;
		}
		@profile_ids = ($spec);
	} elsif ($type == $SPEC_T_WILDCARD) {
		# This specification contains shell wildcards (? and *)
		@profile_ids = _wildcard_to_profile_ids($spec);
	} elsif ($type == $SPEC_T_KEY) {
		# This specification consists of a key, operator, value
		# statement
		@profile_ids = _key_to_profile_ids($spec);
	} else {
		die("Unrecognized profile specification: '$spec'\n");
	}

	if ($intersect) {
		my %new_sel;

		# Create new selection containing intersection of both sets
		foreach $profile_id (@profile_ids) {
			if ($_selected_profile_ids{$profile_id}) {
				$new_sel{$profile_id} = 1;
			}
		}

		# Replace existing selection with intersection
		%_selected_profile_ids = %new_sel;
	} else {
		# Apply list to selection
		foreach $profile_id (@profile_ids) {
			$_selected_profile_ids{$profile_id} = 1;
		}
	}

	$_selection_active = 1;
}

#
# profile_selection_is_empty()
#
# Return non-zero of no profile has been selected.
#
sub profile_selection_is_empty()
{
	if (!%_selected_profile_ids) {
		return 1;
	}

	return 0;
}

#
# profile_new(profile_id)
#
# Add a new, empty profile with the specified PROFILE_ID to the database.
#
sub profile_new($)
{
	my ($profile_id) = @_;

	validate_id("profile name", $profile_id);
	info("Creating empty profile '$profile_id' in ".get_db_scope().
	     " database\n");
	db_profile_new($profile_id);
}

#
# profile_clear()
#
# Clear selected profiles.
#
sub profile_clear()
{
	my @profile_ids = _get_ids(1);
	my $profile_id;

	foreach $profile_id (@profile_ids) {
		info("Clearing configuration data of profile '$profile_id'\n");
		config_clear($profile_id);
	}
}

#
# profile_set_defaults()
#
# Set configuration for selected profiles to default values.
#
sub profile_set_defaults()
{
	my @profile_ids = _get_ids(1);
	my $profile_id;

	foreach $profile_id (@profile_ids) {
		info("Setting default configuration values for profile ".
		      "'$profile_id'\n");
		config_set_defaults($profile_id);
	}
}

#
# profile_set_desc(desc[, profile_id[, quiet]])
#
# Set profile description for selected profiles to DESC.
#
sub profile_set_desc($;$$)
{
	my ($desc, $profile_id, $quiet) = @_;

	if (!defined($profile_id)) {
		$profile_id = _get_id();
	}
	if (!$quiet) {
		info("Changing description of profile '$profile_id'\n");
	}
	config_set_desc($desc, $profile_id);
}

#
# profile_rename(new_id[, profile-id[, quiet]])
#
# Rename specified or selected profile to NEW_ID.
#
sub profile_rename($;$$)
{
	my ($new_id, $profile_id, $quiet) = @_;
	my $profile;

	if (!defined($profile_id)) {
		$profile_id = _get_id();
	}
	$profile = db_profile_get($profile_id, 1);
	if (defined($profile)) {
		check_opt_system($profile->[$PROFILE_T_SYSTEM],
				 "profile '$profile_id'");
	}
	if ($new_id eq $profile_id) {
		warn("New profile ID '$new_id' is the same as the old ID - ".
		     "skipping!\n");
		return;
	}
	if (db_profile_exists($new_id)) {
		die("Cannot rename profile '$profile_id' to existing profile ".
		    "ID '$new_id'!\n");
	}
	validate_id("profile name", $new_id);
	if (!$quiet) {
		info("Renaming profile '$profile_id' to '$new_id'\n");
	}
	db_profile_rename($profile_id, $new_id);
}

#
# profile_delete()
#
# Delete selected profiles from database.
#
sub profile_delete()
{
	my $profile_id;

	# Abort before any profile is deleted if active profile is selected
	$profile_id = db_profile_get_active_id();
	if ($_selected_profile_ids{$profile_id}) {
		die("Cannot delete active profile '$profile_id'!\n");
	}

	foreach $profile_id (profile_get_selected_ids()) {
		info("Deleting ".get_db_scope()." profile '$profile_id'\n");
		db_profile_uninstall($profile_id);
	}
}

#
# profile_copy(new_id)
#
# Create a profile copy with specified ID NEW_ID.
#
sub profile_copy($)
{
	my ($new_id) = @_;
	my $profile_id;

	$profile_id = _get_id();
	if ($profile_id eq $new_id) {
		die("Cannot copy profile '$profile_id' onto itself!\n");
	}
	if (db_profile_exists($new_id)) {
		die("Cannot copy profile '$profile_id' on existing profile ".
		    "'$new_id'!\n");
	}
	validate_id("profile name", $new_id);
	info("Copying profile '$profile_id' to new profile '$new_id' in ".
	     get_db_scope()." database\n");
	db_profile_copy($profile_id, $new_id);
}

#
# profile_merge(source_id)
#
# Merge contents of active or selected profile with data from profile SOURCE_ID.
#
sub profile_merge($)
{
	my ($source_id) = @_;
	my $target_id = _get_id();

	info("Merging configuration data from profile '$source_id' ".
	      "to '$target_id'\n");
	db_profile_merge($source_id, $target_id);
}

#
# _print_property_short(prop_id[, handle])
#
# Print property with specified ID in short form. Return non-zero if a value
# was defined for this key, zero otherwise.
#
sub _print_property_short($;*)
{
	my ($prop_id, $handle) = @_;
	my ($tag) = @$prop_id;
	my $value;
	my $key;

	if (!defined($handle)) {
		$handle = *STDOUT;
	}
	$value = _get_property_value($prop_id);
	if (!defined($value)) {
		return 0;
	}
	$key = _get_property_key($prop_id);

	print($handle "$key=");
	if ($tag == $_PROP_DESC) {
		my $line;

		print($handle "\n");
		foreach $line (split(/\n/, $value)) {
			print($handle "|$line\n");
		}
	} else {
		print($handle "$value\n");
	}

	return 1;
}

#
# _prop_cmp(a, b)
#
# Compare function for two profile property IDs.
#
sub _prop_cmp($$)
{
	my ($a, $b) = @_;
	my ($tag_a, $profile_id_a, $sub_id1_a, $sub_id2_a) = @$a;
	my ($tag_b, $profile_id_b, $sub_id1_b, $sub_id2_b) = @$b;
	my $metaclass_a = $_PROP_METACLASS{$tag_a};
	my $metaclass_b = $_PROP_METACLASS{$tag_b};
	my $class_a = $_PROP_CLASS{$tag_a};
	my $class_b = $_PROP_CLASS{$tag_b};

	# First sort characteristics: profile ID
	if ($profile_id_a ne $profile_id_b) {
		return $profile_id_a cmp $profile_id_b;
	}

	# Second sort characteristics: property meta-class
	if ($metaclass_a != $metaclass_b) {
		return $metaclass_a <=> $metaclass_b;
	}

	if ($class_a == $_PROP_CLASS_HOST) {
		# Special case: compare host numbers numerically
		return $sub_id1_a <=> $sub_id1_b;
	}

	# Third sort characteristics: first sub IDs (e.g. check_id, cons_id)
	if (defined($sub_id1_a) && defined($sub_id1_b) &&
	    $sub_id1_a ne $sub_id1_b) {
		return $sub_id1_a cmp $sub_id1_b;
	}

	# Second sort characteristics: property class
	if ($class_a != $class_b) {
		return $class_a <=> $class_b;
	}

	# Fourth sort characteristics: second sub IDs (e.g. param_id, ex_id)
	if (defined($sub_id2_a) && defined($sub_id2_b) &&
	    $sub_id2_a ne $sub_id2_b) {
		return $sub_id2_a cmp $sub_id2_b;
	}

	# Fifth sort characteristic: property ID
	if ($tag_a != $tag_b) {
		return $tag_a <=> $tag_b;
	}

	# Appears to be equal
	return 0;
}

#
# _print_profile_heading(profile)
#
# Print profile heading.
#
sub _print_profile_heading($)
{
	my ($profile) = @_;
	my $profile_id = $profile->[$PROFILE_T_ID];
	my $heading;

	$heading = "Profile $profile_id";

	print("$heading\n");
	print(("="x(length($heading)))."\n");
}

#
# _print_profile_desc(profile)
#
# Print profile description.
#
sub _print_profile_desc($)
{
	my ($profile) = @_;
	my $desc = $profile->[$PROFILE_T_DESC];

	print("Description:\n");
	print(get_indented($desc, 2));
}

#
# _print_profile_data(profile)
#
# Print profile data.
#
sub _print_profile_data($)
{
	my ($profile) = @_;
	my $profile_id = $profile->[$PROFILE_T_ID];
	my $filename = $profile->[$PROFILE_T_FILENAME];
	my $system_str = system_to_str($profile->[$PROFILE_T_SYSTEM]);
	my $active_id = db_profile_get_active_id();

	print("\nProfile data:\n");
	print_padded(2, 24, "Active", $profile_id eq $active_id ? "yes" : "no");
	print_padded(2, 24, "Filename", $filename);
	print_padded(2, 24, "Installation directory", $system_str);
}

#
# _print_profile_check(check_conf)
#
# Print check configuration data.
#
sub _print_profile_check($)
{
	my ($check_conf) = @_;
	my ($check_id, $state, $repeat, $param_conf_db, $ex_conf_db,
	    $si_conf_db) = @$check_conf;

	print("\nCheck $check_id:\n");
	if (defined($state)) {
		print_padded(2, 24, "State", state_to_str($state));
	}
	if (defined($repeat) && $repeat ne "") {
		print_padded(2, 24, "Repeat interval",
			     normalize_duration($repeat));
	}
	if (defined($param_conf_db) && %{$param_conf_db}) {
		print("\n  Parameters:\n");
		foreach my $param_id (sort(keys(%{$param_conf_db}))) {
			my $param_conf = $param_conf_db->{$param_id};
			my $value = $param_conf->[$PARAM_CONF_T_VALUE];

			print_padded(4, 22, $param_id, $value);
		}
	}
	if (defined($ex_conf_db) && %{$ex_conf_db}) {
		print("\n  Exceptions:\n");
		foreach my $ex_id (sort(keys(%{$ex_conf_db}))) {
			my $ex_conf = $ex_conf_db->{$ex_id};
			my $sev = $ex_conf->[$EX_CONF_T_SEVERITY];
			my $state = $ex_conf->[$EX_CONF_T_STATE];

			print("    $ex_id:\n");
			if (defined($sev)) {
				print_padded(6, 20, "Severity",
					     sev_to_str($sev));
			}
			if (defined($state)) {
				print_padded(6, 20, "State",
					     state_to_str($state));
			}
		}
	}
	if (defined($si_conf_db) && %{$si_conf_db}) {
		print("\n  Sysinfo items:\n");
		foreach my $si_id (sort(keys(%{$si_conf_db}))) {
			my $si_conf = $si_conf_db->{$si_id};
			my $type = $si_conf->[$SI_CONF_T_TYPE];
			my $data = $si_conf->[$SI_CONF_T_DATA];

			print("    $si_id:\n");
			if ($type == $SI_TYPE_T_REC) {
				my $rec_duration =
					$data->[$SI_REC_CONF_T_DURATION];
				if (defined($rec_duration) &&
				    $rec_duration ne "") {
					print_padded(6, 20, "Record duration",
						sec_to_duration($rec_duration));
				}
			}
		}
	}

}

#
# _print_profile_checks(profile)
#
# Print profile check data.
#
sub _print_profile_checks($)
{
	my ($profile) = @_;
	my $check_conf_db = $profile->[$PROFILE_T_CHECK_CONF_DB];

	foreach my $check_id (sort(keys(%{$check_conf_db}))) {
		my $check_conf = $check_conf_db->{$check_id};

		_print_profile_check($check_conf);
	}
}

# _print_profile_consumer(cons_conf)
#
# Print consumer configuration data.
#
sub _print_profile_consumer($)
{
	my ($cons_conf) = @_;
	my ($cons_id, $state, $param_conf_db) = @$cons_conf;

	print("\nConsumer $cons_id:\n");
	if (defined($state)) {
		print_padded(2, 24, "State", state_to_str($state));
	}
	if (defined($param_conf_db) && %{$param_conf_db}) {
		print("\n  Parameters:\n");
		foreach my $param_id (sort(keys(%{$param_conf_db}))) {
			my $param_conf = $param_conf_db->{$param_id};
			my $value = $param_conf->[$PARAM_CONF_T_VALUE];

			print_padded(4, 22, $param_id, $value);
		}
	}
}

#
# _print_profile_consumers(profile)
#
# Print profile consumer data.
#
sub _print_profile_consumers($)
{
	my ($profile) = @_;
	my $cons_conf_db = $profile->[$PROFILE_T_CONS_CONF_DB];

	foreach my $cons_id (sort(keys(%{$cons_conf_db}))) {
		my $cons_conf = $cons_conf_db->{$cons_id};

		_print_profile_consumer($cons_conf);
	}
}

#
# _print_details(profile)
#
# Print detailed profile information for profile PROFILE.
#
sub _print_details($)
{
	my ($profile) = @_;

	_print_profile_heading($profile);
	_print_profile_desc($profile);
	_print_profile_data($profile);
	_print_profile_checks($profile);
	_print_profile_consumers($profile);
}

#
# profile_show()
#
# Print detailed profile information for selected profiles.
#
sub profile_show()
{
	my @profile_ids = _get_ids(1);
	my $nl = "";

	foreach my $profile_id (sort(@profile_ids)) {
		my $profile = db_profile_get($profile_id);

		if (!defined($profile)) {
			# Shouldn't happen
			die("No such profile: $profile_id\n");
		}
		print($nl);
		$nl = "\n";
		_print_details($profile);
	}
}

#
# profile_show_property(keys)
#
# Print profile properties specified by KEYS.
#
sub profile_show_property($)
{
	my ($keys) = @_;
	my $key;
	my @prop_ids;
	my $prop_id;
	my $num_printed = 0;

	# Convert keys into list of property IDs
	foreach $key (@$keys) {
		my @list = _get_property_ids($key, $PROP_EXP_ALWAYS);

		if (@list) {
			push(@prop_ids, @list);
		} else {
			warn("Key '$key' matched no properties.\n");
		}
	}

	foreach $prop_id (sort _prop_cmp @prop_ids) {
		_print_property_short($prop_id) and $num_printed++;
	}
	if (scalar(@prop_ids) > 0 && $num_printed == 0) {
		if (scalar(@$keys) > 1) {
			warn("No data available for the specified keys.\n");
		} else {
			warn("No data available for the specified key.\n");
		}
	}
}

#
# profile_list()
#
# Display a list of all available profiles.
#
sub profile_list()
{
	my @profile_ids = _get_ids(1, 1);
	my $profile_id;
	my $active_id = db_profile_get_active_id();
	my $layout = [
		[
			# min   max     weight  align 		delim
			[ 20,	40,	1,	$ALIGN_T_LEFT,	" " ],
			[ 6,	6,	0,	$ALIGN_T_LEFT,	" " ],
			[ 52,	undef,	1,	$ALIGN_T_LEFT,	"" ],
		]
	];

	# Print heading
	lprintf($layout, "PROFILE NAME", "ACTIVE", "DESCRIPTION");
	print("\n".("="x(layout_get_width($layout)))."\n");

	foreach $profile_id (@profile_ids) {
		my $desc;
		my $act;

		# Get description
		$desc = config_get_desc($profile_id);
		$desc = get_indented($desc, 25);
		$desc =~ s/^\s*//;
		$desc =~ s/\n+$//;

		if ($profile_id eq $active_id) {
			$act = "yes";
		} else {
			$act = "";
		}

		lprintf($layout, $profile_id, $act, $desc);
		print("\n");
	}
}

#
# _set_property_value(prop_id, value[, quiet])
#
# Set value of property PROP_ID to VALUE.
#
sub _set_property_value($$;$)
{
	my ($prop_id, $value, $quiet) = @_;
	my ($tag, @subids) = @$prop_id;
	my $profile_id = $subids[0];

	if ($tag == $_PROP_ID) {
		profile_rename($value, $profile_id, $quiet);
	} elsif ($tag == $_PROP_DESC) {
		profile_set_desc($value, $profile_id, $quiet);
	} elsif ($tag == $_PROP_HOST) {
		my $host_num = $subids[1];

		if (!$quiet) {
			info("Replacing host list entry $host_num with ".
			      "'$value'\n");
		}
		config_host_replace_by_num($value, $host_num, $profile_id);
	} elsif ($tag == $_PROP_CHECK_STATE) {
		my $check_id = $subids[1];
		my $state = str_to_state($value);
		my $state_str = state_to_str($state);

		if (!$quiet) {
			info("Setting check activation state of '$check_id' ".
			      "to '$state_str'\n");
		}
		config_check_set_state($check_id, $state, $profile_id);
	} elsif ($tag == $_PROP_CHECK_REPEAT) {
		my $check_id = $subids[1];

		validate_duration($value, 1);

		if (!$quiet) {
			info("Setting check repeat setting of '$check_id' to ".
			      "'$value'\n");
		}
		config_check_set_repeat($check_id, $value, $profile_id);
	} elsif ($tag == $_PROP_CHECK_PARAM_VALUE) {
		my $check_id = $subids[1];
		my $param_id = $subids[2];

		if (!$quiet) {
			info("Setting check parameter '$check_id.$param_id' ".
			      "to '$value'\n");
		}
		config_check_set_param($check_id, $param_id, $value,
				       $profile_id);
	} elsif ($tag == $_PROP_CHECK_EX_SEVERITY) {
		my $check_id = $subids[1];
		my $ex_id = $subids[2];
		my $sev = str_to_sev($value);
		my $sev_str = sev_to_str($sev);

		if (!$quiet) {
			info("Setting exception severity of ".
			      "'$check_id.$ex_id' to '$sev_str'\n");
		}
		config_check_set_ex_severity($check_id, $ex_id, $sev,
					     $profile_id);
	} elsif ($tag == $_PROP_CHECK_EX_STATE) {
		my $check_id = $subids[1];
		my $ex_id = $subids[2];
		my $state = str_to_state($value);

		if (!$quiet) {
			info("Setting exception state of '$check_id.$ex_id' ".
			      "to '$value'\n");
		}
		config_check_set_ex_state($check_id, $ex_id, $state,
					  $profile_id);
	} elsif ($tag == $_PROP_CHECK_SI_REC_DURATION) {
		my $check_id = $subids[1];
		my $si_id = $subids[2];

		# Check for valid duration
		validate_duration($value, 0);

		if (!$quiet) {
			info("Setting sysinfo record item duration of ".
			      "'$check_id.$si_id' to '$value'\n");
		}
		config_check_set_si_rec_duration($check_id, $si_id, $value,
						 $profile_id);
	} elsif ($tag == $_PROP_CONS_STATE) {
		my $cons_id = $subids[1];
		my $state = str_to_state($value);
		my $state_str = state_to_str($state);

		if (!$quiet) {
			info("Setting consumer activation state of ".
			      "'$cons_id' to '$state_str'\n");
		}
		config_cons_set_state($cons_id, $state, $profile_id);
	} elsif ($tag == $_PROP_CONS_PARAM_VALUE) {
		my $cons_id = $subids[1];
		my $param_id = $subids[2];

		if (!$quiet) {
			info("Setting consumer parameter '$param_id' to ".
			      "'$value'\n");
		}
		config_cons_set_param($cons_id, $param_id, $value, $profile_id);
	} else {
		die("Property '"._get_property_key($prop_id)."' cannot be ".
		    "modified!\n");
	}
}

#
# profile_set_property(key, value)
#
# Set value of profile properties identified by KEY to VALUE.
#
sub profile_set_property($$)
{
	my ($key, $value) = @_;
	my @prop_ids;
	my $prop_id;

	# Convert keys into list of property IDs
	@prop_ids = _get_property_ids($key, $PROP_EXP_NEVER, 1);

	if (!@prop_ids) {
		warn("Key '$key' matched no properties.\n");
		return;
	}

	foreach $prop_id (@prop_ids) {
		_set_property_value($prop_id, $value);
		if ($opt_debug) {
			_print_property_short($prop_id);
		}
	}
}

#
# _remove_property(prop_id)
#
# Remove property PROP_ID.
#
sub _remove_property_value($)
{
	my ($prop_id) = @_;
	my ($tag, @subids) = @$prop_id;
	my $profile_id = $subids[0];

	if ($tag == $_PROP_HOST) {
		my $host_num = $subids[1];
		my $host = $subids[2];

		if (defined($host)) {
			info("Removing host list entry $host_num: '$host'\n");
			config_host_remove($host, $profile_id);
		} else {
			info("Removing host list entry $host_num\n");
			config_host_remove_by_num($host_num, $profile_id);
		}
	} elsif ($tag == $_PROP_CHECK_STATE) {
		my $check_id = $subids[1];

		info("Removing check activation state for '$check_id'\n");
		config_check_del_state($check_id, $profile_id);
	} elsif ($tag == $_PROP_CHECK_REPEAT) {
		my $check_id = $subids[1];

		info("Removing check repeat setting for '$check_id'\n");
		config_check_del_repeat($check_id, $profile_id);
	} elsif ($tag == $_PROP_CHECK_PARAM_VALUE) {
		my $check_id = $subids[1];
		my $param_id = $subids[2];

		info("Removing check parameter value '$check_id.$param_id'\n");
		config_check_del_param_value($check_id, $param_id, $profile_id);
	} elsif ($tag == $_PROP_CHECK_EX_SEVERITY) {
		my $check_id = $subids[1];
		my $ex_id = $subids[2];

		info("Removing exception severity for '$check_id.$ex_id'\n");
		config_check_del_ex_severity($check_id, $ex_id, $profile_id);
	} elsif ($tag == $_PROP_CHECK_EX_STATE) {
		my $check_id = $subids[1];
		my $ex_id = $subids[2];

		info("Removing exception activation state for ".
		      "'$check_id.$ex_id'\n");
		config_check_del_ex_state($check_id, $ex_id, $profile_id);
	} elsif ($tag == $_PROP_CHECK_SI_REC_DURATION) {
		my $check_id = $subids[1];
		my $si_id = $subids[2];

		info("Removing sysinfo record duration for ".
		      "'$check_id.$si_id'\n");
		config_check_del_si_rec_duration($check_id, $si_id,
						 $profile_id);
	} elsif ($tag == $_PROP_CONS_STATE) {
		my $cons_id = $subids[1];

		info("Removing consumer activation state for '$cons_id'\n");
		config_cons_del_state($cons_id, $profile_id);
	} elsif ($tag == $_PROP_CONS_PARAM_VALUE) {
		my $cons_id = $subids[1];
		my $param_id = $subids[2];

		info("Removing consumer parameter value ".
		      "'$cons_id.$param_id'\n");
		config_cons_del_param_value($cons_id, $param_id, $profile_id);
	} else {
		die("Property '"._get_property_key($prop_id)."' cannot be ".
		    "removed!\n");
	}
}

#
# _extend_ids(prop_ids)
#
# Replace all number sub-IDs in PROP_IDS with their actual ID. This is
# necessary for remove operations since removal of an entity changes the
# number of the following entities.
#
sub _extend_ids($)
{
	my ($prop_ids) = @_;
	my $prop_id;

	foreach $prop_id (@$prop_ids) {
		my ($tag, $profile_id, $host_num) = @$prop_id;

		if ($tag != $_PROP_HOST) {
			next;
		}
		$prop_id->[3] = config_host_get_by_num($host_num, $profile_id);
	}
}

#
# profile_remove_properties(keys)
#
# Remove profile properties specified by KEYS.
#
sub profile_remove_properties($)
{
	my ($keys) = @_;
	my $key;
	my @prop_ids;
	my $prop_id;
	my $last_key;
	my $num_removed = 0;

	# Convert keys into list of property IDs
	foreach $key (@$keys) {
		my @list = _get_property_ids($key, $PROP_EXP_ALWAYS);

		if (!@list) {
			warn("Key '$key' matched no properties\n");
			next;
		}

		push(@prop_ids, @list);
	}

	_extend_ids(\@prop_ids);
	foreach $prop_id (sort _prop_cmp @prop_ids) {
		my $this_key = _get_property_key($prop_id);

		# Sort out duplicate keys
		if (defined($last_key) && $this_key eq $last_key) {
			next;
		}
		$last_key = $this_key;
		next if (!defined(_get_property_value($prop_id)));
		_remove_property_value($prop_id);
		$num_removed++;
	}

	if (scalar(@prop_ids) > 0 && $num_removed == 0) {
		if (scalar(@$keys) > 1) {
			warn("No data available for the specified keys.\n");
		} else {
			warn("No data available for the specified key.\n");
		}
	}
}

#
# profile_export(filename)
#
# Export profile data to file FILENAME.
#
sub profile_export($)
{
	my ($filename) = @_;
	my $profile_id = _get_id();

	# Select output handle
	if ($filename eq "-") {
		info("Exporting profile '$profile_id' to standard output\n");
	} else {
		info("Exporting profile '$profile_id' to file '$filename'\n");
	}

	db_profile_export($filename, $profile_id);
}

#
# profile_import(filename[, merge])
#
# Import profile data from file FILENAME.
#
sub profile_import($;$)
{
	my ($filename, $merge) = @_;
	my $profile_id = _get_id();
	my $source;
	my $profile = db_profile_get($profile_id, 1);

	if (defined($profile)) {
		check_opt_system($profile->[$PROFILE_T_SYSTEM],
				 "profile '$profile_id'");
	}

	if ($filename eq "-") {
		$source = "standard input";
	} else {
		$source = "file '$filename'";
	}

	if ($merge) {
		info("Merging data from $source to profile '$profile_id'\n");
	} else {
		info("Importing data from $source to profile '$profile_id' in ".
		     get_db_scope()." database\n");
	}

	db_profile_import($filename, $profile_id, $merge);
}

#
# profile_activate(profile_id)
#
# Activate profile PROFILE_ID.
#
sub profile_activate($)
{
	my ($profile_id) = @_;
	my $profile;

	$profile = db_profile_get($profile_id);
	if ($profile->[$PROFILE_T_SYSTEM]) {
		info("Activating system-wide profile '$profile_id'\n");
		info("Note: You must specify --system to modify this ".
		     "profile\n");
	} else {
		info("Activating user profile '$profile_id'\n");
	}
	db_profile_set_active_id($profile_id);
}


#
# Code entry
#

# Indicate successful module initialization
1;
