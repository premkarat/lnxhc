#
# LNXHC::SIDS.pm
#   Linux Health Checker system information management
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

package LNXHC::SIDS;

use strict;
use warnings;

use Exporter qw(import);
use Cwd qw(getcwd);


#
# Local imports
#
use LNXHC::Check qw(check_get_data_id check_get_selected_ids
		    check_get_si_data_id check_resolve_si_ref
		    check_selection_is_active);
use LNXHC::Config qw(config_check_get_active_ids
		     config_check_get_si_rec_duration_or_default
		     config_hosts_get);
use LNXHC::Consts qw($CHECK_DIR_VAR $CHECK_T_DIR $CHECK_T_SI_DB $COLUMNS
		     $MATCH_ID $MATCH_ID_CHAR $MATCH_ID_WILDCARD $PROP_EXP_NEVER
		     $PROP_EXP_NO_PRIO $PROP_EXP_PRIO $RC_T_FAILED
		     $SIDS_HOST_T_ID $SIDS_HOST_T_ITEMS $SIDS_HOST_T_SYSVAR_DB
		     $SIDS_INST_T_HOSTS $SIDS_INST_T_ID $SIDS_ITEM_T_DATA
		     $SIDS_ITEM_T_DATA_ID $SIDS_ITEM_T_END_TIME
		     $SIDS_ITEM_T_ERR_DATA $SIDS_ITEM_T_EXIT_CODE
		     $SIDS_ITEM_T_START_TIME $SI_TYPE_T_EXT $SI_TYPE_T_FILE
		     $SI_TYPE_T_PROG $SI_TYPE_T_REC $SI_TYPE_T_REF
		     $SYSINFO_T_DATA $SYSINFO_T_TYPE $SI_FILE_DATA_T_USER
		     $SI_PROG_DATA_T_USER $SI_REC_DATA_T_USER);
use LNXHC::DBCheck qw(db_check_exists db_check_get db_check_get_si
		      db_check_si_exists);
use LNXHC::DBSIDS qw(db_sids_clear db_sids_host_add db_sids_host_delete
		     db_sids_host_exists db_sids_host_get db_sids_host_get_nums
		     db_sids_host_id_to_num db_sids_inst_add db_sids_inst_delete
		     db_sids_inst_exists db_sids_inst_get db_sids_inst_get_nums
		     db_sids_inst_id_to_num db_sids_item_add db_sids_item_delete
		     db_sids_item_exists db_sids_item_get db_sids_item_get_nums
		     db_sids_item_id_to_num db_sids_set_modified);
use LNXHC::Misc qw($opt_debug $opt_verbose debug duration_to_sec get_hostname
		   get_indented get_time get_timestamp info info1 info2
		   output_filename print_padded read_file read_file_as
		   read_stdin run_cmd sec_to_duration timestamp_to_str unique
		   needs_user_id_change get_colors);
use LNXHC::Prop qw(prop_parse_key);
use LNXHC::SIDSXML qw(sids_xml_read sids_xml_write);
use LNXHC::SysVar qw(sysvar_check_deps sysvar_get_copy);
use LNXHC::Util qw($ALIGN_T_LEFT $ALIGN_T_RIGHT layout_get_width lprintf);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&sids_add_data &sids_clear &sids_collect &sids_export
		    &sids_import &sids_list &sids_merge &sids_new
		    &sids_remove_properties &sids_set_property &sids_set_sysvar
		    &sids_show &sids_show_property &sids_show_sysvar
		    &sids_show_data);


#
# Constants
#

# Sysinfo property IDs
# <inst_num>
my $_PROP_INST			= 0;
# <inst_num>.id
my $_PROP_INST_ID		= 1;
# <inst_num>.host.<host_num>
my $_PROP_HOST			= 2;
# <inst_num>.host.<host_num>.id
my $_PROP_HOST_ID		= 3;
# <inst_num>.host.<host_num>.sysvar.<sysvar_id>
my $_PROP_HOST_SYSVAR		= 4;
# <inst_num>.host.<host_num>.item.<item_num>
my $_PROP_ITEM			= 5;
# <inst_num>.host.<host_num>.item.<item_num>.id
my $_PROP_ITEM_ID		= 6;
# <inst_num>.host.<host_num>.item.<item_num>.start_time
my $_PROP_ITEM_START_TIME	= 7;
# <inst_num>.host.<host_num>.item.<item_num>.end_time
my $_PROP_ITEM_END_TIME		= 8;
# <inst_num>.host.<host_num>.item.<item_num>.exit_code
my $_PROP_ITEM_EXIT_CODE	= 9;
# <inst_num>.host.<host_num>.item.<item_num>.data
my $_PROP_ITEM_DATA		= 10;
# <inst_num>.host.<host_num>.item.<item_num>.err_data
my $_PROP_ITEM_ERR_DATA		= 11;

# Property ID type definition
my $_PROP_ID_T_TAG		= 0;
my $_PROP_ID_T_INST_NUM		= 1;
my $_PROP_ID_T_HOST_NUM		= 2;
my $_PROP_ID_T_SYSVAR_ID	= 3;
my $_PROP_ID_T_ITEM_NUM		= 3;

# Marker for property IDs which represent a composite property
my %_PROP_COMP = (
	$_PROP_INST	=> 1,
	$_PROP_HOST	=> 1,
	$_PROP_ITEM	=> 1,
);

# Sysinfo data set property definition map: keydef => prop_tag
my %_PDEF_MAP = (
	"<inst_num>"
		=> $_PROP_INST,
	"<inst_num>.id"
		=> $_PROP_INST_ID,
	"<inst_num>.host.<host_num>"
		=> $_PROP_HOST,
	"<inst_num>.host.<host_num>.id"
		=> $_PROP_HOST_ID,
	"<inst_num>.host.<host_num>.sysvar.<sysvar_id>"
		=> $_PROP_HOST_SYSVAR,
	"<inst_num>.host.<host_num>.item.<item_num>"
		=> $_PROP_ITEM,
	"<inst_num>.host.<host_num>.item.<item_num>.id"
		=> $_PROP_ITEM_ID,
	"<inst_num>.host.<host_num>.item.<item_num>.start_time"
		=> $_PROP_ITEM_START_TIME,
	"<inst_num>.host.<host_num>.item.<item_num>.end_time"
		=> $_PROP_ITEM_END_TIME,
	"<inst_num>.host.<host_num>.item.<item_num>.exit_code"
		=> $_PROP_ITEM_EXIT_CODE,
	"<inst_num>.host.<host_num>.item.<item_num>.data"
		=> $_PROP_ITEM_DATA,
	"<inst_num>.host.<host_num>.item.<item_num>.err_data"
		=> $_PROP_ITEM_ERR_DATA,
);

# Sort groups
my $_PROP_GROUP_INST	= 0;
my $_PROP_GROUP_HOST	= 1;
my $_PROP_GROUP_SYSVAR	= 2;
my $_PROP_GROUP_ITEM	= 3;

# Sort group mapping
my %_PROP_SORT_GROUP = (
	$_PROP_INST		=> $_PROP_GROUP_INST,
	$_PROP_INST_ID		=> $_PROP_GROUP_INST,
	$_PROP_HOST		=> $_PROP_GROUP_HOST,
	$_PROP_HOST_ID		=> $_PROP_GROUP_HOST,
	$_PROP_HOST_SYSVAR	=> $_PROP_GROUP_SYSVAR,
	$_PROP_ITEM		=> $_PROP_GROUP_ITEM,
	$_PROP_ITEM_ID		=> $_PROP_GROUP_ITEM,
	$_PROP_ITEM_START_TIME	=> $_PROP_GROUP_ITEM,
	$_PROP_ITEM_END_TIME	=> $_PROP_GROUP_ITEM,
	$_PROP_ITEM_EXIT_CODE	=> $_PROP_GROUP_ITEM,
	$_PROP_ITEM_DATA	=> $_PROP_GROUP_ITEM,
	$_PROP_ITEM_ERR_DATA	=> $_PROP_GROUP_ITEM,
);

# Forward declarations
sub _ns_inst_nums_get($$$);
sub _ns_inst_num_is_valid($$$);
sub _ns_host_nums_get($$$);
sub _ns_host_num_is_valid($$$);
sub _ns_sysvar_ids_get($$$);
sub _ns_sysvar_id_is_valid($$$);
sub _ns_item_nums_get($$$);
sub _ns_item_num_is_valid($$$);

# Sysinfo data set property namespace map
# ns_id => [ type, regexp, fn_get_ids, fn_get_selected_ids, fn_id_is_valid ]
my %_PDEF_NS = (
	"<inst_num>" =>
		[ "instance number", '[\d\?\*]+',
		  \&_ns_inst_nums_get, undef, \&_ns_inst_num_is_valid ],
	"<host_num>" =>
		[ "host number", '[\d\?\*]+',
		  \&_ns_host_nums_get, undef, \&_ns_host_num_is_valid ],
	"<sysvar_id>" =>
		[ "system variable ID", $MATCH_ID_WILDCARD,
		  \&_ns_sysvar_ids_get, undef, \&_ns_sysvar_id_is_valid ],
	"<item_num>" =>
		[ "item number", '[\d\?\*]+',
		  \&_ns_item_nums_get, undef, \&_ns_item_num_is_valid ],
);


#
# Global variables
#


#
# Sub-routines
#

#
# _ns_inst_nums_get(subkeys, level, create)
#
# Return list of instance numbers.
#
sub _ns_inst_nums_get($$$)
{
	my ($subkeys, $level, $create) = @_;

	return db_sids_inst_get_nums();
}

#
# _ns_inst_num_is_valid(subkeys, level, create)
#
# Return non-zero if specified instance number is valid.
#
sub _ns_inst_num_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $inst_num = $subkeys->[0];

	if ($inst_num !~ /^\s*\d+\s*$/) {
		return 0;
	}

	if ($create) {
		return 1;
	}

	return db_sids_inst_exists($inst_num);
}

#
# _ns_host_nums_get(subkey, level, create)
#
# Return list of host numbers.
#
sub _ns_host_nums_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $inst_num = $subkeys->[0];

	return db_sids_host_get_nums($inst_num);
}

#
# _ns_host_num_is_valid(subkeys, level, create)
#
# Return non-zero if specified host number is valid.
#
sub _ns_host_num_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $inst_num = $subkeys->[0];
	my $host_num = $subkeys->[$level];

	if ($host_num !~ /^\s*\d+\s*$/) {
		return 0;
	}

	if ($create) {
		return 1;
	}

	return db_sids_host_exists($inst_num, $host_num);
}

#
# _ns_sysvar_ids_get(subkeys, level, create)
#
# Return list of sysvar IDs.
#
sub _ns_sysvar_ids_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $inst_num = $subkeys->[0];
	my $host_num = $subkeys->[2];
	my $sysvar_id = $subkeys->[$level];
	my $host = db_sids_host_get($inst_num, $host_num);

	if (!defined($host)) {
		return ();
	}

	return keys(%{$host->[$SIDS_HOST_T_SYSVAR_DB]});
}

#
# _ns_sysvar_id_is_valid(subkeys, level, create)
#
# Return non-zero if specified sysvar ID is valid.
#
sub _ns_sysvar_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $inst_num = $subkeys->[0];
	my $host_num = $subkeys->[2];
	my $sysvar_id = $subkeys->[$level];
	my $host = db_sids_host_get($inst_num, $host_num);

	if ($create) {
		# Check if this ID can be created
		if ($sysvar_id =~ /^$MATCH_ID$/i) {
			return 1;
		}
		return 0;
	}

	if (defined($host->[$SIDS_HOST_T_SYSVAR_DB]->{$sysvar_id})) {
		return 1;
	}

	return 0;
}

#
# _ns_item_nums_get(subkeys, level, create)
#
# Return list of item numbers.
#
sub _ns_item_nums_get($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $inst_num = $subkeys->[0];
	my $host_num = $subkeys->[2];

	return db_sids_item_get_nums($inst_num, $host_num);
}

#
# _ns_item_num_is_valid(subkeys, level, create)
#
# Return non-zero if specified item number is valid.
#
sub _ns_item_num_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $inst_num = $subkeys->[0];
	my $host_num = $subkeys->[2];
	my $item_num = $subkeys->[$level];

	if ($item_num !~ /^\s*\d+\s*$/) {
		return 0;
	}

	if ($create) {
		return 1;
	}

	return db_sids_item_exists($inst_num, $host_num, $item_num);
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
# Return the value of a property PROP_ID.
#
sub _get_property_value($)
{
	my ($prop_id) = @_;
	my ($tag, $inst_num, $host_num, $sub_id) = @$prop_id;
	my $inst = db_sids_inst_get($inst_num);
	my $host;
	my $item;

	if (!defined($inst)) {
		return undef;
	}
	# Filter out composite properties
	if ($_PROP_COMP{$tag}) {
		return undef;
	}
	# Instance related
	if ($tag == $_PROP_INST_ID) {
		return $inst->[$SIDS_INST_T_ID];
	}
	# Host-related
	$host = $inst->[$SIDS_INST_T_HOSTS]->[$host_num];
	if (!defined($host)) {
		return undef;
	}
	if ($tag == $_PROP_HOST_ID) {
		return $host->[$SIDS_HOST_T_ID];
	} elsif ($tag == $_PROP_HOST_SYSVAR) {
		my $sysvar_db = $host->[$SIDS_HOST_T_SYSVAR_DB];

		return $sysvar_db->{$sub_id};
	}
	# Item related
	$item = $host->[$SIDS_HOST_T_ITEMS]->[$sub_id];
	if (!defined($item)) {
		return undef;
	}
	if ($tag == $_PROP_ITEM_ID) {
		return $item->[$SIDS_ITEM_T_DATA_ID];
	} elsif ($tag == $_PROP_ITEM_START_TIME) {
		return $item->[$SIDS_ITEM_T_START_TIME];
	} elsif ($tag == $_PROP_ITEM_END_TIME) {
		return $item->[$SIDS_ITEM_T_END_TIME];
	} elsif ($tag == $_PROP_ITEM_EXIT_CODE) {
		return $item->[$SIDS_ITEM_T_EXIT_CODE];
	} elsif ($tag == $_PROP_ITEM_DATA) {
		return $item->[$SIDS_ITEM_T_DATA];
	} elsif ($tag == $_PROP_ITEM_ERR_DATA) {
		return $item->[$SIDS_ITEM_T_ERR_DATA];
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
	my ($tag, $inst_num, $host_num, $sub_id) = @$prop_id;

	if ($tag == $_PROP_INST) {
		return "$inst_num";
	} elsif ($tag == $_PROP_INST_ID) {
		return "$inst_num.id";
	} elsif ($tag == $_PROP_HOST) {
		return "$inst_num.host.$host_num";
	} elsif ($tag == $_PROP_HOST_ID) {
		return "$inst_num.host.$host_num.id";
	} elsif ($tag == $_PROP_HOST_SYSVAR) {
		return "$inst_num.host.$host_num.sysvar.$sub_id";
	} elsif ($tag == $_PROP_ITEM) {
		return "$inst_num.host.$host_num.item.$sub_id";
	} elsif ($tag == $_PROP_ITEM_ID) {
		return "$inst_num.host.$host_num.item.$sub_id.id";
	} elsif ($tag == $_PROP_ITEM_START_TIME) {
		return "$inst_num.host.$host_num.item.$sub_id.start_time";
	} elsif ($tag == $_PROP_ITEM_END_TIME) {
		return "$inst_num.host.$host_num.item.$sub_id.end_time";
	} elsif ($tag == $_PROP_ITEM_EXIT_CODE) {
		return "$inst_num.host.$host_num.item.$sub_id.exit_code";
	} elsif ($tag == $_PROP_ITEM_DATA) {
		return "$inst_num.host.$host_num.item.$sub_id.data";
	} elsif ($tag == $_PROP_ITEM_ERR_DATA) {
		return "$inst_num.host.$host_num.item.$sub_id.err_data";
	}

	return undef;
}

#
# _set_property_value(prop_id, value)
#
# Set value of property PROP_ID to VALUE.
#
sub _set_property_value($$)
{
	my ($prop_id, $value) = @_;
	my ($tag, $inst_num, $host_num, $sub_id) = @$prop_id;
	my $inst = db_sids_inst_get($inst_num);
	my $host;
	my $item;

	if (!defined($inst)) {
		return;
	}
	if ($tag == $_PROP_INST || $tag == $_PROP_HOST || $tag == $_PROP_ITEM) {
		goto err;
	}
	# Instance related
	if ($tag == $_PROP_INST_ID) {
		if (defined(db_sids_inst_id_to_num($value))) {
			die("Cannot change instance ID: ".
			    "'$value' already exists!\n");
		}
		info("Changing instance ID from '".$inst->[$SIDS_INST_T_ID].
		     "' to '$value'\n");
		$inst->[$SIDS_INST_T_ID] = $value;
		goto commit;
	}
	# Host-related
	$host = $inst->[$SIDS_INST_T_HOSTS]->[$host_num];
	if (!defined($host)) {
		return;
	}
	if ($tag == $_PROP_HOST_ID) {
		if (defined(db_sids_host_id_to_num($inst_num, $value))) {
			die("Cannot change host ID: '$value' ".
			    "already exists!\n");
		}
		info("Changing host ID from '".$host->[$SIDS_HOST_T_ID]."' to ".
		     "'$value'\n");
		$host->[$SIDS_HOST_T_ID] = $value;
		goto commit;
	} elsif ($tag == $_PROP_HOST_SYSVAR) {
		my $sysvar_db = $host->[$SIDS_HOST_T_SYSVAR_DB];

		info("Setting value of sysvar '$sub_id' to '$value'!\n");
		$sysvar_db->{$sub_id} = $value;
		goto commit;
	}
	# Item related
	$item = $host->[$SIDS_HOST_T_ITEMS]->[$sub_id];
	if (!defined($item)) {
		return;
	}
	if ($tag == $_PROP_ITEM_ID) {
		if (defined(db_sids_item_id_to_num($inst_num, $host_num,
						   $value))) {
			die("Cannot change data ID: '$value' already ".
			    "exists!\n");
		}
		info("Changing data ID from '".$item->[$SIDS_ITEM_T_DATA_ID].
		     "' to '$value'\n");
		$item->[$SIDS_ITEM_T_DATA_ID] = $value;
		goto commit;
	} elsif ($tag == $_PROP_ITEM_START_TIME) {
		if ($value !~ /^\d+(\.\d+)?$/) {
			die("Cannot change start time: unknown timestamp ".
			    "format '$value'!\n");
		}
		info("Setting item start time to '$value'\n");
		$item->[$SIDS_ITEM_T_START_TIME] = $value;
		goto commit;
	} elsif ($tag == $_PROP_ITEM_END_TIME) {
		if ($value !~ /^\d+(\.\d+)?$/) {
			die("Cannot change end time: unknown timestamp ".
			    "format '$value'!\n");
		}
		info("Setting item end time to '$value'\n");
		$item->[$SIDS_ITEM_T_END_TIME] = $value;
		goto commit;
	} elsif ($tag == $_PROP_ITEM_EXIT_CODE) {
		if ($value !~ /^\d+$/) {
			die("Cannot change exit code: not an unsigned integer ".
			    "number '$value'!\n");
		}
		info("Setting item exit code to '$value'\n");
		$item->[$SIDS_ITEM_T_EXIT_CODE] = $value;
		goto commit;
	} elsif ($tag == $_PROP_ITEM_DATA) {
		info("Setting item data\n");
		$item->[$SIDS_ITEM_T_DATA] = $value;
		goto commit;
	} elsif ($tag == $_PROP_ITEM_ERR_DATA) {
		info("Setting item error data\n");
		$item->[$SIDS_ITEM_T_ERR_DATA] = $value;
		goto commit;
	}

err:
	die("Cannot set property '"._get_property_key($prop_id)."': ".
	    "property cannot be modified!\n");

commit:
	db_sids_set_modified(1);
}

#
# _fix_nums(prop_id)
#
# Find and set the current correct entity numbers for instances, hosts and
# items according to the IDs added by _extend_ids(). Return non-zero on
# success, zero if the entity no longer exists.
#
sub _fix_nums($)
{
	my ($prop_id) = @_;
	my ($tag, $inst_num, $host_num, $item_num) = @$prop_id;
	my ($inst_id, $host_id, $item_id);

	# Get IDs stored by _extend_ids()
	$inst_id = $prop_id->[4];
	$host_id = $prop_id->[5];
	$item_id = $prop_id->[6];

	# Find current numbers
	if (defined($inst_id)) {
		$inst_num = db_sids_inst_id_to_num($inst_id);
		return 0 if (!defined($inst_num));
	}
	if (defined($host_id)) {
		$host_num = db_sids_host_id_to_num($inst_num, $host_id);
		return 0 if (!defined($host_num));
	}
	if (defined($item_id)) {
		$item_num = db_sids_item_id_to_num($inst_num, $host_num,
						   $item_id);
		return 0 if (!defined($item_num));
	}

	# Store current numbers
	$prop_id->[$_PROP_ID_T_INST_NUM] = $inst_num;
	$prop_id->[$_PROP_ID_T_HOST_NUM] = $host_num;
	$prop_id->[$_PROP_ID_T_ITEM_NUM] = $item_num;

	return 1;
}

#
# _remove_property(prop_id)
#
# Remove property PROP_ID.
#
sub _remove_property($)
{
	my ($prop_id) = @_;
	my ($tag, $inst_num, $host_num, $sub_id);
	my $key = _get_property_key($prop_id);

	# Ensure that entity numbers are still valid (they could have changed
	# or been removed)
	if (!_fix_nums($prop_id)) {
		# This property has already been removed. Don't report this
		# as an error.
		return;
	}
	($tag, $inst_num, $host_num, $sub_id) = @$prop_id;
	if ($tag == $_PROP_INST) {
		my $inst = db_sids_inst_get($inst_num);
		my $inst_id = $inst->[$SIDS_INST_T_ID];

		info("Removing sysinfo instance '$key' ($inst_id)\n");
		db_sids_inst_delete($inst_num);
	} elsif ($tag == $_PROP_HOST) {
		my $host = db_sids_host_get($inst_num, $host_num);
		my $host_id = $host->[$SIDS_HOST_T_ID];

		info("Removing sysinfo host data '$key' ($host_id)\n");
		db_sids_host_delete($inst_num, $host_num);
	} elsif ($tag == $_PROP_ITEM) {
		my $item = db_sids_item_get($inst_num, $host_num, $sub_id);
		my $data_id = $item->[$SIDS_ITEM_T_DATA_ID];

		info("Removing sysinfo item data '$key' ($data_id)\n");
		db_sids_item_delete($inst_num, $host_num, $sub_id);
	} elsif ($tag == $_PROP_HOST_SYSVAR) {
		my $host = db_sids_host_get($inst_num, $host_num);
		my $sysvar_db = $host->[$SIDS_HOST_T_SYSVAR_DB];

		if (!defined($sysvar_db->{$sub_id})) {
			die("Cannot remove sysvar '$sub_id': sysvar does not ".
			    "exist!\n");
		}
		info("Removing sysvar value '$sub_id'\n");
		delete($host->[$SIDS_HOST_T_SYSVAR_DB]->{$sub_id});
		db_sids_set_modified(1);
	} else {
		die("Cannot remove '$key': property cannot be ".
		    "removed!\n");
	}
}

#
# sids_clear([quiet])
#
# Clear current data set.
#
sub sids_clear(;$)
{
	my ($quiet) = @_;

	if (!$quiet) {
		info("Clearing system information data\n");
	}

	db_sids_clear();
}

#
# _get_minimum_sysinfo_list()
#
# Determine minimum list of sysinfo items required by active checks.
#
# result: [ ref1, ref2, ... ]
# ref: [ check_id, si_id, item_id ]
#
# Note: sysinfo reference items are replaced by their reference target if
# possible. All references/external sysinfo items that remain are
# unresolved/invalid.
#
sub _get_minimum_sysinfo_list()
{
	my %known;
	my @check_ids;
	my $check_id;
	my @result;
	my ($red, $green, $blue, $bold, $reset) = get_colors();

	info2("Determining list of sysinfo items to be collected\n");

	# Determine list of checks scheduled to run
	if (check_selection_is_active()) {
		@check_ids = check_get_selected_ids();
	} else {
		@check_ids = config_check_get_active_ids();
	}

	# Process all checks scheduled to run
	foreach $check_id (@check_ids) {
		my $check = db_check_get($check_id);
		my $si_db = $check->[$CHECK_T_SI_DB];
		my $si_id;
		my $msg;
		my $dep;

		# Skip sysinfo items if check dependencies are not fulfilled
		($msg, $dep) = sysvar_check_deps($check);
		if (!$dep) {
			if (!$opt_verbose) {
				next;
			}
			# Print a line for each skipped item
			foreach $si_id (sort(keys(%{$si_db}))) {
				info2(sprintf("  %-*s  [".$blue.
					      "NOT APPLICABLE".$reset."]\n",
					      $COLUMNS - 20,
					      "$check_id.$si_id"));
				info2("    dependency failed: $msg\n");
			}
			next;
		}

		# Process all sysinfo items of this check
		foreach $si_id (sort(keys(%{$si_db}))) {
			my $si = $si_db->{$si_id};
			my $type = $si->[$SYSINFO_T_TYPE];
			my $data_id;
			my $code = "";
			my $details;
			my $source = "$check_id.$si_id";

			# Special handling for sysinfo reference items: use
			# data of reference target
			if ($type == $SI_TYPE_T_REF) {
				my ($tcheck_id, $tsi_id, $err) =
					check_resolve_si_ref($check_id, $si_id,
							     1);

				if (defined($err)) {
					$code = $red."UNRESOLVED".$reset;
					$details = $err;
					goto info;
				}
				$si = db_check_get_si($tcheck_id, $tsi_id);
				$check_id = $tcheck_id;
				$si_id = $tsi_id;
			}

			# Check if data for this sysinfo item can be provided
			# by another item
			$data_id = check_get_si_data_id($check_id, $si);
			if (!defined($data_id)) {
				# Item cannot be compared
				$code = $green."COLLECT".$reset;
				$details = "item cannot be compared";
				push(@result,
				     [ $check_id, $si_id, undef ]);
			} elsif (!defined($known{$data_id})) {
				# Item is not yet in the list
				$code = $green."COLLECT".$reset;
				push(@result,
				     [ $check_id, $si_id, $data_id ]);
				$known{$data_id} = "$check_id.$si_id";
			} else {
				# Item is in the list
				$code = $green."DUPLICATE".$reset;
				$details = "duplicate of ".$known{$data_id};
			}
info:
			info2(sprintf("  %-*s  [%s]\n", $COLUMNS - 20,
				      $source, $code));
			if (defined($details)) {
				info2("    $details\n");
			}
		}
	}

	@result = sort { $a->[2] cmp $b->[2] } @result;

	return \@result;
}

#
# _collect_sysinfo_file(si_data)
#
# Collect data for a sysinfo file item specified by SI_DATA. RC indicates if
# data collection was successful. DATA contains the collected data. ERROR
# contains an error message if data collection failed.
#
# result: ( exit_code, data, error )
#
sub _collect_sysinfo_file($)
{
	my ($si_data) = @_;
	my ($filename, $user) = @$si_data;
	my $exit_code;
	my $data;
	my $error;

	if ($user eq "") {
		($error, $data) = read_file($filename, 1);
	} else {
		($error, $data) = read_file_as($filename, $user, 1);
	}
	if (defined($data)) {
		$exit_code = 0;
	} else {
		$exit_code = 1;
	}

	return ( $exit_code, $data, $error );
}

#
# _add_si_prog_env(env, sysvar_db)
#
# Add environment variables for running sysinfo programs.
#
sub _add_si_prog_env($$)
{
	my ($env, $sysvar_db) = @_;
	my $sysvar_id;

	# C Locale - set this to ensure that check programs don't need to
	# implement locale-specific parsing of locale-aware sysinfo program
	# output.
	$env->{"LC_ALL"} = "C";

	# System variables
	foreach $sysvar_id (keys(%{$sysvar_db})) {
		my $value = $sysvar_db->{$sysvar_id};

		$env->{"LNXHC_SYS_$sysvar_id"} = $value;
	}
}

#
# _adjust_results(exit_code, data, err)
#
# Adjust results of running a program. Return (exit_code, data, err_data).
#
sub _adjust_results($$$)
{
	my ($exit_code, $data, $err) = @_;

	if (defined($err)) {
		# Command could not be started
		$exit_code = 1;
	} elsif ($exit_code != 0) {
		# Command exited with non-zero exit code
		$err = $data;
		$data = undef;
	}

	return ($exit_code, $data, $err);
}

#
# _collect_sysinfo_prog(si_data, dir, sysvar_db)
#
# Collect data for a sysinfo program item specified by SI_DATA. DIR specifies
# the check directory. RC indicates if data collection was successful. DATA
# contains the collected data. ERROR contains an error message if data
# collection failed.
#
# result: ( rc, data, error )
#
sub _collect_sysinfo_prog($$$)
{
	my ($si_data, $dir, $sysvar_db) = @_;
	my ($cmdline, $user, $ignorerc) = @$si_data;
	my $data;
	my $err;
	my $exit_code;
	my %env;
	my $old_dir = getcwd();

	# Mark user as undefined if it is not present
	if ($user eq "") {
		$user = undef;
	}

	# Set LNXHC_CHECK_DIR variable
	$env{$CHECK_DIR_VAR} = $dir;
	_add_si_prog_env(\%env, $sysvar_db);

	# Change working directory
	chdir($dir) or die("Could not change to directory '$dir': $!\n");

	# Perform command
	($err, $exit_code, $data) = run_cmd($cmdline, $user, 1, undef, \%env);

	chdir($old_dir);

	return _adjust_results($exit_code, $data, $err);
}

#
# _collect_sysinfo_rec(si_data, dir, sysvar_db, check_id, si_id)
#
# Collect data for a sysinfo record item specified by SI_DATA. DIR specifies
# the check directory RC indicates if data collection was successful. DATA
# contains the collected data. ERROR contains an error message if data
# collection failed.
#
# result: ( rc, data, error )
#
sub _collect_sysinfo_rec($$$$$)
{
	my ($si_data, $dir, $sysvar_db, $check_id, $si_id) = @_;
	my ($start, $stop, $duration, $user) = @$si_data;
	my $duration_sec;
	my $rc = $RC_T_FAILED;
	my $data;
	my $err;
	my $exit_code;
	my %env;
	my $old_dir = getcwd();

	$duration_sec = config_check_get_si_rec_duration_or_default($check_id,
								    $si_id);
	$duration_sec = duration_to_sec($duration_sec);
	# Mark user as undefined if it is not present
	if ($user eq "") {
		$user = undef;
	}

	# Set LNXHC_CHECK_DIR variable
	$env{$CHECK_DIR_VAR} = $dir;
	_add_si_prog_env(\%env, $sysvar_db);

	# Change working directory
	chdir($dir) or die("Could not change to directory '$dir': $!\n");

	# Perform start command
	($err, $exit_code, $data) = run_cmd($start, $user, 1, undef, \%env);

	chdir($old_dir);

	# Process results
	($exit_code, $data, $err) = _adjust_results($exit_code, $data, $err);
	if ($exit_code != 0) {
		goto out;
	}

	# Wait for duration
	info("Recording data for ".sec_to_duration($duration_sec)." (until ".
	     get_time($duration_sec).") ...\n");
	sleep($duration_sec);

	# Change working directory
	chdir($dir) or die("Could not change to directory '$dir': $!\n");

	# Perform stop command, passing start's output as input on the
	# standard input stream
	($err, $exit_code, $data) = run_cmd($stop, $user, 1, $data, \%env);

	chdir($old_dir);

	# Process results
	($exit_code, $data, $err) = _adjust_results($exit_code, $data, $err);

out:
	return ($exit_code, $data, $err);
}

#
# _get_si_user(si)
#
# Return the value for the user= statement of sysinfo item SI or undef if
# no user is defined.
#
sub _get_si_user($)
{
	my ($si) = @_;
	my $type = $si->[$SYSINFO_T_TYPE];
	my $data = $si->[$SYSINFO_T_DATA];

	return $data->[$SI_FILE_DATA_T_USER] if ($type == $SI_TYPE_T_FILE);
	return $data->[$SI_PROG_DATA_T_USER] if ($type == $SI_TYPE_T_PROG);
	return $data->[$SI_REC_DATA_T_USER] if ($type == $SI_TYPE_T_REC);

	return undef;
}

#
# _collect_sysinfo_list(si_refs, sysvar_db, no_sudo)
#
# Collect all sysinfo items found in SI_REFS.
#
# si_refs: [ ref1, ref2, ...]
# ref: [ check_id, si_id, item_id ]
#
# result: list of sids_item_t
#
sub _collect_sysinfo_list($$$)
{
	my ($si_refs, $sysvar_db, $no_sudo) = @_;
	my $si_ref;
	my @items;
	my ($red, $green, $blue, $bold, $reset) = get_colors();

	foreach $si_ref (@$si_refs) {
		my ($check_id, $si_id, $data_id) = @$si_ref;
		my $check = db_check_get($check_id);
		my $dir = $check->[$CHECK_T_DIR];
		my $check_si_db = $check->[$CHECK_T_SI_DB];
		my $sysinfo = $check_si_db->{$si_id};
		my $si_type = $sysinfo->[$SYSINFO_T_TYPE];
		my $si_data = $sysinfo->[$SYSINFO_T_DATA];
		my $start_time;
		my $end_time;
		my $exit_code = 1;
		my $data;
		my $err_data;
		my $needs_sudo;
		my $sudo_prompt = 0;

		info1(sprintf("    %-*s", $COLUMNS - 13, $data_id));

		# Check sudo requirement
		$needs_sudo = needs_user_id_change(_get_si_user($sysinfo));
		if ($needs_sudo && $no_sudo) {
			info1("[".$blue."SKIPPED".$reset."]\n");
			next;
		}

		# Ensure newline in case of sudo prompt
		if ($opt_verbose > 0 && $needs_sudo) {
			printf("\n");
			$sudo_prompt = 1;
		}

		# Collect sysinfo item
		$start_time = get_timestamp();
		if ($si_type == $SI_TYPE_T_FILE) {
			($exit_code, $data, $err_data) =
				_collect_sysinfo_file($si_data);
		} elsif ($si_type == $SI_TYPE_T_PROG) {
			($exit_code, $data, $err_data) =
				_collect_sysinfo_prog($si_data, $dir,
						      $sysvar_db);
		} elsif ($si_type == $SI_TYPE_T_REC) {
			if ($opt_verbose >= 1) {
				# _collect function prints text
				print("\n");
			}
			($exit_code, $data, $err_data) =
				_collect_sysinfo_rec($si_data, $dir,
						     $sysvar_db, $check_id,
						     $si_id);
		} elsif ($si_type == $SI_TYPE_T_REF) {
			my ($target_check_id, $target_si_id) = @$si_data;

			$err_data = "unresolved reference to ".
				    "$target_check_id.$target_si_id";
		} elsif ($si_type == $SI_TYPE_T_EXT) {
			$err_data = "unresolved external sysinfo item";
		}
		$end_time = get_timestamp();

		# Ensure indentation in case of sudo prompt
		print(" "x($COLUMNS - 9)) if ($sudo_prompt);
		if ($exit_code != 0) {
			info1("[".$red."FAILED ".$reset."]\n");
			info2("      Exit code: $exit_code\n");

			if (defined($err_data) && $err_data ne "") {
				my $e = $err_data;
				chomp($e);
				info2("      Output:\n");
				info2(get_indented($e, 8));
			}
		} else {
			info1("[".$green."SUCCESS".$reset."]\n");
		}

		# Add sids_item_t
		push(@items, [ $data_id, $start_time, $end_time, $exit_code,
			       $data, $err_data ]);
	}

	return \@items;
}

#
# _sids_collect_from_local()
#
# Collect sysinfo data for all active checks from local host and return
# resulting sids_coll_t.
#
sub _sids_collect_from_local($)
{
	my ($no_sudo) = @_;
	my $host_id;
	my $sysvar_db;
	my $items;
	my $si_refs;

	$host_id = get_hostname();
	# Copy system variables describing the local system
	$sysvar_db = sysvar_get_copy();
	# Determine list of unique sysinfo items
	$si_refs = _get_minimum_sysinfo_list();
	# Collect data for unique sysinfo items
	info2("Collecting data\n");
	$items = _collect_sysinfo_list($si_refs, $sysvar_db, $no_sudo);

	# Return sids_host_t
	return [ $host_id, $sysvar_db, $items ];
}

#
# _sids_collect_from_host(host_id, local_host_id, no_sudo)
#
# Collect sysinfo data for all active checks from host HOST_ID.
#
sub _sids_collect_from_host($$$)
{
	my ($host_id, $local_host_id, $no_sudo) = @_;
	my $host;

	if ($host_id eq $local_host_id) {
		# Gather system information from local host
		$host = _sids_collect_from_local($no_sudo);
		$host->[$SIDS_HOST_T_ID] = $host_id;

		return $host;
	}
	die("unimplemented function: collect sysinfo from remote host ".
	    "'$host_id'\n");
}

#
# sids_collect([inst_id, local_host_id, no_sudo])
#
# Collect sysinfo data for all active checks. Result is stored as current
# data set. Use INST_ID as instance ID if specified, otherwise use a generated
# instance ID. Use LOCAL_HOST_ID as ID of local host if specified, otherwise
# use actual local host ID. Do not collect sysinfo data requiring a user change
# if no_sudo is set.
#
sub sids_collect(;$$$)
{
	my ($inst_id, $local_host_id, $no_sudo) = @_;
	my $host_ids;
	my $host_id;
	my @hosts;
	my $inst;

	info("Collecting system information".
	     ($no_sudo ? " (skipping sudo)":"")."\n");

	# Query hostname if necessary
	if (!defined($local_host_id)) {
		$local_host_id = get_hostname();
	}

	# Create new instance ID if necessary
	if (!defined($inst_id)) {
		$inst_id = timestamp_to_str(get_timestamp(), 0);
	}

	# Use local host if no host list was specified
	$host_ids = config_hosts_get();
	if (!defined($host_ids) || !@$host_ids) {
		$host_ids = [ $local_host_id ];
	}

	# Get data for each specified host
	foreach $host_id (@$host_ids) {
		my $host;

		if ($host_id eq "localhost") {
			# Convert local host to global host ID
			$host_id = $local_host_id;
		}
		info1("  Host '$host_id'\n");
		$host = _sids_collect_from_host($host_id, $local_host_id,
						$no_sudo);

		push(@hosts, $host);
	}

	# Create sids_inst_t
	$inst = [ $inst_id, \@hosts ];

	# Add to database
	db_sids_inst_add($inst);
}

#
# sids_export(filename[, quiet])
#
# Export current data set to file FILENAME. If QUIET is non-zero, don't write
# a message.
#
sub sids_export($;$)
{
	my ($filename, $quiet) = @_;
	my $handle;

	# Select output handle
	if (!$quiet) {
		info("Exporting sysinfo data to ".output_filename($filename).
		     "\n");
	}
	if ($filename eq "-") {
		$handle = *STDOUT;
	} else {
		open($handle, ">", $filename) or
			die("Could not write to file '$filename': $!\n");
	}

	# Write XML stream
	sids_xml_write($handle);

	# Close handle
	if ($filename ne "-") {
		close($handle);
	}
}

#
# sids_import(filename[, inst_id, host_id, quiet])
#
# Import current data set from file FILENAME.
#
sub sids_import($;$$$)
{
	my ($filename, $inst_id, $host_id, $quiet) = @_;
	my $handle;

	# Select input handle
	if ($filename eq "-") {
		if (!$quiet) {
			info("Importing sysinfo data from standard input\n");
		}
		$handle = *STDIN;
	} else {
		if (!$quiet) {
			info("Importing sysinfo data from file '$filename'\n");
		}
		if (! -e $filename) {
			die("File '$filename' does not exist!\n");
		}
		if (! -f $filename) {
			die("Could not read file '$filename': not a regular ".
			    "file!\n");
		}
		open($handle, "<", $filename) or
			die("Could not read file '$filename': $!\n");
	}

	# Import data set
	sids_xml_read($handle, $filename, 0, $inst_id, $host_id);

	# Close handle
	if ($filename ne "-") {
		close($handle);
	}
}

#
# sids_merge(filename[, inst_id, host_id, quiet])
#
# Merge contents of file FILENAME to current data set
#
sub sids_merge($;$$$)
{
	my ($filename, $inst_id, $host_id, $quiet) = @_;
	my $handle;

	# Select input handle
	if ($filename eq "-") {
		if (!$quiet) {
			info("Merging sysinfo data from standard input\n");
		}
		$handle = *STDIN;
	} else {
		if (!$quiet) {
			info("Merging sysinfo data from file '$filename'\n");
		}
		if (! -e $filename) {
			die("File '$filename' does not exist!\n");
		}
		if (! -f $filename) {
			die("Could not read file '$filename': not a regular ".
			    "file!\n");
		}
		open($handle, "<", $filename) or
			die("could not read file '$filename': $!\n");
	}

	# Read data from file
	sids_xml_read($handle, $filename, 1, $inst_id, $host_id);

	# Close handle
	if ($filename ne "-") {
		close($handle);
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
# _print_inst_heading(inst)
#
# Print heading for sids instance INST
#
sub _print_inst_heading($)
{
	my ($inst) = @_;
	my $inst_id = $inst->[$SIDS_INST_T_ID];
	my $num = scalar(@{$inst->[$SIDS_INST_T_HOSTS]});
	my $heading;

	if ($num == 1) {
		$heading = "Instance '$inst_id' ($num host)";
	} else {
		$heading = "Instance '$inst_id' ($num hosts)";

	}
	print("$heading\n");
	print(("="x(length($heading)))."\n");
}

#
# _print_item_data(item)
#
# Print sids item data for ITEM.
#
sub _print_item_data($)
{
	my ($item) = @_;
	my ($data_id, $start_time, $end_time, $exit_code, $data,
	    $err_data) = @$item;
	my $duration = sprintf("%.3f", $end_time - $start_time);
	my $rc_str = ($exit_code == 0 ? "OK" : "FAILED");

	print("\n  Item '$data_id' ($rc_str)\n");
	print_padded(4, 14, "Start time", timestamp_to_str($start_time, 1));
	print_padded(4, 14, "End time", timestamp_to_str($end_time, 1).
		      " (+".$duration."s)");
	print_padded(4, 14, "Exit code", $exit_code);
	if (defined($data)) {
		my $line;

		print("    Data:\n");
		foreach $line (split(/\n/, $data)) {
			print("      |$line\n");
		}
	}
	if (defined($err_data)) {
		my $line;

		print("    Error data:\n");
		foreach $line (split(/\n/, $err_data)) {
			print("      |$line\n");
		}
	}

}

#
# _print_host_data(host)
#
# Print sids host data for HOST.
#
sub _print_host_data($)
{
	my ($host) = @_;
	my ($host_id, $sysvar_db, $items) = @$host;
	my $item;
	my $num = scalar(@$items);
	my $sysvar;

	# Print heading
	if ($num == 1) {
		print("Host '$host_id' ($num item)\n");
	} else {
		print("Host '$host_id' ($num items)\n");

	}
	# Print sysvars
	if (%{$sysvar_db}) {
		print("\n  System variables:\n");
		foreach $sysvar (sort(keys(%{$sysvar_db}))) {
			print_padded(4, 20, $sysvar, $sysvar_db->{$sysvar});
		}
	}
	# Print item data
	foreach $item (@$items) {
		_print_item_data($item);
	}
}

#
# _print_details(inst)
#
# Print detailed sids information for instance INST.
#
sub _print_details($)
{
	my ($inst) = @_;
	my $hosts = $inst->[$SIDS_INST_T_HOSTS];
	my $host;
	my $nl = "";

	_print_inst_heading($inst);
	foreach $host (@$hosts) {
		print($nl);
		$nl = "\n";
		_print_host_data($host);
	}
}

#
# sids_show()
#
# Print detailed sids information.
#
sub sids_show()
{
	my @inst_nums = db_sids_inst_get_nums();
	my $inst_num;
	my $nl = "";

	if (!@inst_nums) {
		die("No system information found!\n");
	}
	foreach $inst_num (sort(@inst_nums)) {
		my $inst = db_sids_inst_get($inst_num);

		print($nl);
		$nl = "\n";
		_print_details($inst);
	}
}

#
# _prop_cmp(a, b)
#
# Compare two sids property IDs.
#
sub _prop_cmp($$)
{
	my ($a, $b) = @_;
	my ($tag_a, $inst_num_a, $host_num_a, $sub_id_a) = @$a;
	my ($tag_b, $inst_num_b, $host_num_b, $sub_id_b) = @$b;
	my $group_a = $_PROP_SORT_GROUP{$tag_a};
	my $group_b = $_PROP_SORT_GROUP{$tag_b};

	if ($inst_num_a != $inst_num_b) {
		# Instance number
		return $inst_num_a <=> $inst_num_b;
	} elsif ($group_a != $group_b) {
		return $group_a <=> $group_b;
	} elsif ($group_a == $_PROP_GROUP_INST) {
		return $tag_a <=> $tag_b;
	} elsif ($host_num_a != $host_num_b) {
		# Host number
		return $host_num_a <=> $host_num_b;
	} elsif ($group_a == $_PROP_GROUP_SYSVAR) {
		# Sysvar ID
		return $sub_id_a cmp $sub_id_b;
	} elsif ($group_a == $_PROP_GROUP_ITEM) {
		# Item number
		if ($sub_id_a != $sub_id_b) {
			return $sub_id_a <=> $sub_id_b;
		}
	}

	return $tag_a <=> $tag_b;
}

#
# sids_show_property(keys)
#
# Print sids properties specified by KEYS.
#
sub sids_show_property($)
{
	my ($keys) = @_;
	my $key;
	my @prop_ids;
	my $prop_id;
	my $last_key;

	# Convert keys into list of property IDs
	foreach $key (@$keys) {
		my @list = _get_property_ids($key, $PROP_EXP_PRIO);

		if (@list) {
			push(@prop_ids, @list);
		} else {
			warn("Key '$key' matched no properties\n");
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
# _extend_ids(prop_ids)
#
# Replace all number sub-IDs in PROP_IDS with their actual ID. This is
# necessary for remove operations since removal of an entity changes the
# number of the following entities.
#
sub _extend_ids($)
{
	my ($prop_ids) = @_;

	foreach my $prop_id (@$prop_ids) {
		my ($tag, $inst_num, $host_num, $item_num) = @$prop_id;
		my $inst = db_sids_inst_get($inst_num);
		my ($inst_id, $host_id, $item_id);

		# Retrieve IDs
		$inst_id = $inst->[$SIDS_INST_T_ID];
		if (defined($host_num)) {
			my $host = $inst->[$SIDS_INST_T_HOSTS]->[$host_num];

			$host_id = $host->[$SIDS_HOST_T_ID];

			if ($tag != $_PROP_HOST_SYSVAR && defined($item_num)) {
				my $item = $host->[$SIDS_HOST_T_ITEMS]->
						[$item_num];

				$item_id = $item->[$SIDS_ITEM_T_DATA_ID];
			}
		}

		# Store IDs
		$prop_id->[4] = $inst_id;
		$prop_id->[5] = $host_id;
		$prop_id->[6] = $item_id;
	}
}

#
# sids_remove_properties(keys)
#
# Remove specified properties from current data set.
#
sub sids_remove_properties($)
{
	my ($keys) = @_;
	my $key;
	my @prop_ids;
	my $prop_id;
	my $last_key;

	# Convert keys into list of property IDs
	foreach $key (@$keys) {
		my @list = _get_property_ids($key, $PROP_EXP_NO_PRIO);

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
		_remove_property($prop_id);
	}
}

#
# sids_set_property(key, value)
#
# Set value of sids properties identified by KEY to VALUE.
#
sub sids_set_property($$)
{
	my ($key, $value) = @_;
	my @prop_ids;
	my $prop_id;

	# Convert key to list of IDs
	@prop_ids = _get_property_ids($key, $PROP_EXP_NEVER);

	if (!@prop_ids) {
		warn("Key '$key' matched no properties\n");
		return;
	}

	# Perform operation for each ID
	foreach $prop_id (@prop_ids) {
		_set_property_value($prop_id, $value);
		if ($opt_debug) {
			_print_property($prop_id);
		}
	}
}

#
# _get_last_or_new_inst_id()
#
# If sids database contains at least one instance entry, return the ID of the
# last instance in the list. Otherwise create a new one.
#
sub _get_last_or_new_inst_id()
{
	my @nums = db_sids_inst_get_nums();

	if (@nums) {
		my $inst = db_sids_inst_get($nums[$#nums]);

		return $inst->[$SIDS_INST_T_ID];
	} else {
		return timestamp_to_str(get_timestamp(), 0);
	}
}

#
# _get_last_or_new_host_id(inst_num)
#
# If sids database contains at least one host entry for instance INST_NUM,
# return the ID of the last host in the list. Otherwise create a new one.
#
sub _get_last_or_new_host_id($)
{
	my ($inst_num) = @_;
	my @nums = db_sids_host_get_nums($inst_num);

	if (@nums) {
		my $host = db_sids_host_get($inst_num, $nums[$#nums]);

		return $host->[$SIDS_HOST_T_ID];
	} else {
		return get_hostname();
	}
}

#
# _get_last_or_new([inst_id[, host_id]])
#
# Locate existing sids instance and host entries for the specified INST_ID
# and HOST_ID. If these entries don't exists, create new ones. If INST_ID or
# HOST_ID is not specified, create new IDs and entries.
#
# Return (inst_num, host_num, exists) of the resulting entries.
#
sub _get_last_or_new(;$$)
{
	my ($inst_id, $host_id) = @_;
	my $inst_num;
	my $host_num;
	my $exists = 1;

	# Determine inst_id
	if (!defined($inst_id)) {
		$inst_id = _get_last_or_new_inst_id();
	}
	$inst_num = db_sids_inst_id_to_num($inst_id);
	if (!defined($inst_num)) {
		# Add new sids_inst_t
		my $inst = [ $inst_id, [] ];

		db_sids_inst_add($inst);
		$inst_num = db_sids_inst_id_to_num($inst_id);
		$exists = 0;
	}

	# Determine host_id
	if (!defined($host_id)) {
		$host_id = _get_last_or_new_host_id($inst_num);
	}
	$host_num = db_sids_host_id_to_num($inst_num, $host_id);
	if (!defined($host_num)) {
		# Add new sids_host_t
		my $host = [ $host_id, sysvar_get_copy(), [] ];

		db_sids_host_add($inst_num, $host);
		$host_num = db_sids_host_id_to_num($inst_num, $host_id);
		$exists = 0;
	}

	return ($inst_num, $host_num, $exists);
}

#
# sids_new([inst_id, host_id])
#
# Add an empty sids data set, either with the specified IDs or with new IDs.
#
sub sids_new(;$$)
{
	my ($inst_id, $host_id) = @_;
	my $inst_num;
	my $host_num;
	my $create;

	# Create new instance if necessary
	if (!defined($inst_id)) {
		$inst_id = timestamp_to_str(get_timestamp(), 0);
	}
	$inst_num = db_sids_inst_id_to_num($inst_id);
	if (!defined($inst_num)) {
		db_sids_inst_add([ $inst_id, [] ]);
		$create = 1;
		$inst_num = db_sids_inst_id_to_num($inst_id);
	}
	# Add/replace host
	if (!defined($host_id)) {
		$host_id = get_hostname();
	}
	$host_num = db_sids_host_id_to_num($inst_num, $host_id);
	if (!defined($host_num)) {
		$create = 1;
	}
	db_sids_host_add($inst_num, [ $host_id, sysvar_get_copy(), [] ]);
	$host_num = db_sids_host_id_to_num($inst_num, $host_id);

	if ($create) {
		info("Adding empty data set as '$inst_num.host.$host_num'\n");
	} else {
		info("Replacing '$inst_num.host.$host_num' with empty data ".
		     "set\n");
	}
}

#
# _process_item_id_spec(spec[, add_op])
#
# Retrieve list of data_ids and the filename defined by the given add-data
# parameter SPEC. If ADD_OP is set, assume an add-data operation and check for
# a trailing =<filename>. Otherwise assume a show-data operation.
#
sub _process_item_id_spec($;$)
{
	my ($spec, $add_op) = @_;
	my $op = $add_op ? "add" : "show";
	my $fn = $add_op ? "=(.*)" : "";
	my @data_ids;
	my $filename;
	my $err;

	if ($spec =~ /^($MATCH_ID)\.($MATCH_ID)$fn$/i) {
		my $check_id;
		my $si_id;
		my $data_id;

		($check_id, $si_id, $filename) = (lc($1), lc($2), $3);
		if (!db_check_exists($check_id)) {
			$err = "check '$check_id' does not exist";
			goto usage_err;
		}
		if (!db_check_si_exists($check_id, $si_id)) {
			$err = "sysinfo item '$check_id.$si_id' does not exist";
			goto usage_err;
		}
		($err, $data_id) = check_get_data_id($check_id, $si_id);
		push(@data_ids, $data_id);
	} elsif ($spec =~ /^($MATCH_ID)$fn$/i) {
		my @check_ids;
		my $si_id;

		($si_id, $filename) = (lc($1), $2);

		# Repeat for each check
		if (check_selection_is_active()) {
			@check_ids = check_get_selected_ids();
		} else {
			@check_ids = config_check_get_active_ids();
		}

		foreach my $check_id (@check_ids) {
			my $data_id;

			next if (!db_check_si_exists($check_id, $si_id));
			info("Found sysinfo item ID '$si_id' in check ".
			     "'$check_id'\n");
			($err, $data_id) = check_get_data_id($check_id, $si_id);
			push(@data_ids, $data_id);
		}
		if (!@data_ids) {
			$err = "none of the active checks defines sysinfo ".
			       "item with ID '$si_id'";
			goto usage_err;
		}
	} elsif ($spec =~ /^([a-z]+:[$MATCH_ID_CHAR]*:.*)$fn$/) {
		my $data_id;

		($data_id, $filename) = ($1, $2);

		if ($data_id !~ /^(file|program|record|ext)::/) {
			$err = "unknown data ID format";
			goto usage_err;
		}
		push(@data_ids, $data_id);
	} else {
		$err = "unknown parameter format";
		goto usage_err;
	}

	return (\@data_ids, $filename);

usage_err:
	die("Cannot $op data for '$spec': $err!\n");
}

#
# sids_add_data(spec[, inst_id, host_id])
#
# Add data according to SPEC. SPEC can take either of the following formats:
#   <item_id>=<filename>
#   <check_id>.<sysinfo_id>=<filename>
#   <sysinfo_id>=<filename>
# If INST_ID is specified, data is added for this instance, otherwise the last
# instance ID is used or a new one is generated if there is no instance yet.
# If HOST_ID is specified, data is added for that host, otherwise the last
# host ID is used or a new one is generated if there is no host data yet.
#
sub sids_add_data($;$$)
{
	my ($spec, $inst_id, $host_id) = @_;
	my ($data_ids, $filename);
	my $data;
	my $time;
	my ($inst_num, $host_num, $replace);
	my $err;
	my %done;

	# Determine target IDs
	($data_ids, $filename) = _process_item_id_spec($spec, 1);

	# Determine data content
	if ($filename eq "-") {
		$data = read_stdin();
	} else {
		# Resolve "~" since shell had no chance to
		if ($filename =~ /^~\// && defined($ENV{"HOME"})) {
			$filename =~ s/^~/$ENV{"HOME"}/;
		}

		($err, $data) = read_file($filename, 1);
		if (defined($err)) {
			goto runtime_err;
		}
	}
	$time = get_timestamp();

	# Get container information
	($inst_num, $host_num, $replace) = _get_last_or_new($inst_id, $host_id);

	# Store data for each ID
	foreach my $data_id (@$data_ids) {
		my $item;
		my $item_num;

		next if ($done{$data_id});

		# Add sids_item_t
		$item = [ $data_id, $time, $time, 0, $data, undef ];
		db_sids_item_add($inst_num, $host_num, $item);
		$item_num = db_sids_item_id_to_num($inst_num, $host_num,
						   $data_id);
		if ($replace) {
			info("Replacing data for ".
			     "'$inst_num.host.$host_num.item.$item_num'\n");
		} else {
			info("Adding data as ".
			     "'$inst_num.host.$host_num.item.$item_num'\n");
		}

		$done{$data_id} = 1;
	}

	return;

runtime_err:
	die("Could not add data '$spec': $err!\n");
}

#
# sids_show_data(spec[, inst_id, host_id])
#
# Print the data associated with the sysinfo item defined by SPEC.
#
sub sids_show_data($;$$)
{
	my ($spec, $inst_id, $host_id) = @_;
	my $data_ids;
	my $data_id;
	my ($inst_num, $host_num, $item_num);
	my $exists;
	my $item;

	# Determine data ID
	($data_ids) = _process_item_id_spec($spec, 0);
	@$data_ids = unique(@$data_ids);
	if (scalar(@$data_ids) > 1) {
		die("More than one data ID matches specification '$spec'!\n");
	}
	$data_id = $data_ids->[0];

	# Get container information
	($inst_num, $host_num, $exists) = _get_last_or_new($inst_id, $host_id);
	if (!$exists) {
		if (defined($inst_id) || defined($host_id)) {
			die("No sysinfo data found for the specified instance ".
			    "and/or host ID!\n");
		} else {
			die("No sysinfo data found!\n");
		}
	}
	$item_num = db_sids_item_id_to_num($inst_num, $host_num, $data_id);
	if (!defined($item_num)) {
		if (defined($inst_id) || defined($host_id)) {
			die("No sysinfo item found for '$spec' for ".
			    "the specified instance and/or host ID!\n");
		} else {
			die("No sysinfo item found for '$spec'!\n");
		}
	}
	$item = db_sids_item_get($inst_num, $host_num, $item_num);
	if (!defined($item->[$SIDS_ITEM_T_DATA])) {
		die("No data available for the specified sysinfo item!\n"); 
	}
	print($item->[$SIDS_ITEM_T_DATA]);
}

#
# _get_item_size(item)
#
# Return size of data of sids item ITEM.
#
sub _get_item_size($)
{
	my ($item) = @_;
	my $size = 0;

	if (defined($item->[$SIDS_ITEM_T_DATA])) {
		$size += length($item->[$SIDS_ITEM_T_DATA]);
	} elsif (defined($item->[$SIDS_ITEM_T_ERR_DATA])) {
		$size += length($item->[$SIDS_ITEM_T_ERR_DATA]);
	}

	return $size;
}

#
# _format_size(size)
#
# Return a string representing SIZE in bytes
#
sub _format_size($)
{
	my ($size) = @_;
	my $suffix = "B";
	my $str;

	if ($size >= 1024 * 1024) {
		$suffix = "M";
		$size = $size / (1024 * 1024);
	} elsif ($size >= 1024) {
		$suffix = "K";
		$size = $size / 1024;
	}
	$str = sprintf("%.1f", $size);
	if (length($str) > 3) {
		$str = sprintf("%d", $size);
	}
	return "$str$suffix";
}

#
# _format_time(time)
#
# Return a string representation represeting an approximation of TIME in
# seconds.
#
sub _format_time($)
{
	my ($time) = @_;

	# Seconds
	if ($time < 60) {
		return sprintf("%.3fs", $time);
	}
	# Minutes
	$time /= 60;
	if ($time < 60) {

		if ($time == int($time)) {
			return $time."m";
		} else {
			return ">".int($time)."m";
		}
	}
	# Hours
	$time /= 60;
	if ($time < 24) {

		if ($time == int($time)) {
			return $time."h";
		} else {
			return ">".int($time)."h";
		}
	}
	# Days
	$time /= 24;
	if ($time > 999) {
		return ">999d";
	} elsif ($time == int($time)) {
		return $time."d";
	} else {
		return ">".int($time)."d";
	}
}

#
# sids_list()
#
# List contents of current data set.
#
sub sids_list()
{
	my @inst_nums = db_sids_inst_get_nums();
	my $inst_num;
	my $layout = [
		[
			# min   max     weight  align 		delim
			[ 19,	22,	1,	$ALIGN_T_LEFT,	" " ],
			[ 38,	undef,	1,	$ALIGN_T_LEFT,	" " ],
			[ 6,	6,	1,	$ALIGN_T_LEFT,	" " ],
			[ 7,	8,	1,	$ALIGN_T_RIGHT,	" " ],
			[ 5,	6,	1,	$ALIGN_T_RIGHT,	"" ],
		]
	];

	if (!@inst_nums) {
		die("No system information found!\n");
	}

	lprintf($layout, "PROPERTY KEY", "INSTANCE/HOST/DATA ID", "RESULT",
		"TIME", "SIZE");
	print("\n".("="x(layout_get_width($layout)))."\n");

	# Print entry per instance
	foreach $inst_num (@inst_nums) {
		my $inst = db_sids_inst_get($inst_num);
		my ($inst_id, $hosts) = @$inst;
		my $host;
		my $host_num = 0;

		lprintf($layout, $inst_num, $inst_id);
		print("\n");
		# Print entry per host
		foreach $host (@$hosts) {
			my ($host_id, undef, $items) = @$host;
			my $item;
			my $item_num = 0;

			lprintf($layout, "$inst_num.host.$host_num",
				" $host_id");
			print("\n");
			# Print entry per item
			foreach $item (@$items) {
				my ($data_id, $start_time, $end_time,
				    $exit_code) = @$item;
				my $rc_str = ($exit_code == 0 ? "OK" :
								"FAILED");
				my $dur = _format_time($end_time - $start_time);
				my $size = _get_item_size($item);
				my $size_str = _format_size($size);
				my $key = "$inst_num.host.$host_num.item.".
					  "$item_num";

				lprintf($layout, $key, "  $data_id", $rc_str,
					$dur, $size_str);
				print("\n");

				$item_num++;
			}
			$host_num++;
		}
	}
}

#
# sids_set_sysvar(spec[, inst_id, host_id])
#
# Set sysvar according to SPEC.
#
sub sids_set_sysvar($;$$)
{
	my ($spec, $inst_id, $host_id) = @_;
	my $key;
	my $value;
	my $inst_num;
	my $host_num;
	my $host;

	if ($spec !~ /^([^=]+)=(.*)$/) {
		die("Cannot add data '$spec': unknown parameter format!\n");
	}
	($key, $value) = ($1, $2);
	($inst_num, $host_num) = _get_last_or_new($inst_id, $host_id);
	$host = db_sids_host_get($inst_num, $host_num);

	info("Setting system variable '$key' to '$value' for ".
	     "'$inst_num.host.$host_num'\n");
	$host->[$SIDS_HOST_T_SYSVAR_DB]->{$key} = $value;
	db_sids_set_modified(1);
}

#
# _get_last_host(inst_id, host_id)
#
# Return (inst_num, host_num) for specified INST_ID, HOST_ID or which was
# last added.
#
sub _get_last_host($$)
{
	my ($inst_id, $host_id) = @_;
	my $inst_num;
	my $host_num;

	# Get inst_num for instance with specified inst_id or the latest
	# added instance.
	if (defined($inst_id)) {
		$inst_num = db_sids_inst_id_to_num($inst_id);
	} else {
		my @inst_nums = db_sids_inst_get_nums();

		if (@inst_nums) {
			$inst_num = $#inst_nums;
		}
	}
	if (!defined($inst_num)) {
		return (undef, undef);
	}

	# Get host_num for instance with specified host_id or the latest
	# added host.
	if (defined($host_id)) {
		$host_num = db_sids_host_id_to_num($inst_num, $host_id);
	} else {
		my @host_nums = db_sids_host_get_nums($inst_num);

		if (@host_nums) {
			$host_num = $#host_nums;
		}
	}
	if (!defined($host_num)) {
		return ($inst_num, undef);
	}

	return ($inst_num, $host_num);
}

#
# sids_show_sysvar([inst_id, host_id])
#
# Show system variables.
#
sub sids_show_sysvar(;$$)
{
	my ($inst_id, $host_id) = @_;
	my ($inst_num, $host_num) = _get_last_host($inst_id, $host_id);
	my $inst;
	my $host;
	my $host_db;
	my $key;

	if (!defined($inst_num)) {
		if (defined($inst_id)) {
			die("No data found for instance '$inst_id'!\n");
		}
		die("No system information found!\n");
	}
	if (!defined($host_num)) {
		if (defined($host_id)) {
			if (defined($inst_id)) {
				die("No data found for host '$host_id' in ".
				    "instance '$inst_id!'\n");
			}
			die("No data found for host '$host_id' in most recent ".
			    "instance!\n");
		}
		if (defined($inst_id)) {
			die("No host data found in instance '$inst_id'!\n");
		}
		die("No host data available in most recent instance!\n");
	}
	$inst = db_sids_inst_get($inst_num);
	$host = db_sids_host_get($inst_num, $host_num);
	$host_db = $host->[$SIDS_HOST_T_SYSVAR_DB];

	info("System variables for host '".$host->[$SIDS_HOST_T_ID]."' of ".
	     "instance '".$inst->[$SIDS_INST_T_ID]."'\n");
	foreach $key (keys(%{$host_db})) {
		print("$key=".$host_db->{$key}."\n");
	}
}


#
# Code entry
#

# Indicate successful module initialization
1;
