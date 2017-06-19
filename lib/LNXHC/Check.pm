#
# LNXHC::Check.pm
#   Linux Health Checker support functions for handling check related data
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

package LNXHC::Check;

use strict;
use warnings;

use Exporter qw(import);
use File::Basename qw(basename);


#
# Local imports
#
use LNXHC::Config qw(config_check_get_active_ids config_check_get_ex_severity
		     config_check_get_ex_severity_or_default
		     config_check_get_ex_state
		     config_check_get_ex_state_or_default config_check_get_param
		     config_check_get_param_or_default config_check_get_repeat
		     config_check_get_repeat_or_default
		     config_check_get_si_rec_duration
		     config_check_get_si_rec_duration_or_default
		     config_check_get_state config_check_get_state_or_default
		     config_check_set_defaults config_check_set_ex_severity
		     config_check_set_ex_state config_check_set_param
		     config_check_set_repeat config_check_set_si_rec_duration
		     config_check_set_state);
use LNXHC::Consts qw($CHECK_DIR_VAR $CHECK_T_AUTHORS $CHECK_T_COMPONENT
		     $CHECK_T_DEPS $CHECK_T_DESC $CHECK_T_DIR
		     $CHECK_T_EXTRAFILES $CHECK_T_EX_DB $CHECK_T_ID
		     $CHECK_T_MULTIHOST $CHECK_T_MULTITIME $CHECK_T_PARAM_DB
		     $CHECK_T_REPEAT $CHECK_T_SI_DB $CHECK_T_STATE
		     $CHECK_T_SYSTEM $CHECK_T_TITLE $DEP_T_DEP
		     $EXCEPTION_T_EXPLANATION $EXCEPTION_T_ID
		     $EXCEPTION_T_REFERENCE $EXCEPTION_T_SEVERITY
		     $EXCEPTION_T_SOLUTION $EXCEPTION_T_STATE
		     $EXCEPTION_T_SUMMARY $MATCH_ID $MATCH_ID_CHAR
		     $MATCH_ID_WILDCARD $PARAM_T_DESC $PARAM_T_VALUE
		     $PROP_EXP_ALWAYS $PROP_EXP_NEVER $SI_FILE_DATA_T_FILENAME
		     $SI_FILE_DATA_T_USER $SI_PROG_DATA_T_CMDLINE
		     $SI_PROG_DATA_T_EXTRAFILES $SI_PROG_DATA_T_IGNORERC
		     $SI_PROG_DATA_T_USER $SI_REC_DATA_T_DURATION
		     $SI_REC_DATA_T_EXTRAFILES $SI_REC_DATA_T_START
		     $SI_REC_DATA_T_STOP $SI_REC_DATA_T_USER
		     $SI_REF_DATA_T_CHECK $SI_REF_DATA_T_SYSINFO $SI_TYPE_T_EXT
		     $SI_TYPE_T_FILE $SI_TYPE_T_PROG $SI_TYPE_T_REC
		     $SI_TYPE_T_REF $SPEC_T_ID $SPEC_T_KEY $SPEC_T_WILDCARD
		     $SYSINFO_T_DATA $SYSINFO_T_TYPE $CAT_TOOL);
use LNXHC::DBCheck qw(db_check_ex_exists db_check_exists db_check_get
		      db_check_get_ex_ids db_check_get_ids
		      db_check_get_param_ids db_check_get_si_ids
		      db_check_get_si_type db_check_install
		      db_check_param_exists db_check_si_exists
		      db_check_uninstall);
use LNXHC::Misc qw($opt_debug $opt_system debug filter_ids_by_wildcard
		   get_indented get_spec_type info info2 match_wildcard
		   print_indented print_padded sev_to_str si_type_to_str
		   state_to_str str_to_sev str_to_state validate_duration
		   validate_duration_nodie yesno_to_str unique);
use LNXHC::Prop qw(prop_parse_key);
use LNXHC::Util qw($ALIGN_T_LEFT format_as_text layout_get_width lprintf);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&check_get_data_id &check_get_num_selected
		    &check_get_selected_ids &check_get_si_data_id &check_info
		    &check_install &check_list &check_resolve_si_ref
		    &check_select &check_select_all &check_select_none
		    &check_selection_is_active &check_selection_is_empty
		    &check_set_defaults &check_set_ex_severity
		    &check_set_ex_state &check_set_param &check_set_property
		    &check_set_si_rec_duration &check_set_state &check_show
		    &check_show_data_id &check_show_property &check_uninstall
		    &check_show_sudoers);


#
# Constants
#

# Check property tags
# <check_id>.id
my $_PROP_ID				= 0;
# <check_id>.title
my $_PROP_TITLE				= 1;
# <check_id>.desc
my $_PROP_DESC				= 2;
# <check_id>.author.<author_num>
my $_PROP_AUTHOR			= 3;
# <check_id>.default_state
my $_PROP_DEFAULT_STATE			= 4;
# <check_id>.state
my $_PROP_STATE				= 5;
# <check_id>.component
my $_PROP_COMPONENT			= 6;
# <check_id>.default_repeat
my $_PROP_DEFAULT_REPEAT		= 7;
# <check_id>.repeat
my $_PROP_REPEAT			= 8;
# <check_id>.multihost
my $_PROP_MULTIHOST			= 9;
# <check_id>.multitime
my $_PROP_MULTITIME			= 10;
# <check_id>.dir
my $_PROP_DIR				= 11;
# <check_id>.extrafile.<extrafile_num>
my $_PROP_EXTRAFILE			= 12;
# <check_id>.dep.<dep_num>
my $_PROP_DEP				= 13;
# <check_id>.param.<param_id>.id
my $_PROP_PARAM_ID			= 14;
# <check_id>.param.<param_id>.desc
my $_PROP_PARAM_DESC			= 15;
# <check_id>.param.<param_id>.default_value
my $_PROP_PARAM_DEFAULT_VALUE		= 16;
# <check_id>.param.<param_id>.value
my $_PROP_PARAM_VALUE			= 17;
# <check_id>.si.<si_id>.id
my $_PROP_SI_ID				= 18;
# <check_id>.si.<si_id>.type
my $_PROP_SI_TYPE			= 19;
# <check_id>.si.<si_id>.file_filename
my $_PROP_SI_FILE_FILENAME		= 20;
# <check_id>.si.<si_id>.file_user
my $_PROP_SI_FILE_USER			= 21;
# <check_id>.si.<si_id>.prog_cmdline
my $_PROP_SI_PROG_CMDLINE		= 22;
# <check_id>.si.<si_id>.prog_user
my $_PROP_SI_PROG_USER			= 23;
# <check_id>.si.<si_id>.prog_ignorerc
my $_PROP_SI_PROG_IGNORERC		= 24;
# <check_id>.si.<si_id>.prog_extrafile.<prog_extrafile_num>
my $_PROP_SI_PROG_EXTRAFILE		= 25;
# <check_id>.si.<si_id>.rec_start
my $_PROP_SI_REC_START			= 26;
# <check_id>.si.<si_id>.rec_stop
my $_PROP_SI_REC_STOP			= 27;
# <check_id>.si.<si_id>.rec_default_duration
my $_PROP_SI_REC_DEFAULT_DURATION	= 28;
# <check_id>.si.<si_id>.rec_duration
my $_PROP_SI_REC_DURATION		= 29;
# <check_id>.si.<si_id>.rec_user
my $_PROP_SI_REC_USER			= 30;
# <check_id>.si.<si_id>.rec_extrafile.<rec_extrafile_num>
my $_PROP_SI_REC_EXTRAFILE		= 31;
# <check_id>.si.<si_id>.ref_check_id
my $_PROP_SI_REF_CHECK_ID		= 32;
# <check_id>.si.<si_id>.ref_si_id
my $_PROP_SI_REF_SI_ID			= 33;
# <check_id>.ex.<ex_id>.id
my $_PROP_EX_ID				= 34;
# <check_id>.ex.<ex_id>.default_sev
my $_PROP_EX_DEFAULT_SEVERITY		= 35;
# <check_id>.ex.<ex_id>.sev
my $_PROP_EX_SEVERITY			= 36;
# <check_id>.ex.<ex_id>.default_state
my $_PROP_EX_DEFAULT_STATE		= 37;
# <check_id>.ex.<ex_id>.state
my $_PROP_EX_STATE			= 38;
# <check_id>.ex.<ex_id>.summary
my $_PROP_EX_SUMMARY			= 39;
# <check_id>.ex.<ex_id>.explanation
my $_PROP_EX_EXPLANATION		= 40;
# <check_id>.ex.<ex_id>.solution
my $_PROP_EX_SOLUTION			= 41;
# <check_id>.ex.<ex_id>.reference
my $_PROP_EX_REFERENCE			= 42;
# <check_id>.system
my $_PROP_SYSTEM			= 43;

# Property ID type definition
my $_PROP_ID_T_TAG			= 0;
my $_PROP_ID_T_CHECK_ID			= 1;
my $_PROP_ID_T_AUTHOR_NUM		= 2;
my $_PROP_ID_T_EXTRAFILE_NUM		= 2;
my $_PROP_ID_T_DEP_NUM			= 2;
my $_PROP_ID_T_PARAM_ID			= 2;
my $_PROP_ID_T_SI_ID			= 2;
my $_PROP_ID_T_EX_ID			= 2;
my $_PROP_ID_T_SI_PROG_EXTRAFILE_NUM	= 3;
my $_PROP_ID_T_SI_REC_EXTRAFILE_NUM	= 3;

# Mark parameter tags (used during sort)
my %_PARAM_TAGS = (
	$_PROP_PARAM_ID			=> 1,
	$_PROP_PARAM_DESC		=> 1,
	$_PROP_PARAM_DEFAULT_VALUE	=> 1,
	$_PROP_PARAM_VALUE		=> 1,
);

# Mark sysinfo tags (used during sort)
my %_SI_TAGS = (
	$_PROP_SI_ID			=> 1,
	$_PROP_SI_TYPE			=> 1,
	$_PROP_SI_FILE_FILENAME		=> 1,
	$_PROP_SI_FILE_USER		=> 1,
	$_PROP_SI_PROG_CMDLINE		=> 1,
	$_PROP_SI_PROG_USER		=> 1,
	$_PROP_SI_PROG_IGNORERC		=> 1,
	$_PROP_SI_PROG_EXTRAFILE	=> 1,
	$_PROP_SI_REC_START		=> 1,
	$_PROP_SI_REC_STOP		=> 1,
	$_PROP_SI_REC_DEFAULT_DURATION	=> 1,
	$_PROP_SI_REC_DURATION		=> 1,
	$_PROP_SI_REC_USER		=> 1,
	$_PROP_SI_REC_EXTRAFILE		=> 1,
	$_PROP_SI_REF_CHECK_ID		=> 1,
	$_PROP_SI_REF_SI_ID		=> 1,
);

# Mark exception tags (used during sort)
my %_EX_TAGS = (
	$_PROP_EX_ID			=> 1,
	$_PROP_EX_DEFAULT_SEVERITY	=> 1,
	$_PROP_EX_SEVERITY		=> 1,
	$_PROP_EX_DEFAULT_STATE		=> 1,
	$_PROP_EX_STATE			=> 1,
	$_PROP_EX_SUMMARY		=> 1,
	$_PROP_EX_EXPLANATION		=> 1,
	$_PROP_EX_SOLUTION		=> 1,
	$_PROP_EX_REFERENCE		=> 1,
);

# Check property definition map: keydef => prop_tag
our  %_PDEF_MAP = (
	"<check_id>.id"
		=> $_PROP_ID,
	"<check_id>.title"
		=> $_PROP_TITLE,
	"<check_id>.desc"
		=> $_PROP_DESC,
	"<check_id>.author.<author_num>"
		=> $_PROP_AUTHOR,
	"<check_id>.default_state"
		=> $_PROP_DEFAULT_STATE,
	"<check_id>.state"
		=> $_PROP_STATE,
	"<check_id>.component"
		=> $_PROP_COMPONENT,
	"<check_id>.default_repeat"
		=> $_PROP_DEFAULT_REPEAT,
	"<check_id>.repeat"
		=> $_PROP_REPEAT,
	"<check_id>.multihost"
		=> $_PROP_MULTIHOST,
	"<check_id>.multitime"
		=> $_PROP_MULTITIME,
	"<check_id>.dir"
		=> $_PROP_DIR,
	"<check_id>.extrafile.<extrafile_num>"
		=> $_PROP_EXTRAFILE,
	"<check_id>.dep.<dep_num>"
		=> $_PROP_DEP,
	"<check_id>.param.<param_id>.id"
		=> $_PROP_PARAM_ID,
	"<check_id>.param.<param_id>.desc"
		=> $_PROP_PARAM_DESC,
	"<check_id>.param.<param_id>.default_value"
		=> $_PROP_PARAM_DEFAULT_VALUE,
	"<check_id>.param.<param_id>.value"
		=> $_PROP_PARAM_VALUE,
	"<check_id>.si.<si_id>.id"
		=> $_PROP_SI_ID,
	"<check_id>.si.<si_id>.type"
		=> $_PROP_SI_TYPE,
	"<check_id>.si.<si_id>.file_filename"
		=> $_PROP_SI_FILE_FILENAME,
	"<check_id>.si.<si_id>.file_user"
		=> $_PROP_SI_FILE_USER,
	"<check_id>.si.<si_id>.prog_cmdline"
		=> $_PROP_SI_PROG_CMDLINE,
	"<check_id>.si.<si_id>.prog_user"
		=> $_PROP_SI_PROG_USER,
	"<check_id>.si.<si_id>.prog_ignorerc"
		=> $_PROP_SI_PROG_IGNORERC,
	"<check_id>.si.<si_id>.prog_extrafile.<si_prog_extrafile_num>"
		=> $_PROP_SI_PROG_EXTRAFILE,
	"<check_id>.si.<si_id>.rec_start"
		=> $_PROP_SI_REC_START,
	"<check_id>.si.<si_id>.rec_stop"
		=> $_PROP_SI_REC_STOP,
	"<check_id>.si.<si_id>.rec_default_duration"
		=> $_PROP_SI_REC_DEFAULT_DURATION,
	"<check_id>.si.<si_id>.rec_duration"
		=> $_PROP_SI_REC_DURATION,
	"<check_id>.si.<si_id>.rec_user"
		=> $_PROP_SI_REC_USER,
	"<check_id>.si.<si_id>.rec_extrafile.<si_rec_extrafile_num>"
		=> $_PROP_SI_REC_EXTRAFILE,
	"<check_id>.si.<si_id>.ref_check_id"
		=> $_PROP_SI_REF_CHECK_ID,
	"<check_id>.si.<si_id>.ref_si_id"
		=> $_PROP_SI_REF_SI_ID,
	"<check_id>.ex.<ex_id>.id"
		=> $_PROP_EX_ID,
	"<check_id>.ex.<ex_id>.default_sev"
		=> $_PROP_EX_DEFAULT_SEVERITY,
	"<check_id>.ex.<ex_id>.sev"
		=> $_PROP_EX_SEVERITY,
	"<check_id>.ex.<ex_id>.default_state"
		=> $_PROP_EX_DEFAULT_STATE,
	"<check_id>.ex.<ex_id>.state"
		=> $_PROP_EX_STATE,
	"<check_id>.ex.<ex_id>.summary"
		=> $_PROP_EX_SUMMARY,
	"<check_id>.ex.<ex_id>.explanation"
		=> $_PROP_EX_EXPLANATION,
	"<check_id>.ex.<ex_id>.solution"
		=> $_PROP_EX_SOLUTION,
	"<check_id>.ex.<ex_id>.reference"
		=> $_PROP_EX_REFERENCE,
	"<check_id>.system"
		=> $_PROP_SYSTEM,
);

# Forward declarations
sub _ns_check_get_ids($$$);
sub _ns_check_get_selected_ids($$$);
sub _ns_check_id_is_valid($$$);
sub _ns_author_nums_get($$$);
sub _ns_author_num_is_valid($$$);
sub _ns_extrafile_nums_get($$$);
sub _ns_extrafile_num_is_valid($$$);
sub _ns_dep_nums_get($$$);
sub _ns_dep_num_is_valid($$$);
sub _ns_param_ids_get($$$);
sub _ns_param_id_is_valid($$$);
sub _ns_si_ids_get($$$);
sub _ns_si_id_is_valid($$$);
sub _ns_si_prog_extrafile_nums_get($$$);
sub _ns_si_prog_extrafile_num_is_valid($$$);
sub _ns_si_rec_extrafile_nums_get($$$);
sub _ns_si_rec_extrafile_num_is_valid($$$);
sub _ns_ex_ids_get($$$);
sub _ns_ex_id_is_valid($$$);

# Consumer property namespace map
# ns_id => [ type, regexp, fn_get_ids, fn_get_selected_ids, fn_id_is_valid ]
my %_PDEF_NS = (
	"<check_id>" =>
		[ "check name", $MATCH_ID_WILDCARD,
		  \&_ns_check_get_ids, \&_ns_check_get_selected_ids,
		  \&_ns_check_id_is_valid ],
	"<author_num>" =>
		[ "author number", '[\d\?\*]+',
		  \&_ns_author_nums_get, undef, \&_ns_author_num_is_valid ],
	"<extrafile_num>" =>
		[ "extrafile number", '[\d\?\*]+',
		  \&_ns_extrafile_nums_get, undef,
		  \&_ns_extrafile_num_is_valid ],
	"<dep_num>" =>
		[ "dependency number", '[\d\?\*]+',
		  \&_ns_dep_nums_get, undef, \&_ns_dep_num_is_valid ],
	"<param_id>" =>
		[ "parameter ID", $MATCH_ID_WILDCARD,
		  \&_ns_param_ids_get, undef, \&_ns_param_id_is_valid ],
	"<si_id>" =>
		[ "sysinfo ID", $MATCH_ID_WILDCARD,
		  \&_ns_si_ids_get, undef, \&_ns_si_id_is_valid ],
	"<si_prog_extrafile_num>" =>
		[ "sysinfo program item extrafile number", '[\d\?\*]+',
		  \&_ns_si_prog_extrafile_nums_get, undef,
		  \&_ns_si_prog_extrafile_num_is_valid ],
	"<si_rec_extrafile_num>" =>
		[ "sysinfo record item extrafile number", '[\d\?\*]+',
		  \&_ns_si_rec_extrafile_nums_get, undef,
		  \&_ns_si_rec_extrafile_num_is_valid ],
	"<ex_id>" =>
		[ "exception ID", $MATCH_ID_WILDCARD,
		  \&_ns_ex_ids_get, undef, \&_ns_ex_id_is_valid ],
);


#
# Global variables
#

# Hash containing IDs of checks which were selected by user
my %_selected_check_ids;

# Flag indicating if a selection is active
my $_selection_active;


#
# Sub-routines
#

#
# check_get_selected_ids()
#
# Return list of selected check IDs.
#
sub check_get_selected_ids()
{
	return keys(%_selected_check_ids);
}

#
# check_get_num_selected()
#
# Return number of selected checks.
#
sub check_get_num_selected()
{
	return scalar(keys(%_selected_check_ids));
}

#
# _ns_check_get_ids(subkeys, level, create)
#
# Return list of check IDs.
#
sub _ns_check_get_ids($$$)
{
	my ($subkeys, $level, $create) = @_;

	return db_check_get_ids();
}

#
# _ns_check_get_selected_ids(subkeys, level, create)
#
# Return list of selected check IDs.
#
sub _ns_check_get_selected_ids($$$)
{
	my ($subkeys, $level, $create) = @_;

	return check_get_selected_ids();
}

#
# _ns_check_id_is_valid(subkeys, level, create)
#
# Return non-zero if check ID specified by SUBKEY and LEVEL exists.
#
sub _ns_check_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[$level];

	if ($create) {
		# Check if this ID can be created
		if ($check_id =~ /^$MATCH_ID$/i) {
			return 1;
		}
		return 0;
	} else {
		db_check_exists($check_id);
	}
}

#
# _ns_author_nums_get(subkeys, level, create)
#
# Return list of author numbers.
#
sub _ns_author_nums_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $check = db_check_get($check_id);
	my $authors;

	if (!defined($check)) {
		return ();
	}
	$authors = $check->[$CHECK_T_AUTHORS];

	return 0..(scalar(@$authors) - 1);
}

#
# _ns_author_num_is_valid(subkeys, level, create)
#
# Return non-zero if author number specified by SUBKEY and LEVEL exists.
#
sub _ns_author_num_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $num = $subkeys->[$level];
	my $check = db_check_get($check_id);
	my $authors;

	if (!defined($check)) {
		return 0;
	}

	# Check if this is a number, also remove leading zeros
	if (!($num =~ s/^0*(\d+)$/$1/)) {
		return 0;
	}

	if ($create) {
		# For IDs that should be created, this is enough testing
		return 1;
	}

	$authors = $check->[$CHECK_T_AUTHORS];
	if ($num >= scalar(@$authors)) {
		return 0;
	}

	return 1;
}

#
# _ns_extrafile_nums_get(subkeys, level, create)
#
# Return list of extrafile numbers.
#
sub _ns_extrafile_nums_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $check = db_check_get($check_id);
	my $extrafiles;

	if (!defined($check)) {
		return ();
	}
	$extrafiles = $check->[$CHECK_T_EXTRAFILES];

	return 0..(scalar(@$extrafiles) - 1);
}

#
# _ns_extrafile_num_is_valid(subkeys, level, create)
#
# Return non-zero if extrafile number specified by SUBKEY and LEVEL exists.
#
sub _ns_extrafile_num_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $num = $subkeys->[$level];
	my $check = db_check_get($check_id);
	my $extrafiles;

	if (!defined($check)) {
		return 0;
	}

	# Check if this is a number, also remove leading zeros
	if (!($num =~ s/^0*(\d+)$/$1/)) {
		return 0;
	}

	if ($create) {
		# For IDs that should be created, this is enough testing
		return 1;
	}

	$extrafiles = $check->[$CHECK_T_EXTRAFILES];
	if (!defined($extrafiles) || $num >= scalar(@$extrafiles)) {
		return 0;
	}

	return 1;
}

#
# _ns_dep_nums_get(subkeys, level, create)
#
# Return list of dependency numbers.
#
sub _ns_dep_nums_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $check = db_check_get($check_id);
	my $deps;

	if (!defined($check)) {
		return ();
	}
	$deps = $check->[$CHECK_T_DEPS];

	return 0..(scalar(@$deps) - 1);
}

#
# _ns_dep_num_is_valid(subkeys, level, create)
#
# Return non-zero if dependency number specified by SUBKEY and LEVEL exists.
#
sub _ns_dep_num_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $num = $subkeys->[$level];
	my $check = db_check_get($check_id);
	my $deps;

	if (!defined($check)) {
		return 0;
	}

	# Check if this is a number, also remove leading zeros
	if (!($num =~ s/^0*(\d+)$/$1/)) {
		return 0;
	}

	if ($create) {
		# For IDs that should be created, this is enough testing
		return 1;
	}

	$deps = $check->[$CHECK_T_DEPS];
	if (!defined($deps) || $num >= scalar(@$deps)) {
		return 0;
	}

	return 1;
}

#
# _ns_param_ids_get(subkeys, level, create)
#
# Return list of parameter IDs.
#
sub _ns_param_ids_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];

	return db_check_get_param_ids($check_id);
}

#
# _ns_param_id_is_valid(subkeys, level, create)
#
# Return non-zero if parameter ID specified by SUBKEY and LEVEL exists.
#
sub _ns_param_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $param_id = $subkeys->[$level];

	if ($create) {
		# Check if this ID can be created
		if ($param_id =~ /^$MATCH_ID$/) {
			return 1;
		}
		return 0;
	}
	return db_check_param_exists($check_id, $param_id);
}

#
# _ns_si_ids_get(subkeys, level, create)
#
# Return list of sysinfo IDs.
#
sub _ns_si_ids_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];

	return db_check_get_si_ids($check_id);
}

#
# _ns_si_id_is_valid(subkeys, level, create)
#
# Return non-zero if sysinfo ID specified by SUBKEY and LEVEL exists.
#
sub _ns_si_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $si_id = $subkeys->[$level];

	if ($create) {
		# Check if this ID can be created
		if ($si_id =~ /^$MATCH_ID$/) {
			return 1;
		}
		return 0;
	}
	return db_check_si_exists($check_id, $si_id);
}

#
# _get_si_prog_extrafiles(check_id, si_id)
#
# Return list of extrafiles defined for sysinfo program item defined by
# CHECK_ID and SI_ID.
#
sub _get_si_prog_extrafiles($$)
{
	my ($check_id, $si_id) = @_;
	my $check;
	my $si;
	my $type;

	# Get check
	$check = db_check_get($check_id);
	if (!defined($check)) {
		return undef;
	}
	# Get sysinfo item
	$si = $check->[$CHECK_T_SI_DB]->{$si_id};
	if (!defined($si)) {
		return undef;
	}
	# Ensure correct type
	if ($si->[$SYSINFO_T_TYPE] != $SI_TYPE_T_PROG) {
		return undef;
	}

	return $si->[$SYSINFO_T_DATA]->[$SI_PROG_DATA_T_EXTRAFILES];
}

#
# _ns_si_prog_extrafile_nums_get(subkeys, level, create)
#
# Return list of extrafile numbers for sysinfo program item.
#
sub _ns_si_prog_extrafile_nums_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $si_id = $subkeys->[2];
	my $extrafiles = _get_si_prog_extrafiles($check_id, $si_id);

	if (!defined($extrafiles)) {
		return ();
	}
	return 0..(scalar(@$extrafiles) - 1);
}

#
# _ns_si_prog_extrafile_num_is_valid(subkeys, level, create)
#
# Return non-zero if sysinfo program item extrafile number specified by
# SUBKEY and LEVEL exists.
#
sub _ns_si_prog_extrafile_num_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $si_id = $subkeys->[2];
	my $num = $subkeys->[$level];
	my $extrafiles;
	my $type = db_check_get_si_type($check_id, $si_id);

	# Check type
	if (!defined($type) || $type != $SI_TYPE_T_PROG) {
		return 0;
	}

	# Check if this is a number, also remove leading zeros
	if (!($num =~ s/^0*(\d+)$/$1/)) {
		return 0;
	}

	if ($create) {
		# For IDs that should be created, this is enough testing
		return 1;
	}

	$extrafiles = _get_si_prog_extrafiles($check_id, $si_id);
	if (!defined($extrafiles) || $num >= scalar(@$extrafiles)) {
		return 0;
	}

	return 1;
}

#
# _get_si_rec_extrafiles(check_id, si_id)
#
# Return list of extrafiles defined for sysinfo record item defined by
# CHECK_ID and SI_ID.
#
sub _get_si_rec_extrafiles($$)
{
	my ($check_id, $si_id) = @_;
	my $check;
	my $si;
	my $type;

	# Get check
	$check = db_check_get($check_id);
	if (!defined($check)) {
		return undef;
	}
	# Get sysinfo item
	$si = $check->[$CHECK_T_SI_DB]->{$si_id};
	if (!defined($si)) {
		return undef;
	}
	# Ensure correct type
	if ($si->[$SYSINFO_T_TYPE] != $SI_TYPE_T_REC) {
		return undef;
	}

	return $si->[$SYSINFO_T_DATA]->[$SI_REC_DATA_T_EXTRAFILES];
}

#
# _ns_si_rec_extrafile_nums_get(subkeys, level, create)
#
# Return list of extrafile numbers for sysinfo record item.
#
sub _ns_si_rec_extrafile_nums_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $si_id = $subkeys->[2];
	my $extrafiles = _get_si_rec_extrafiles($check_id, $si_id);

	if (!defined($extrafiles)) {
		return ();
	}
	return 0..(scalar(@$extrafiles) - 1);
}

#
# _ns_si_rec_extrafile_num_is_valid(subkeys, level, create)
#
# Return non-zero if sysinfo record item extrafile number specified by
# SUBKEY and LEVEL exists.
#
sub _ns_si_rec_extrafile_num_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $si_id = $subkeys->[2];
	my $num = $subkeys->[$level];
	my $extrafiles;
	my $type = db_check_get_si_type($check_id, $si_id);

	# Check type
	if (!defined($type) || $type != $SI_TYPE_T_REC) {
		return 0;
	}

	# Check if this is a number, also remove leading zeros
	if (!($num =~ s/^0*(\d+)$/$1/)) {
		return 0;
	}

	if ($create) {
		# For IDs that should be created, this is enough testing
		return 1;
	}

	$extrafiles = _get_si_rec_extrafiles($check_id, $si_id);
	if (!defined($extrafiles) || $num >= scalar(@$extrafiles)) {
		return 0;
	}

	return 1;
}

#
# _ns_ex_ids_get(subkeys, level, create)
#
# Return list of exception IDs.
#
sub _ns_ex_ids_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];

	return db_check_get_ex_ids($check_id);
}

#
# _ns_ex_id_is_valid(subkeys, level, create)
#
# Return non-zero if exception ID specified by SUBKEY and LEVEL exists.
#
sub _ns_ex_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $check_id = $subkeys->[0];
	my $ex_id = $subkeys->[2];

	if ($create) {
		# Check if this ID can be created
		if ($ex_id =~ /^$MATCH_ID$/) {
			return 1;
		}
		return 0;
	}
	return db_check_ex_exists($check_id, $ex_id);
}

#
# _get_property_ids(key[, expand[, create[, skip_invalid[, err_prefix]]]])
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
# _get_property_value(prop_id[, profile_id])
#
# Return value of property PROP_ID.
#
sub _get_property_value($;$)
{
	my ($prop_id, $profile_id) = @_;
	my ($tag, $check_id, $sub_id, $sub_id2) = @$prop_id;
	my $check = db_check_get($check_id);

	if (!defined($check)) {
		return undef;
	}
	if ($tag == $_PROP_ID) {
		return $check_id;
	} elsif ($tag == $_PROP_TITLE) {
		return $check->[$CHECK_T_TITLE];
	} elsif ($tag == $_PROP_DESC) {
		return $check->[$CHECK_T_DESC];
	} elsif ($tag == $_PROP_AUTHOR) {
		return $check->[$CHECK_T_AUTHORS]->[$sub_id];
	} elsif ($tag == $_PROP_DEFAULT_STATE) {
		return $check->[$CHECK_T_STATE];
	} elsif ($tag == $_PROP_STATE) {
		return config_check_get_state($check_id, $profile_id);
	} elsif ($tag == $_PROP_COMPONENT) {
		return $check->[$CHECK_T_COMPONENT];
	} elsif ($tag == $_PROP_DEFAULT_REPEAT) {
		return $check->[$CHECK_T_REPEAT];
	} elsif ($tag == $_PROP_REPEAT) {
		return config_check_get_repeat($check_id, $profile_id);
	} elsif ($tag == $_PROP_MULTIHOST) {
		return $check->[$CHECK_T_MULTIHOST];
	} elsif ($tag == $_PROP_MULTITIME) {
		return $check->[$CHECK_T_MULTITIME];
	} elsif ($tag == $_PROP_DIR) {
		return $check->[$CHECK_T_DIR];
	} elsif ($tag == $_PROP_EXTRAFILE) {
		return $check->[$CHECK_T_EXTRAFILES]->[$sub_id];
	} elsif ($tag == $_PROP_DEP) {
		return $check->[$CHECK_T_DEPS]->[$sub_id]->[$DEP_T_DEP];
	} elsif ($tag == $_PROP_PARAM_ID) {
		return $sub_id;
	} elsif ($tag == $_PROP_PARAM_DESC) {
		return $check->[$CHECK_T_PARAM_DB]->{$sub_id}->[$PARAM_T_DESC];
	} elsif ($tag == $_PROP_PARAM_DEFAULT_VALUE) {
		return $check->[$CHECK_T_PARAM_DB]->{$sub_id}->[$PARAM_T_VALUE];
	} elsif ($tag == $_PROP_PARAM_VALUE) {
		return config_check_get_param($check_id, $sub_id, $profile_id);
	} elsif ($tag == $_PROP_SI_ID) {
		return $sub_id;
	} elsif ($tag == $_PROP_SI_TYPE) {
		return $check->[$CHECK_T_SI_DB]->{$sub_id}->[$SYSINFO_T_TYPE];
	} elsif ($tag == $_PROP_SI_FILE_FILENAME) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_FILE) {
			return undef;
		}

		return $data->[$SI_FILE_DATA_T_FILENAME];
	} elsif ($tag == $_PROP_SI_FILE_USER) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_FILE) {
			return undef;
		}

		return $data->[$SI_FILE_DATA_T_USER];
	} elsif ($tag == $_PROP_SI_PROG_CMDLINE) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_PROG) {
			return undef;
		}

		return $data->[$SI_PROG_DATA_T_CMDLINE];
	} elsif ($tag == $_PROP_SI_PROG_USER) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_PROG) {
			return undef;
		}

		return $data->[$SI_PROG_DATA_T_USER];
	} elsif ($tag == $_PROP_SI_PROG_IGNORERC) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_PROG) {
			return undef;
		}

		return $data->[$SI_PROG_DATA_T_IGNORERC];
	} elsif ($tag == $_PROP_SI_PROG_EXTRAFILE) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_PROG) {
			return undef;
		}

		return $data->[$SI_PROG_DATA_T_EXTRAFILES]->[$sub_id2];
	} elsif ($tag == $_PROP_SI_REC_START) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_REC) {
			return undef;
		}

		return $data->[$SI_REC_DATA_T_START];
	} elsif ($tag == $_PROP_SI_REC_STOP) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_REC) {
			return undef;
		}

		return $data->[$SI_REC_DATA_T_STOP];
	} elsif ($tag == $_PROP_SI_REC_DEFAULT_DURATION) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_REC) {
			return undef;
		}

		return $data->[$SI_REC_DATA_T_DURATION];
	} elsif ($tag == $_PROP_SI_REC_DURATION) {
		return config_check_get_si_rec_duration($check_id, $sub_id,
							$profile_id);
	} elsif ($tag == $_PROP_SI_REC_USER) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_REC) {
			return undef;
		}

		return $data->[$SI_REC_DATA_T_USER];
	} elsif ($tag == $_PROP_SI_REC_EXTRAFILE) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_REC) {
			return undef;
		}

		return $data->[$SI_REC_DATA_T_EXTRAFILES]->[$sub_id2];
	} elsif ($tag == $_PROP_SI_REF_CHECK_ID) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_REF) {
			return undef;
		}

		return $data->[$SI_REF_DATA_T_CHECK];
	} elsif ($tag == $_PROP_SI_REF_SI_ID) {
		my $sysinfo = $check->[$CHECK_T_SI_DB]->{$sub_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		if ($type != $SI_TYPE_T_REF) {
			return undef;
		}

		return $data->[$SI_REF_DATA_T_SYSINFO];
	} elsif ($tag == $_PROP_EX_ID) {
		return $sub_id;
	} elsif ($tag == $_PROP_EX_DEFAULT_SEVERITY) {
		return $check->[$CHECK_T_EX_DB]->{$sub_id}->
			[$EXCEPTION_T_SEVERITY];
	} elsif ($tag == $_PROP_EX_SEVERITY) {
		return config_check_get_ex_severity($check_id, $sub_id,
							       $profile_id);
	} elsif ($tag == $_PROP_EX_DEFAULT_STATE) {
		return $check->[$CHECK_T_EX_DB]->{$sub_id}->
			[$EXCEPTION_T_STATE];
	} elsif ($tag == $_PROP_EX_STATE) {
		return config_check_get_ex_state($check_id, $sub_id,
							    $profile_id);
	} elsif ($tag == $_PROP_EX_SUMMARY) {
		return $check->[$CHECK_T_EX_DB]->{$sub_id}->
			[$EXCEPTION_T_SUMMARY];
	} elsif ($tag == $_PROP_EX_EXPLANATION) {
		return $check->[$CHECK_T_EX_DB]->{$sub_id}->
			[$EXCEPTION_T_EXPLANATION];
	} elsif ($tag == $_PROP_EX_SOLUTION) {
		return $check->[$CHECK_T_EX_DB]->{$sub_id}->
			[$EXCEPTION_T_SOLUTION];
	} elsif ($tag == $_PROP_EX_REFERENCE) {
		return $check->[$CHECK_T_EX_DB]->{$sub_id}->
			[$EXCEPTION_T_REFERENCE];
	} elsif ($tag == $_PROP_SYSTEM) {
		return $check->[$CHECK_T_SYSTEM];
	}

	return undef;
}

#
# _get_property_key(prop_id)
#
# Return string representation of PROP_ID.
#
sub _get_property_key($)
{
	my ($prop_id) = @_;
	my ($tag, $check_id, $sub_id, $sub_id2) = @$prop_id;

	if ($tag == $_PROP_ID) {
		return "$check_id.id";
	} elsif ($tag == $_PROP_TITLE) {
		return "$check_id.title";
	} elsif ($tag == $_PROP_DESC) {
		return "$check_id.desc";
	} elsif ($tag == $_PROP_AUTHOR) {
		return "$check_id.author.$sub_id";
	} elsif ($tag == $_PROP_DEFAULT_STATE) {
		return "$check_id.default_state";
	} elsif ($tag == $_PROP_STATE) {
		return "$check_id.state";
	} elsif ($tag == $_PROP_COMPONENT) {
		return "$check_id.component";
	} elsif ($tag == $_PROP_DEFAULT_REPEAT) {
		return "$check_id.default_repeat";
	} elsif ($tag == $_PROP_REPEAT) {
		return "$check_id.repeat";
	} elsif ($tag == $_PROP_MULTIHOST) {
		return "$check_id.multihost";
	} elsif ($tag == $_PROP_MULTITIME) {
		return "$check_id.multitime";
	} elsif ($tag == $_PROP_DIR) {
		return "$check_id.dir";
	} elsif ($tag == $_PROP_EXTRAFILE) {
		return "$check_id.extrafile.$sub_id";
	} elsif ($tag == $_PROP_DEP) {
		return "$check_id.dep.$sub_id";
	} elsif ($tag == $_PROP_PARAM_ID) {
		return "$check_id.param.$sub_id.id";
	} elsif ($tag == $_PROP_PARAM_DESC) {
		return "$check_id.param.$sub_id.desc";
	} elsif ($tag == $_PROP_PARAM_DEFAULT_VALUE) {
		return "$check_id.param.$sub_id.default_value";
	} elsif ($tag == $_PROP_PARAM_VALUE) {
		return "$check_id.param.$sub_id.value";
	} elsif ($tag == $_PROP_SI_ID) {
		return "$check_id.si.$sub_id.id";
	} elsif ($tag == $_PROP_SI_TYPE) {
		return "$check_id.si.$sub_id.type";
	} elsif ($tag == $_PROP_SI_FILE_FILENAME) {
		return "$check_id.si.$sub_id.file_filename";
	} elsif ($tag == $_PROP_SI_FILE_USER) {
		return "$check_id.si.$sub_id.file_user";
	} elsif ($tag == $_PROP_SI_PROG_CMDLINE) {
		return "$check_id.si.$sub_id.prog_cmdline";
	} elsif ($tag == $_PROP_SI_PROG_USER) {
		return "$check_id.si.$sub_id.prog_user";
	} elsif ($tag == $_PROP_SI_PROG_IGNORERC) {
		return "$check_id.si.$sub_id.prog_ignorerc";
	} elsif ($tag == $_PROP_SI_PROG_EXTRAFILE) {
		return "$check_id.si.$sub_id.prog_extrafile.$sub_id2";
	} elsif ($tag == $_PROP_SI_REC_START) {
		return "$check_id.si.$sub_id.rec_start";
	} elsif ($tag == $_PROP_SI_REC_STOP) {
		return "$check_id.si.$sub_id.rec_stop";
	} elsif ($tag == $_PROP_SI_REC_DEFAULT_DURATION) {
		return "$check_id.si.$sub_id.rec_default_duration";
	} elsif ($tag == $_PROP_SI_REC_DURATION) {
		return "$check_id.si.$sub_id.rec_duration";
	} elsif ($tag == $_PROP_SI_REC_USER) {
		return "$check_id.si.$sub_id.rec_user";
	} elsif ($tag == $_PROP_SI_REC_EXTRAFILE) {
		return "$check_id.si.$sub_id.rec_extrafile.$sub_id2";
	} elsif ($tag == $_PROP_SI_REF_CHECK_ID) {
		return "$check_id.si.$sub_id.ref_check_id";
	} elsif ($tag == $_PROP_SI_REF_SI_ID) {
		return "$check_id.si.$sub_id.ref_si_id";
	} elsif ($tag == $_PROP_EX_ID) {
		return "$check_id.ex.$sub_id.id";
	} elsif ($tag == $_PROP_EX_DEFAULT_SEVERITY) {
		return "$check_id.ex.$sub_id.default_severity";
	} elsif ($tag == $_PROP_EX_SEVERITY) {
		return "$check_id.ex.$sub_id.severity";
	} elsif ($tag == $_PROP_EX_DEFAULT_STATE) {
		return "$check_id.ex.$sub_id.default_state";
	} elsif ($tag == $_PROP_EX_STATE) {
		return "$check_id.ex.$sub_id.state";
	} elsif ($tag == $_PROP_EX_SUMMARY) {
		return "$check_id.ex.$sub_id.summary";
	} elsif ($tag == $_PROP_EX_EXPLANATION) {
		return "$check_id.ex.$sub_id.explanation";
	} elsif ($tag == $_PROP_EX_SOLUTION) {
		return "$check_id.ex.$sub_id.solution";
	} elsif ($tag == $_PROP_EX_REFERENCE) {
		return "$check_id.ex.$sub_id.reference";
	} elsif ($tag == $_PROP_SYSTEM) {
		return "$check_id.system";
	}
}

#
# _print_property(prop_id)
#
# Print property PROP_ID.
#
sub _print_property($)
{
	my ($prop_id) = @_;
	my $key = _get_property_key($prop_id);
	my $value = _get_property_value($prop_id);

	if (!defined($value)) {
		return;
	}
	if ($value =~ /\n/) {
		my $line;

		print("$key=\n");
		foreach $line (split(/\n/, $value)) {
			print("|$line\n");
		}
	} else {
			print("$key=$value\n");
	}
}

#
# _set_property_value(prop_id, value)
#
# Set value of property PROP_ID to VALUE.
#
sub _set_property_value($$)
{
	my ($prop_id, $value) = @_;
	my ($tag, $check_id, $sub_id) = @$prop_id;

	if ($tag == $_PROP_STATE) {
		my $state = str_to_state($value);
		my $state_str = state_to_str($state);

		info("Setting check activation state of '$check_id' to ".
		      "'$state_str'\n");
		config_check_set_state($check_id, $state);
	} elsif ($tag == $_PROP_REPEAT) {
		validate_duration($value, 1);

		info("Setting check repeat setting of '$check_id' to ".
		      "'$value'\n");
		config_check_set_repeat($check_id, $value);
	} elsif ($tag == $_PROP_PARAM_VALUE) {
		info("Setting check parameter '$check_id.$sub_id' to ".
		      "'$value'\n");
		config_check_set_param($check_id, $sub_id, $value);
	} elsif ($tag == $_PROP_SI_REC_DURATION) {
		# Check for valid duration
		validate_duration($value, 0);

		info("Setting sysinfo record item duration of ".
		      "'$check_id.$sub_id' to '$value'\n");
		config_check_set_si_rec_duration($check_id, $sub_id, $value);
	} elsif ($tag == $_PROP_EX_SEVERITY) {
		my $sev = str_to_sev($value);

		info("Setting exception severity of '$check_id.$sub_id' to ".
		      "'$value'\n");
		config_check_set_ex_severity($check_id, $sub_id, $sev);
	} elsif ($tag == $_PROP_EX_STATE) {
		my $state = str_to_state($value);

		info("Setting state of exception '$sub_id' of check ".
		      "'$check_id' to '$value'\n");
		config_check_set_ex_state($check_id, $sub_id, $state);
	} else {
		die("Cannot modify property '"._get_property_key($prop_id).
		    "'\n");
	}
}

#
# check_select_all()
#
# Add all checks to selection.
#
sub check_select_all()
{
	my @check_ids = db_check_get_ids();
	my $check_id;

	foreach $check_id (@check_ids) {
		$_selected_check_ids{$check_id} = 1;
	}
	$_selection_active = 1;
}

#
# check_select_none()
#
# Remove all checks from selection.
#
sub check_select_none()
{
	%_selected_check_ids = ();
	$_selection_active = 1;
}

#
# check_selection_is_empty()
#
# Return non-zero if no checks are currently selected.
#
sub check_selection_is_empty()
{
	return !(%_selected_check_ids);
}

#
# _match_property_value(prop_id, op, value, profile_id)
#
# If current value of property PROP_ID matches VALUE according to OP, return
# non-zero. Return zero otherwise.
#
sub _match_property_value($$$$)
{
	my ($prop_id, $op, $value, $profile_id) = @_;
	my $actual = _get_property_value($prop_id, $profile_id);
	my $tag = $prop_id->[$_PROP_ID_T_TAG];

	if (!defined($value) || !defined($actual)) {
		return 0;
	}
	# Adjust property name if necessary
	if ($value =~ /^\d+$/) {
		# User specified number format, nothing to do
	} elsif ($tag == $_PROP_STATE || $tag == $_PROP_DEFAULT_STATE ||
		 $tag == $_PROP_EX_STATE || $tag == $_PROP_EX_DEFAULT_STATE) {
		$actual = state_to_str($actual);
	} elsif ($tag == $_PROP_EX_SEVERITY ||
		 $tag == $_PROP_EX_DEFAULT_SEVERITY) {
		$actual = sev_to_str($actual);
	} elsif ($tag == $_PROP_MULTIHOST || $tag == $_PROP_MULTITIME) {
		$actual = yesno_to_str($actual);
	} elsif ($tag == $_PROP_SI_TYPE) {
		$actual = si_type_to_str($actual);
	}

	debug("Matching '$value' $op '$actual'\n");
	if ($op eq "=") {
		return match_wildcard($actual, $value);
	} elsif ($op eq "!=") {
		return !match_wildcard($actual, $value);
	}

	# Handle unknown operators gracefully
	return 0;
}

#
# _key_to_check_ids(spec, profile_id)
#
# Return list of check IDs for which boolean condition defined by SPEC
# evaluates as true.
#
sub _key_to_check_ids($$)
{
	my ($spec, $profile_id) = @_;
	my $key;
	my $op;
	my $value;
	my $prop_id;
	my $err_prefix;
	my @check_ids;
	my $check_id;

	if (!($spec =~ /^([$MATCH_ID_CHAR\.\*]+)(=|!=)(.*)$/)) {
		die("Check specification '$spec': unrecognized format!\n");
	}
	($key, $op, $value) = ($1, $2, $3);

	# Convert keys into list of property IDs
	$err_prefix = "Check specification '$key': ";
	foreach $prop_id (_get_property_ids("*.$key", $PROP_EXP_NEVER, 1, 0,
					    $err_prefix)) {
		if (!_match_property_value($prop_id, $op, $value,
					   $profile_id)) {
			next;
		}
		$check_id = $prop_id->[$_PROP_ID_T_CHECK_ID];
		push(@check_ids, $check_id);

		info2("Check $check_id matches '$key$op$value'\n");
	}

	info2("Keyword $key$op$value matched ".scalar(@check_ids)." checks\n");

	return @check_ids;
}

#
# check_select(spec, intersect, nonex[, profile_id])
#
# Perform selection operation on checks which match SPEC. If INTERSECT is
# non-zero, reduce selection to those checks that match SPEC and are already
# selected. If NONEX is non-zero, allow selecting checks which do not exist.
#
sub check_select($$$;$)
{
	my ($spec, $intersect, $nonex, $profile_id) = @_;
	my $lspec = lc($spec);
	my @check_ids;
	my $check_id;
	my $type;

	$type = get_spec_type($spec);

	if ($type == $SPEC_T_ID) {
		# This specification is a check ID
		if (!db_check_exists($lspec) && !$nonex) {
			warn("Check '$spec' does not exist - skipping\n");
			return;
		}
		@check_ids = ($lspec);
	} elsif ($type == $SPEC_T_WILDCARD) {
		# This specification contains shell wildcards (? and *)
		@check_ids = filter_ids_by_wildcard($spec, "check",
						    db_check_get_ids());
	} elsif ($type == $SPEC_T_KEY) {
		# This specification consists of a key, operator, value
		# statement
		@check_ids = _key_to_check_ids($spec, $profile_id);
	} else {
		die("Unrecognized check specification: '$spec'\n");
	}

	if ($intersect) {
		my %new_sel;

		# Create new selection containing intersection of both sets
		foreach $check_id (@check_ids) {
			if ($_selected_check_ids{$check_id}) {
				$new_sel{$check_id} = 1;
			}
		}

		# Replace existing selection with intersection
		%_selected_check_ids = %new_sel;
	} else {
		# Apply list to selection
		foreach $check_id (@check_ids) {
			$_selected_check_ids{$check_id} = 1;
		}
	}

	$_selection_active = 1;
}

#
# check_selection_is_active()
#
# Return non-zero if a check selection is active.
#
sub check_selection_is_active()
{
	return $_selection_active;
}

#
# _print_check_heading(check, show_state)
#
# Print check heading.
#
sub _print_check_heading($$)
{
	my ($check, $show_state) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $heading;

	if ($show_state) {
		my $state = config_check_get_state_or_default($check_id);

		$state = state_to_str($state);
		$heading = "Check $check_id ($state)";
	} else {
		$heading = "Check $check_id";
	}

	print("$heading\n");
	print(("="x(length($heading)))."\n");
}

#
# _print_check_title(check)
#
# Print check title.
#
sub _print_check_title($)
{
	my ($check) = @_;
	my $title = $check->[$CHECK_T_TITLE];

	print("Title:\n");
	print(get_indented($title, 2));
}

#
# _print_check_desc(check)
#
# Print check description.
#
sub _print_check_desc($)
{
	my ($check) = @_;
	my $desc = $check->[$CHECK_T_DESC];

	print("\nDescription:\n");
	print(format_as_text($desc, 2));
}

#
# _print_check_data(check)
#
# Print generic check data.
#
sub _print_check_data($)
{
	my ($check) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $state = state_to_str(config_check_get_state_or_default($check_id));
	my $state_def = state_to_str($check->[$CHECK_T_STATE]);
	my $repeat = config_check_get_repeat_or_default($check_id);
	my $repeat_def = $check->[$CHECK_T_REPEAT];
	my $multihost = yesno_to_str($check->[$CHECK_T_MULTIHOST]);
	my $multitime = yesno_to_str($check->[$CHECK_T_MULTITIME]);
	my $component = $check->[$CHECK_T_COMPONENT];
	my $dir = $check->[$CHECK_T_DIR];
	my $system = $check->[$CHECK_T_SYSTEM];
	my @extrafiles = @{$check->[$CHECK_T_EXTRAFILES]};
	my $extrafile;

	print("\nCheck data:\n");
	print_padded(2, 24, "State [$state_def]", $state);
	print_padded(2, 24, "Repeat interval [$repeat_def]", $repeat);
	print_padded(2, 24, "Multihost", $multihost);
	print_padded(2, 24, "Multitime", $multitime);
	print_padded(2, 24, "Component", $component);
	print_padded(2, 24, "Installation directory", $dir);
	if (!defined($system)) {
		$system = "not installed";
	} elsif ($system) {
		$system = "system-wide database";
	} else {
		$system = "user database";
	}
	print_padded(2, 24, "Installed in", $system);
	foreach $extrafile (@extrafiles) {
		print_padded(2, 24, "Extra file", $extrafile);
	}
}

#
# _print_check_authors(check)
#
# Print check authors.
#
sub _print_check_authors($)
{
	my ($check) = @_;
	my $author;

	print("\nAuthors:\n");
	foreach $author (@{$check->[$CHECK_T_AUTHORS]}) {
		print("  $author\n");
	}
}

#
# _print_check_params(check)
#
# Print check parameter.
#
sub _print_check_params($)
{
	my ($check) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $param_db = $check->[$CHECK_T_PARAM_DB];
	my @param_ids = keys(%{$param_db});
	my $param_id;
	my $nl;

	# Check if this check provides parameters
	if (!@param_ids) {
		return;
	}
	print("\nParameters:\n");
	foreach $param_id (sort(@param_ids)) {
		my $param = $param_db->{$param_id};
		my $param_desc = $param->[$PARAM_T_DESC];
		my $value = config_check_get_param_or_default($check_id,
							     $param_id);
		my $default = $param->[$PARAM_T_VALUE];
		my $default_text = "\nDefault value is \"$default\".\n";

		print($nl) if (defined($nl));
		$nl = "\n";
		print("  $param_id=$value\n");
		print(format_as_text($param_desc, 8));
		print(get_indented($default_text, 8));
	}
}

#
# _print_check_sysinfo_item_detailed(check, si)
#
# Print detailed sysinfo item data.
#
sub _print_check_sysinfo_item_detailed($$)
{
	my ($check, $si) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my ($si_id, $type, $data) = @$si;
	my $type_str = si_type_to_str($type);

	print("  $si_id\n");
	print_padded(4, 22, "Type", $type_str);
	if ($type == $SI_TYPE_T_FILE) {
		my $user = $data->[$SI_FILE_DATA_T_USER];

		print_padded(4, 22, "Filename",
			      $data->[$SI_FILE_DATA_T_FILENAME]);
		if ($user ne "") {
			print_padded(4, 22, "Username", $user);
		}
	} elsif ($type == $SI_TYPE_T_PROG) {
		my $extrafiles = $data->[$SI_PROG_DATA_T_EXTRAFILES];
		my $extrafile;
		my $user = $data->[$SI_PROG_DATA_T_USER];

		print_padded(4, 22, "Command line",
			      $data->[$SI_PROG_DATA_T_CMDLINE]);
		if ($user ne "") {
			print_padded(4, 22, "Username", $user);
		}
		print_padded(4, 22, "Ignore RC",
			      yesno_to_str($data->[$SI_PROG_DATA_T_IGNORERC]));
		foreach $extrafile (@$extrafiles) {
			print_padded(4, 22, "Extra file", $extrafile);
		}
	} elsif ($type == $SI_TYPE_T_REC) {
		my $extrafiles = $data->[$SI_REC_DATA_T_EXTRAFILES];
		my $extrafile;
		my $rec = config_check_get_si_rec_duration_or_default($check_id,
								      $si_id);
		my $rec_def = $data->[$SI_REC_DATA_T_DURATION];
		my $user = $data->[$SI_REC_DATA_T_USER];

		print_padded(4, 22, "Start command line",
			      $data->[$SI_REC_DATA_T_START]);
		print_padded(4, 22, "Stop command line",
			      $data->[$SI_REC_DATA_T_STOP]);
		print_padded(4, 22, "Record duration[$rec_def]", $rec);
		if ($user ne "") {
			print_padded(4, 22, "Username", $user);
		}
		foreach $extrafile (@$extrafiles) {
			print_padded(4, 22, "Extra file", $extrafile);
		}
	} elsif ($type == $SI_TYPE_T_REF) {
		print_padded(4, 22, "Target check name",
			      $data->[$SI_REF_DATA_T_CHECK]);
		print_padded(4, 22, "Target sysinfo ID",
			      $data->[$SI_REF_DATA_T_SYSINFO]);
	}
}

#
# _print_check_sysinfo_item(check, si)
#
# Print basic sysinfo item data.
#
sub _print_check_sysinfo_item($$)
{
	my ($check, $si) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my ($si_id, $type, $data) = @$si;
	my $value;

	# Only print data for record items
	if ($type != $SI_TYPE_T_REC) {
		return;
	}

	$value = config_check_get_si_rec_duration_or_default($check_id, $si_id);
	print("  $si_id.rec_duration=$value\n");
}

#
# _print_check_sysinfo(check, show_details)
#
# Print check sysinfo data.
#
sub _print_check_sysinfo($$)
{
	my ($check, $show_details) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $si_db = $check->[$CHECK_T_SI_DB];
	my @si_ids = sort(keys(%{$si_db}));
	my $si_id;
	my $nl = "";

	if (!$show_details) {
		my $found = 0;
		# Don't print anything if there isn't at least one
		# record sysinfo item
		foreach $si_id (@si_ids) {
			if (db_check_get_si_type($check_id, $si_id) ==
			    $SI_TYPE_T_REC) {
				$found = 1;
				last;
			}
		}
		if (!$found) {
			return;
		}
	}
	print("\nSystem information:\n");
	foreach $si_id (@si_ids) {
		my $si = $si_db->{$si_id};

		if ($show_details) {
			print($nl);
			$nl = "\n";
			_print_check_sysinfo_item_detailed($check, $si);
		} else {
			_print_check_sysinfo_item($check, $si);
		}
	}
}

#
# _print_check_exception_detailed(check, ex)
#
# Print detailed exception data.
#
sub _print_check_exception_detailed($$)
{
	my ($check, $ex) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $ex_id = $ex->[$EXCEPTION_T_ID];
	my $sev = config_check_get_ex_severity_or_default($check_id, $ex_id);
	my $sev_def = $ex->[$EXCEPTION_T_SEVERITY];
	my $state = config_check_get_ex_state_or_default($check_id, $ex_id);
	my $state_def = $ex->[$EXCEPTION_T_STATE];

	$sev = sev_to_str($sev);
	$sev_def = sev_to_str($sev_def);
	$state = state_to_str($state);
	$state_def = state_to_str($state_def);

	print("  $ex_id\n");
	print_padded(4, 22, "Severity[$sev_def]", $sev);
	print_padded(4, 22, "State[$state_def]", $state);
	print("\n    Summary:\n");
	print_indented($ex->[$EXCEPTION_T_SUMMARY], 8);
	print("\n    Explanation:\n");
	print(format_as_text($ex->[$EXCEPTION_T_EXPLANATION], 8));
	print("\n    Solution:\n");
	print(format_as_text($ex->[$EXCEPTION_T_SOLUTION], 8));
	print("\n    Reference:\n");
	print(format_as_text($ex->[$EXCEPTION_T_REFERENCE], 8));
}

#
# _print_check_exception(check, ex)
#
# Print basic exception data.
#
sub _print_check_exception($$)
{
	my ($check, $ex) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $ex_id = $ex->[$EXCEPTION_T_ID];
	my $sev = config_check_get_ex_severity_or_default($check_id, $ex_id);
	my $state = config_check_get_ex_state_or_default($check_id, $ex_id);

	$sev = sev_to_str($sev);
	$state = state_to_str($state);

	print("  $ex_id=$sev ($state)\n");
}

#
# _print_check_exceptions(check, show_details)
#
# Print check exception data.
#
sub _print_check_exceptions($$)
{
	my ($check, $show_details) = @_;
	my $ex_db = $check->[$CHECK_T_EX_DB];
	my @ex_ids = keys(%{$ex_db});
	my $ex_id;
	my $nl = "";

	print("\nExceptions:\n");
	foreach $ex_id (sort(@ex_ids)) {
		my $ex = $ex_db->{$ex_id};

		if ($show_details) {
			print($nl);
			$nl = "\n";
			_print_check_exception_detailed($check, $ex);
		} else {
			_print_check_exception($check, $ex);
		}
	}
}

#
# _print_info(check)
#
# Print basic check information for check CHECK.
#
sub _print_info($)
{
	my ($check) = @_;

	_print_check_heading($check, 1);
	_print_check_title($check);
	_print_check_desc($check);
	_print_check_sysinfo($check, 0);
	_print_check_exceptions($check, 0);
	_print_check_params($check);
}

#
# check_info()
#
# Print basic check information for selected checks.
#
sub check_info()
{
	my @check_ids = check_get_selected_ids();
	my $check_id;
	my $nl = "";

	if (!@check_ids) {
		die("No check was selected!\n");
	}
	foreach $check_id (sort(@check_ids)) {
		my $check = db_check_get($check_id);

		if (!defined($check)) {
			# Shouldn't happen
			die("No such check: $check_id\n");
		}
		print($nl);
		$nl = "\n";
		_print_info($check);
	}
}

#
# _print_details(check)
#
# Print detailed check information for check CHECK.
#
sub _print_details($)
{
	my ($check) = @_;

	_print_check_heading($check, 0);
	_print_check_title($check);
	_print_check_authors($check);
	_print_check_desc($check);
	_print_check_data($check);
	_print_check_sysinfo($check, 1);
	_print_check_exceptions($check, 1);
	_print_check_params($check);
}

#
# check_show()
#
# Print detailed check information for selected checks.
#
sub check_show()
{
	my @check_ids = check_get_selected_ids();
	my $check_id;
	my $nl = "";

	foreach $check_id (sort(@check_ids)) {
		my $check = db_check_get($check_id);

		if (!defined($check)) {
			# Shouldn't happen
			die("No such check: $check_id\n");
		}
		print($nl);
		$nl = "\n";
		_print_details($check);
	}
}

#
# _prop_cmp(a, b)
#
# Compare two check property IDs.
#
sub _prop_cmp($$)
{
	my ($a, $b) = @_;
	my ($tag_a, $check_id_a, $sub_id_a, $sub_id2_a) = @$a;
	my ($tag_b, $check_id_b, $sub_id_b, $sub_id2_b) = @$b;

	if ($check_id_a ne $check_id_b) {
		# Check ID
		return $check_id_a cmp $check_id_b;
	} elsif ($tag_a == $_PROP_AUTHOR && $tag_b == $_PROP_AUTHOR ||
		 $tag_a == $_PROP_EXTRAFILE && $tag_b == $_PROP_EXTRAFILE ||
		 $tag_a == $_PROP_DEP && $tag_b == $_PROP_DEP) {
		# Author, extrafile or dependency number
		return $sub_id_a <=> $sub_id_b;
	} elsif ($_PARAM_TAGS{$tag_a} && $_PARAM_TAGS{$tag_b} &&
		 ($sub_id_a ne $sub_id_b)) {
		# Parameters
		return $sub_id_a cmp $sub_id_b;
	} elsif ($_SI_TAGS{$tag_a} && $_SI_TAGS{$tag_b}) {
		# Sysinfo items

		if ($sub_id_a ne $sub_id_b) {
			# Sysinfo item ID
			return $sub_id_a cmp $sub_id_b;
		} elsif ($tag_a != $tag_b) {
			# Sysinfo item tag
			return $tag_a <=> $tag_b;
		} elsif ($tag_a == $_PROP_SI_PROG_EXTRAFILE ||
			 $tag_a == $_PROP_SI_REC_EXTRAFILE) {
			# Sysinfo program/record item extrafile number
			return $sub_id2_a <=> $sub_id2_b;
		} else {
			return 0;
		}
	} elsif ($_EX_TAGS{$tag_a} && $_EX_TAGS{$tag_b} &&
		 ($sub_id_a ne $sub_id_b)) {
		# Exceptions
		return $sub_id_a cmp $sub_id_b;
	} else {
		return $tag_a <=> $tag_b;
	}
}

#
# check_show_property(keys)
#
# Print check properties specified by KEYS.
#
sub check_show_property($)
{
	my ($keys) = @_;
	my $key;
	my @prop_ids;
	my $prop_id;
	my $last_key;

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
		my $this_key = _get_property_key($prop_id);

		# Sort out duplicate keys
		if (defined($last_key) && $this_key eq $last_key) {
			next;
		}
		$last_key = $this_key;
		_print_property($prop_id);
	}
}

#
# check_set_property(key, value)
#
# Set value of check properties identified by KEY to VALUE.
#
sub check_set_property($$)
{
	my ($key, $value) = @_;
	my @prop_ids;
	my $prop_id;

	# Convert keys into list of property IDs
	@prop_ids = _get_property_ids($key);

	if (!@prop_ids) {
		warn("Key '$key' matched no properties.\n");
		return;
	}

	foreach $prop_id (@prop_ids) {
		_set_property_value($prop_id, $value);
		if ($opt_debug) {
			_print_property($prop_id);
		}
	}
}

#
# check_list()
#
# List contents of check database.
#
sub check_list()
{
	my @check_ids;
	my $check_id;
	my $layout = [
		[
			# min   max     weight  align 		delim
			[ 40,	40,	0,	$ALIGN_T_LEFT,	" " ],
			[ 30,	40,	1,	$ALIGN_T_LEFT,	" " ],
			[ 8,	8,	0,	$ALIGN_T_LEFT,	"" ],
		]
	];

	if ($_selection_active) {
		@check_ids = check_get_selected_ids();
	} else {
		@check_ids = db_check_get_ids();
	}

	return if (!@check_ids);

	# Print heading
	lprintf($layout, "CHECK NAME", "COMPONENT", "STATE");
	print("\n".("="x(layout_get_width($layout)))."\n");

	# Print entry per installed check
	foreach $check_id (sort(@check_ids)) {
		my $check = db_check_get($check_id);
		my $component = $check->[$CHECK_T_COMPONENT];
		my $state;

		# Get activation state
		$state = config_check_get_state_or_default($check_id);
		$state = state_to_str($state);

		# Print entry
		lprintf($layout, $check_id, $component, $state);
		print("\n");
	}
}

#
# check_set_param(spec[, use_active])
#
# Set check parameters according to SPEC. SPEC can take either of the following
# formats:
#   <check_id>.<param_id>=<value>   -> change specified parameter
#   <param_id>=<value>              -> change parameters of selected checks
#
# If USE_ACTIVE is non-zero, parameters for the active checks are modified
# instead of selected checks.
#
sub check_set_param($;$)
{
	my ($spec, $use_active) = @_;
	my @check_ids;
	my $check_id;
	my $param_id;
	my $value;
	my $msg;

	if ($spec =~ /^($MATCH_ID)\.($MATCH_ID)=(.*)$/i) {
		($check_id, $param_id, $value) = (lc($1), lc($2), $3);

		if (!db_check_exists($check_id)) {
			$msg = "check '$check_id' does not exist!\n";
			goto err;
		}
		if (!db_check_param_exists($check_id, $param_id)) {
			$msg = "parameter does not exist!\n";
			goto err;
		}
		push(@check_ids, $check_id);
	} elsif ($spec =~ /^($MATCH_ID)=(.*)$/i) {
		($param_id, $value) = (lc($1), $2);
		my @selected_ids = check_get_selected_ids();

		if ($use_active) {
			@selected_ids = config_check_get_active_ids();
			if (!@selected_ids) {
				# Don't count this as an error
				return;
			}
		} else {
			@selected_ids = check_get_selected_ids();
			if (!@selected_ids) {
				$msg = "no check was selected!\n";
				goto err;
			}
		}

		foreach $check_id (@selected_ids) {
			if (db_check_param_exists($check_id, $param_id)) {
				push(@check_ids, $check_id);
			} else {
				warn("Check '$check_id' does not define ".
				     "parameter '$param_id' - skipping\n");
			}
		}
		if (!@check_ids) {
			my $source = $_selection_active ? "selected" : "active";

			warn("None of the $source checks defines parameter ".
			     "'$param_id' - skipping\n");
			return;
		}
	} else {
		my $source = $_selection_active ? "selected" : "active";

		$msg = <<EOF;
unrecognized parameter format!
Use 'CHECK.PARAM=VALUE' to set a parameter for a specific check.
Use 'PARAM=VALUE' to set a parameter for all $source checks.
EOF
		goto err;
	}

	foreach $check_id (@check_ids) {
		config_check_set_param($check_id, $param_id, $value);
		info("Setting value of parameter $check_id.$param_id to ".
		     "'$value'\n");
	}
	return;

err:
	die("Cannot set check parameter '$spec': $msg");
}

#
# check_set_state(spec)
#
# Set activation state according to SPEC. SPEC can take either of the following
# formats:
# <check_id>=<state>    -> change state of specified check
# <state>               -> change state of selected checks
#
sub check_set_state($)
{
	my ($spec) = @_;
	my @check_ids;
	my $check_id;
	my $state;
	my $str;
	my $msg;

	if ($spec =~ /^($MATCH_ID)=(.*)$/i) {
		($check_id, $state) = (lc($1), $2);

		if (!db_check_exists($check_id)) {
			$msg = "check '$check_id' does not exist!\n";
			goto err;
		}
		push(@check_ids, $check_id);
	} else {
		@check_ids = check_get_selected_ids();

		if (!@check_ids) {
			$msg = "no check was selected!\n";
			goto err;
		}
		$state = $spec;
	}

	$state = str_to_state($state, "Cannot set check state '$spec'");
	$str = state_to_str($state);
	foreach $check_id (@check_ids) {
		info("Setting state of check '$check_id' to '$str'\n");
		config_check_set_state($check_id, $state);
	}

	return;
err:
	die("Cannot set check state '$spec': $msg");
}

#
# check_set_ex_severity(spec)
#
# Set exception severity according to SPEC. SPEC can take one of the following
# formats:
# <check_id>.<ex_id>=<value> -> change severity of exception for specified check
# <ex_id>=<value>            -> change severity of exception for selected checks
#
sub check_set_ex_severity($)
{
	my ($spec) = @_;
	my @check_ids;
	my $check_id;
	my $ex_id;
	my $sev;
	my $str;
	my $msg;

	if ($spec =~ /^($MATCH_ID)\.($MATCH_ID)=(.*)$/i) {
		($check_id, $ex_id, $sev) = (lc($1), lc($2), $3);

		if (!db_check_exists($check_id)) {
			$msg = "check '$check_id' does not exist!\n";
			goto err;
		}
		if (!db_check_ex_exists($check_id, $ex_id)) {
			$msg = "exception does not exist: ".
			       "'$check_id.$ex_id'!\n";
			goto err;
		}
		push(@check_ids, $check_id);
	} elsif ($spec =~ /^($MATCH_ID)=(.*)$/i) {
		($ex_id, $sev) = (lc($1), $2);
		my @selected_ids = check_get_selected_ids();

		if (!@selected_ids) {
			$msg = "no check was selected!\n";
			goto err;
		}
		foreach $check_id (@selected_ids) {
			if (db_check_ex_exists($check_id, $ex_id)) {
				push(@check_ids, $check_id);
			} else {
				warn("Check '$check_id' does not define ".
				     "exception '$ex_id' - skipping\n");
			}
		}
		if (!@check_ids) {
			warn("None of the selected checks defines exception ".
			     "'$ex_id' - skipping\n");
			return;
		}
	} else {
		$msg = <<EOF;
unrecognized format!
Try '$main::tool_inv check --ex-severity CHECK_ID.EX_ID=SEVERITY' or
    '$main::tool_inv check --ex-severity EX_ID=SEVERITY SELECT'
EOF
		goto err;
	}

	$sev = str_to_sev($sev, "Cannot set exception severity '$spec'");
	$str = sev_to_str($sev);

	foreach $check_id (@check_ids) {
		info("Setting exception severity of '$check_id.$ex_id' to ".
		      "'$str'\n");
		config_check_set_ex_severity($check_id, $ex_id, $sev);
	}

	return;

err:
	die("Cannot set exception severity '$spec': $msg");
}

#
# check_set_ex_state(spec)
#
# Set exception state according to SPEC. SPEC can take one of the following
# formats:
# <check_id>.<ex_id>=<value>  -> change state of exception for specified check
# <ex_id>=<value> E           -> change state of exception for selected checks
#
sub check_set_ex_state($)
{
	my ($spec) = @_;
	my @check_ids;
	my $check_id;
	my $ex_id;
	my $state;
	my $str;
	my $msg;

	if ($spec =~ /^($MATCH_ID)\.($MATCH_ID)=(.*)$/i) {
		($check_id, $ex_id, $state) = (lc($1), lc($2), $3);

		if (!db_check_exists($check_id)) {
			$msg = "check '$check_id' does not exist!\n";
			goto err;
		}
		if (!db_check_ex_exists($check_id, $ex_id)) {
			$msg = "exception does not exist: ".
			       "'$check_id.$ex_id'!\n";
			goto err;
		}
		push(@check_ids, $check_id);
	} elsif ($spec =~ /^($MATCH_ID)=(.*)$/i) {
		($ex_id, $state) = (lc($1), $2);
		my @selected_ids = check_get_selected_ids();

		if (!@selected_ids) {
			$msg = "no check was selected!\n";
			goto err;
		}
		foreach $check_id (@selected_ids) {
			if (db_check_ex_exists($check_id, $ex_id)) {
				push(@check_ids, $check_id);
			} else {
				warn("Check '$check_id' does not define ".
				     "exception '$ex_id' - skipping\n");
			}
		}
		if (!@check_ids) {
			warn("None of the selected checks defines exception ".
			     "'$ex_id' - skipping\n");
			return;
		}
	} else {
		$msg = <<EOF;
unrecognized format!
Try '$main::tool_inv check --ex-state CHECK_ID.EX_ID=SEVERITY' or
    '$main::tool_inv check --ex-state EX_ID=SEVERITY SELECT'
EOF
		goto err;
	}

	$state = str_to_state($state, "Cannot set exception state '$spec'");
	$str = state_to_str($state);

	foreach $check_id (@check_ids) {
		config_check_set_ex_state($check_id, $ex_id, $state);
		info("Setting exception state of '$check_id.$ex_id' to ".
		      "'$str'\n");
	}

	return;

err:
	die("Cannot set exception state '$spec': $msg");
}

#
# check_set_si_rec_duration(spec)
#
# Set sysinfo record duration according to SPEC. SPEC can take one of the
# following formats:
# CHECK_ID.SI_ID=VALUE  -> change duration of sysinfo item for specified check
# SI_ID=VALUE           -> change duration of sysinfo item for selected checks
#
sub check_set_si_rec_duration($)
{
	my ($spec) = @_;
	my @check_ids;
	my $check_id;
	my $si_id;
	my $duration;
	my $msg;

	if ($spec =~ /^($MATCH_ID)\.($MATCH_ID)=(.*)$/i) {
		my $type;

		($check_id, $si_id, $duration) = (lc($1), lc($2), $3);

		if (!db_check_exists($check_id)) {
			$msg = "check '$check_id' does not exist!\n";
			goto err;
		}
		if (!db_check_si_exists($check_id, $si_id)) {
			$msg = "sysinfo item does not exist: ".
			       "'$check_id.$si_id'!\n";
			goto err;
		}
		$type = db_check_get_si_type($check_id, $si_id);
		if (!defined($type) || $type != $SI_TYPE_T_REC) {
			$msg = "item is not a sysinfo record item: ".
			       "'$check_id.$si_id'!\n";
			goto err;
		}
		push(@check_ids, $check_id);
	} elsif ($spec =~ /^($MATCH_ID)=(.*)$/i) {
		($si_id, $duration) = (lc($1), $2);
		my @selected_ids = check_get_selected_ids();

		if (!@selected_ids) {
			$msg = "no check was selected!\n";
			goto err;
		}
		foreach $check_id (@selected_ids) {
			my $type = db_check_get_si_type($check_id, $si_id);
			if (defined($type) && $type == $SI_TYPE_T_REC) {
				push(@check_ids, $check_id);
			} else {
				warn("Check '$check_id' does not define ".
				     "sysinfo record item '$si_id' - ".
				     "skipping\n");
			}
		}
		if (!@check_ids) {
			warn("None of the selected checks defines sysinfo ".
			     "record item '$si_id' - skipping\n");
			return;
		}
	} else {
		$msg = <<EOF;
unrecognized format!
Try '$main::tool_inv check --rec-duration CHECK_ID.SI_ID=INTERVAL' or
    '$main::tool_inv check --rec-duration SI_ID=INTERVAL SELECT'
EOF
		goto err;
	}

	$msg = validate_duration_nodie($duration, 1);
	if (defined($msg)) {
		$msg .= "!\n";
		goto err;
	}

	foreach $check_id (@check_ids) {
		config_check_set_si_rec_duration($check_id, $si_id, $duration);
		info("Setting record duration of '$check_id.$si_id' to ".
		      "'$duration'\n");
	}

	return;

err:
	die("Cannot set record duration '$spec': $msg");
}

#
# check_set_defaults()
#
# Set configuration for selected checks to default values.
#
sub check_set_defaults()
{
	my @check_ids = check_get_selected_ids();
	my $check_id;

	if (!@check_ids) {
		die("No check was selected!\n");
	}

	# Set defaults for all selected checks
	foreach $check_id (@check_ids) {
		info("Setting default configuration values for check ".
		     "'$check_id'\n");
		config_check_set_defaults($check_id);
	}
}

#
# check_install(dir)
#
# Install check from DIR.
#
sub check_install($)
{
	my ($dir) = @_;
	my $check;
	my $check_id;

	# Add to database
	$check = db_check_install($dir);
	$check_id = $check->[$CHECK_T_ID];

	if ($opt_system) {
		info("Installed check '$check_id' in system-wide ".
		     "database\n");
	} else {
		info("Installed check '$check_id' in user database\n");
	}
}

#
# check_uninstall()
#
# Remove selected checks.
#
sub check_uninstall()
{
	my @check_ids = check_get_selected_ids();
	my $check_id;

	if (!@check_ids) {
		die("No check was selected!\n");
	}
	foreach $check_id (@check_ids) {
		# Remove from database
		db_check_uninstall($check_id);

		if ($opt_system) {
			info("Removed check '$check_id' from system-wide ".
			     "database\n");
		} else {
			info("Removed check '$check_id' from user database\n");
		}
	}
}

#
# check_get_si_data_id(check_id, sysinfo)
#
# Return a normalized string representation of the data for the specified
# SYSINFO item or undef if it is a reference.
#
# The normalized string has the following format:
# <type>:<check_id>:<type specific id>
#
# type: one of file, program, record, external
# check_id: if this sysinfo item relies on check specific programs, this
#           is the ID of the check. Otherwise this is an empty string.
# type specific id:
#    for files: path to the file to be read
#    for programs: command line of the program to be run
#    for record items: start:stop:duration of the record item. If start, stop
#                      or duration contain a colon (':'), that is replaced
#                      by two colons ('::')
#    for external items: sysinfo ID
#
sub check_get_si_data_id($$)
{
	my ($check_id, $sysinfo) = @_;
	my ($si_id, $type, $data) = @$sysinfo;
	my $type_str = "";
	my $check_id_str = "";
	my $data_str = "";

	if ($type == $SI_TYPE_T_FILE) {
		my ($filename) = @$data;

		$type_str = "file";
		$data_str = $filename;
	} elsif ($type == $SI_TYPE_T_PROG) {
		my ($cmdline) = @$data;

		$type_str = "program";

		# Determine if sysinfo item has a dependency on a check
		# specific program.
		if ($cmdline =~ /\$$CHECK_DIR_VAR/) {
			$check_id_str = $check_id;
		}

		$data_str = $cmdline;
	} elsif ($type == $SI_TYPE_T_REC) {
		my ($start, $stop, $duration) = @$data;

		$type_str = "record";

		# Determine if sysinfo item has a dependency on a check
		# specific program.
		if (($start =~ /\$$CHECK_DIR_VAR/) ||
		    ($stop =~ /\$$CHECK_DIR_VAR/)) {
			$check_id_str = $check_id;
		}

		# Need to escape : so that start:stop:duration cannot be
		# accidentally matched if either element contains a :
		$start =~ s/:/::/g;
		$stop =~ s/:/::/g;
		$duration =~ s/:/::/g;

		$data_str = "$start:$stop:$duration";
	} elsif ($type == $SI_TYPE_T_EXT) {
		$type_str = "external";
		$check_id_str = $check_id;
		$data_str = $si_id;
	} else {
		# Default is that items cannot be compared
		return undef;
	}

	return "$type_str:$check_id_str:$data_str";
}

#
# check_resolve_si_ref(check_id, si_id[, nodie])
#
# If sysinfo item CHECK_ID.SI_ID is a sysinfo reference item, return
# (check_id, si_id) of the target item. If it is not a reference item, return
# (check_id, si_id) of the item itself. If NODIE is set and a reference is
# invalid, return (undef, undef, err). Otherwise abort with an error message.
#
sub check_resolve_si_ref($$;$)
{
	my ($check_id, $si_id, $nodie) = @_;
	my $orig_check_id = $check_id;
	my $orig_si_id = $si_id;
	my $err;
	my %visited;
	my @sequence;

	push(@sequence, "$check_id.$si_id");
	$visited{$check_id}->{$si_id} = 1;
	do {
		my $check = db_check_get($check_id);
		my $si_db;
		my $si;
		my $new_check_id;
		my $new_si_id;
		my $data;

		if (!defined($check)) {
			$err = "check '$check_id' does not exist";
			goto err;
		}
		$si_db = $check->[$CHECK_T_SI_DB];
		if (!exists($si_db->{$si_id})) {
			$err = "sysinfo item '$check_id.$si_id' does not exist";
			goto err;
		}
		$si = $si_db->{$si_id};
		if ($si->[$SYSINFO_T_TYPE] != $SI_TYPE_T_REF) {
			return ($check_id, $si_id);
		}
		$data = $si->[$SYSINFO_T_DATA];
		($new_check_id, $new_si_id) = @$data;
		push(@sequence, "$new_check_id.$new_si_id");
		if (exists($visited{$new_check_id}->{$new_si_id})) {
			$err = "circular reference found: ".
			       join(" -> ", @sequence);
			goto err;
		}
		$visited{$new_check_id}->{$new_si_id} = 1;
		$check_id = $new_check_id;
		$si_id = $new_si_id;
	} while (1);

err:
	if ($nodie) {
		return (undef, undef, $err);
	}
	die("Could not resolve sysinfo reference '$orig_check_id.".
	    "$orig_si_id': $err!\n");
}

#
# check_get_data_id(check_id, si_id[, nodie])
#
# Return data ID of the specified check CHECK_ID and sysinfo SI_ID. If
# NODIE is true and the data ID could not be determined, return (err, undef).
#
sub check_get_data_id($$;$)
{
	my ($check_id, $si_id, $nodie) = @_;
	my $source = "$check_id.$si_id";
	my $check;
	my $si_db;
	my $sysinfo;
	my $err;

	$check = db_check_get($check_id);
	if (!defined($check)) {
		$err =  "check '$check_id' does not exist";
		goto err;
	}
	$si_db = $check->[$CHECK_T_SI_DB];
	if (!exists($si_db->{$si_id})) {
		$err =  "sysinfo item '$si_id' does not exist";
		goto err,
	}
	$sysinfo = $si_db->{$si_id};

	if ($sysinfo->[$SYSINFO_T_TYPE] == $SI_TYPE_T_REF) {
		($check_id, $si_id, $err) =
			check_resolve_si_ref($check_id, $si_id, 1);
		if (defined($err)) {
			goto err;
		}
		$check = db_check_get($check_id);
		$si_db = $check->[$CHECK_T_SI_DB];
		$sysinfo = $si_db->{$si_id};
	}

	return (undef, check_get_si_data_id($check_id, $sysinfo));

err:
	if ($nodie) {
		return ($err, undef);
	}
	die("Could not determine data ID for '$source': $err!\n");
}

#
# check_show_data_id(spec)
#
# Show data ID associated with sysinfo item specified by SPEC. SPEC can take
# one of the following formats:
#   <check_id>.<si_id>   -> show specified data ID
#   <si_id>              -> show data ID for selected checks
#
sub check_show_data_id($)
{
	my ($spec) = @_;
	my @sources;

	if ($spec =~ /^($MATCH_ID)\.($MATCH_ID_WILDCARD)$/i) {
		my ($check_id, $si_pattern) = (lc($1), lc($2));
		my @si_ids;
		my $check = db_check_get($check_id);
		my $si_db;

		if (!defined($check)) {
			die("Check '$check_id' does not exist!\n");
		}
		$si_db = $check->[$CHECK_T_SI_DB];
		if ($si_pattern =~ /[\*\?]/) {
			@si_ids = sort(keys(%{$si_db}));
			@si_ids = filter_ids_by_wildcard($si_pattern,
						"sysinfo item IDs", @si_ids);
		} else {
			if (!exists($si_db->{$si_pattern})) {
				die("Sysinfo item '$check_id.$si_pattern' ".
				    "does not exist!\n");
			}
			push(@si_ids, $si_pattern);
		}
		foreach my $si_id (@si_ids) {
			push(@sources, [ $check_id, $si_id ]);
		}
	} elsif ($spec =~ /^($MATCH_ID_WILDCARD)$/i) {
		my $si_pattern = lc($1);
		my @check_ids;

		if ($_selection_active) {
			@check_ids = check_get_selected_ids();
		} else {
			@check_ids = db_check_get_ids();
		}
		foreach my $check_id (@check_ids) {
			my $check = db_check_get($check_id);
			my $si_db = $check->[$CHECK_T_SI_DB];
			my @si_ids;

			if ($si_pattern =~ /[\*\?]/) {
				@si_ids = sort(keys(%{$si_db}));
				@si_ids = filter_ids_by_wildcard($si_pattern,
						"sysinfo item IDs", @si_ids);
			} else {
				if (exists($si_db->{$si_pattern})) {
					push(@si_ids, $si_pattern);
				}
			}
			foreach my $si_id (@si_ids) {
				push(@sources, [ $check_id, $si_id ]);
			}
		}
		if (!@sources) {
			if ($_selection_active) {
				warn("None of the selected checks defines ".
				     "sysinfo item '$si_pattern'\n");
			} else {
				warn("No check defines sysinfo item ".
				     "'$si_pattern'\n");
			}
			return;
		}
	} else {
		die(<<EOF);
Unrecognized parameter format!
Use 'CHECK.SYSINFO_ID' to show the data ID of a specific sysinfo item.
Use 'SYSINFO_ID' to show the data ID of sysinfo items of selected or all checks.
EOF
	}

	foreach my $source (@sources) {
		my ($check_id, $si_id) = @$source;

		print("$check_id.$si_id=".check_get_data_id($check_id, $si_id).
		      "\n");
	}
}

#
# _add_su_cmds(su_db, check, si)
#
# Identify command lines of CHECK and SI that require changing user IDs and
# add them to su_db:
# su_db: username -> cmd_db
# cmd_db: cmdline  -> 1
#
sub _add_su_cmds($$$)
{
	my ($su_db, $check, $si) = @_;
	my ($id, $type, $data) = @$si;
	my $dir = $check->[$CHECK_T_DIR];
	my @cmds;

	if ($type == $SI_TYPE_T_FILE) {
		my $user = $data->[$SI_FILE_DATA_T_USER];
		my $filename = $data->[$SI_FILE_DATA_T_FILENAME];

		if ($user ne "") {
			push(@cmds, [ $user, "$CAT_TOOL $filename" ]);
		}
	} elsif ($type == $SI_TYPE_T_PROG) {
		my $user = $data->[$SI_PROG_DATA_T_USER];
		my $cmdline = $data->[$SI_PROG_DATA_T_CMDLINE];

		if ($user ne "") {
			push(@cmds, [ $user, $cmdline ]);
		}
	} elsif ($type == $SI_TYPE_T_REC) {
		my $user = $data->[$SI_REC_DATA_T_USER];
		my $start = $data->[$SI_REC_DATA_T_START];
		my $stop = $data->[$SI_REC_DATA_T_STOP];

		if ($user ne "") {
			push(@cmds, [ $user, $start ]);
			push(@cmds, [ $user, $stop ]);
		}
	}

	foreach my $entry (@cmds) {
		my ($user, $cmd) = @$entry;

		if ($cmd =~ s/\$$CHECK_DIR_VAR/$dir/g &&
		    !$check->[$CHECK_T_SYSTEM]) {
			warn("Check ".$check->[$CHECK_T_ID]." requires SUDO ".
			     "for a helper program that is not installed ".
			     "system-wide:\n".$cmd."\n");
		}
		$su_db->{$user}->{$cmd} = 1;
	}
}

#
# check_show_sudoers(user)
#
# Display the contents of a sudo-compatible configuration file that
# authorizes the specified user to obtain root privileges for performing
# all data collection actions defined by the active health checks.
#
sub check_show_sudoers($)
{
	my ($user) = @_;
	my @check_ids;
	my %su_db;

	if ($_selection_active) {
		@check_ids = check_get_selected_ids();
	} else {
		@check_ids = db_check_get_ids();
	}

	return if (!@check_ids);

	foreach my $check_id (sort(@check_ids)) {
		my $check = db_check_get($check_id);
		my $si_db = $check->[$CHECK_T_SI_DB];

		foreach my $si_id (sort(keys(%{$si_db}))) {
			_add_su_cmds(\%su_db, $check, $si_db->{$si_id});
		}
	}

	foreach my $cmd_user (sort(keys(%su_db))) {
		my $cmd_db = $su_db{$cmd_user};

		foreach my $cmd (sort(keys(%{$cmd_db}))) {
			print("$user ALL=($cmd_user)NOPASSWD:$cmd\n");
		}
	}
}


#
# Code entry
#

# Indicate successful module initialization
1;
