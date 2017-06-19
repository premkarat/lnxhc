#
# LNXHC::Cons.pm
#   Linux Health Checker support functions for parsing result consumers
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

package LNXHC::Cons;

use strict;
use warnings;

use Exporter qw(import);
use File::Basename qw(basename);


#
# Local imports
#
use LNXHC::Config qw(config_cons_get_active_ids config_cons_get_param
		     config_cons_get_param_or_default config_cons_get_state
		     config_cons_get_state_or_default config_cons_set_defaults
		     config_cons_set_param config_cons_set_state);
use LNXHC::Consts qw($CONS_EVENT_T_ANY $CONS_EVENT_T_EX $CONS_FMT_T_ENV
		     $CONS_FMT_T_XML $CONS_FREQ_T_BOTH $CONS_FREQ_T_FOREACH
		     $CONS_FREQ_T_ONCE $CONS_TYPE_T_HANDLER $CONS_TYPE_T_REPORT
		     $CONS_T_AUTHORS $CONS_T_DESC $CONS_T_DIR $CONS_T_EVENT
		     $CONS_T_EXTRAFILES $CONS_T_FORMAT $CONS_T_FREQ $CONS_T_ID
		     $CONS_T_PARAM_DB $CONS_T_STATE $CONS_T_SYSTEM $CONS_T_TITLE
		     $CONS_T_TYPE $MATCH_ID $MATCH_ID_CHAR $MATCH_ID_WILDCARD
		     $PARAM_T_DESC $PARAM_T_VALUE $PROP_EXP_ALWAYS
		     $PROP_EXP_NEVER $SPEC_T_ID $SPEC_T_KEY $SPEC_T_WILDCARD
		     $STATE_T_INACTIVE $STATE_T_ACTIVE);
use LNXHC::DBCons qw(db_cons_exists db_cons_get db_cons_get_ids
		     db_cons_get_param_ids db_cons_get_type db_cons_install
		     db_cons_param_exists db_cons_uninstall);
use LNXHC::Misc qw($opt_debug $opt_system cons_type_to_str debug
		   filter_ids_by_wildcard get_indented get_spec_type info info2
		   match_wildcard print_padded state_to_str str_to_state);
use LNXHC::Prop qw(prop_parse_key);
use LNXHC::Util qw($ALIGN_T_LEFT format_as_text layout_get_width lprintf);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&cons_get_num_selected &cons_get_selected_ids &cons_info
		    &cons_install &cons_list &cons_select &cons_select_all
		    &cons_select_none &cons_selection_is_empty
		    &cons_set_defaults &cons_set_handler_state &cons_set_param
		    &cons_set_property &cons_set_report_state &cons_set_state
		    &cons_show &cons_show_property &cons_uninstall
		    &cons_switch_active_report);


#
# Constants
#

# Consumer property tags
# <cons_id>.id
my $_PROP_ID				= 0;
# <cons_id>.title
my $_PROP_TITLE				= 1;
# <cons_id>.desc
my $_PROP_DESC				= 2;
# <cons_id>.author.<author_num>
my $_PROP_AUTHOR			= 3;
# <cons_id>.default_state
my $_PROP_DEFAULT_STATE			= 4;
# <cons_id>.state
my $_PROP_STATE				= 5;
# <cons_id>.format
my $_PROP_FORMAT			= 6;
# <cons_id>.freq
my $_PROP_FREQ				= 7;
# <cons_id>.event
my $_PROP_EVENT				= 8;
# <cons_id>.type
my $_PROP_TYPE				= 9;
# <cons_id>.dir
my $_PROP_DIR				= 10;
# <cons_id>.extrafile.<extrafile_num>
my $_PROP_EXTRAFILE			= 11;
# <cons_id>.param.<param_id>.id
my $_PROP_PARAM_ID			= 12;
# <cons_id>.param.<param_id>.desc
my $_PROP_PARAM_DESC			= 13;
# <cons_id>.param.<param_id>.default_value
my $_PROP_PARAM_DEFAULT_VALUE		= 14;
# <cons_id>.param.<param_id>.value
my $_PROP_PARAM_VALUE			= 15;
# <cons_id>.system
my $_PROP_SYSTEM			= 16;

# Property ID type definition
my $_PROP_ID_T_TAG		= 0;
my $_PROP_ID_T_CONS_ID		= 1;
my $_PROP_ID_T_AUTHOR_NUM	= 2;
my $_PROP_ID_T_EXTRAFILE_NUM	= 2;
my $_PROP_ID_T_PARAM_ID		= 2;

# Mark parameter tags (used during sort)
my %_PARAM_TAGS = (
	$_PROP_PARAM_ID			=> 1,
	$_PROP_PARAM_DESC		=> 1,
	$_PROP_PARAM_DEFAULT_VALUE	=> 1,
	$_PROP_PARAM_VALUE		=> 1,
);

# Consumer property definition map: keydef => prop_tag
my %_PDEF_MAP = (
	"<cons_id>.id"
		=> $_PROP_ID,
	"<cons_id>.title"
		=> $_PROP_TITLE,
	"<cons_id>.desc"
		=> $_PROP_DESC,
	"<cons_id>.author.<author_num>"
		=> $_PROP_AUTHOR,
	"<cons_id>.format"
		=> $_PROP_FORMAT,
	"<cons_id>.freq"
		=> $_PROP_FREQ,
	"<cons_id>.event"
		=> $_PROP_EVENT,
	"<cons_id>.type"
		=> $_PROP_TYPE,
	"<cons_id>.dir"
		=> $_PROP_DIR,
	"<cons_id>.default_state"
		=> $_PROP_DEFAULT_STATE,
	"<cons_id>.state"
		=> $_PROP_STATE,
	"<cons_id>.extrafile.<extrafile_num>"
		=> $_PROP_EXTRAFILE,
	"<cons_id>.param.<param_id>.id"
		=> $_PROP_PARAM_ID,
	"<cons_id>.param.<param_id>.desc"
		=> $_PROP_PARAM_DESC,
	"<cons_id>.param.<param_id>.default_value"
		=> $_PROP_PARAM_DEFAULT_VALUE,
	"<cons_id>.param.<param_id>.value"
		=> $_PROP_PARAM_VALUE,
	"<cons_id>.system"
		=> $_PROP_SYSTEM,
);

# Forward declarations
sub _ns_cons_get_ids($$$);
sub _ns_cons_get_selected_ids($$$);
sub _ns_cons_id_is_valid($$$);
sub _ns_author_nums_get($$$);
sub _ns_author_num_is_valid($$$);
sub _ns_extrafile_nums_get($$$);
sub _ns_extrafile_num_is_valid($$$);
sub _ns_param_ids_get($$$);
sub _ns_param_id_is_valid($$$);

# Consumer property namespace map
# ns_id => [ type, regexp, fn_get_ids, fn_get_selected_ids, fn_id_is_valid ]

my %_PDEF_NS = (
	"<cons_id>" =>
		[ "consumer name", $MATCH_ID_WILDCARD,
		  \&_ns_cons_get_ids, \&_ns_cons_get_selected_ids,
		  \&_ns_cons_id_is_valid ],
	"<author_num>" =>
		[ "author number", '[\d\?\*]+',
		  \&_ns_author_nums_get, undef, \&_ns_author_num_is_valid ],
	"<extrafile_num>" =>
		[ "extrafile number", '[\d\?\*]+',
		  \&_ns_extrafile_nums_get, undef,
		  \&_ns_extrafile_num_is_valid ],
	"<param_id>" =>
		[ "parameter ID", $MATCH_ID_WILDCARD,
		  \&_ns_param_ids_get, undef, \&_ns_param_id_is_valid ],
);

#
# Global variables
#

# Hash containing IDs of consumers which were selected by user
my %_selected_cons_ids;

# Flag indicating if a selection is active
my $_selection_active;


#
# Sub-routines
#

#
# cons_get_selected_ids()
#
# Return list of selected consumer IDs.
#
sub cons_get_selected_ids()
{
	return keys(%_selected_cons_ids);
}

#
# cons_get_num_selected()
#
# Return number of selected consumers.
#
sub cons_get_num_selected()
{
	return scalar(keys(%_selected_cons_ids));
}

#
# _ns_cons_get_ids(subkeys, level, create)
#
# Return list of consumer IDs.
#
sub _ns_cons_get_ids($$$)
{
	my ($subkeys, $level, $create) = @_;

	return db_cons_get_ids();
}

#
# _ns_cons_get_selected_ids(subkeys, level, create)
#
# Return list of selected consumer IDs.
#
sub _ns_cons_get_selected_ids($$$)
{
	my ($subkeys, $level, $create) = @_;

	return cons_get_selected_ids();
}

#
# _ns_cons_id_is_valid(subkeys, level, create)
#
# Return non-zero if consumer ID specified by SUBKEY and LEVEL exists.
#
sub _ns_cons_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $cons_id = $subkeys->[$level];

	if ($create) {
		# Check if this ID can be created
		if ($cons_id =~ /^$MATCH_ID$/i) {
			return 1;
		}
		return 0;
	} else {
		db_cons_exists($cons_id);
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
	my $cons_id = $subkeys->[0];
	my $cons = db_cons_get($cons_id);
	my $authors;

	if (!defined($cons)) {
		return ();
	}
	$authors = $cons->[$CONS_T_AUTHORS];

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
	my $cons_id = $subkeys->[0];
	my $num = $subkeys->[$level];
	my $cons = db_cons_get($cons_id);
	my $authors;

	if (!defined($cons)) {
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

	$authors = $cons->[$CONS_T_AUTHORS];
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
	my $cons_id = $subkeys->[0];
	my $cons = db_cons_get($cons_id);
	my $extrafiles;

	if (!defined($cons)) {
		return ();
	}
	$extrafiles = $cons->[$CONS_T_EXTRAFILES];

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
	my $cons_id = $subkeys->[0];
	my $num = $subkeys->[$level];
	my $cons = db_cons_get($cons_id);
	my $extrafiles;

	if (!defined($cons)) {
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

	$extrafiles = $cons->[$CONS_T_EXTRAFILES];
	if (!defined($extrafiles) || $num >= scalar(@$extrafiles)) {
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
	my $cons_id = $subkeys->[0];

	return db_cons_get_param_ids($cons_id);
}

#
# _ns_param_id_is_valid(subkeys, level, create)
#
# Return non-zero if parameter ID specified by SUBKEY and LEVEL exists.
#
sub _ns_param_id_is_valid($$$)
{
	my ($subkeys, $level, $create) = @_;
	my $cons_id = $subkeys->[0];
	my $param_id = $subkeys->[2];

	if ($create) {
		# Check if this ID can be created
		if ($param_id =~ /^$MATCH_ID$/) {
			return 1;
		}
		return 0;
	}
	return db_cons_param_exists($cons_id, $param_id);
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
# _get_property_value(prop_id[, profile_id])
#
# Return value of property PROP_ID
#
sub _get_property_value($;$)
{
	my ($prop_id, $profile_id) = @_;
	my ($tag, $cons_id, $sub_id) = @$prop_id;
	my $cons = db_cons_get($cons_id);

	if (!defined($cons)) {
		return undef;
	}
	if ($tag == $_PROP_ID) {
		return $cons_id;
	} elsif ($tag == $_PROP_TITLE) {
		return $cons->[$CONS_T_TITLE];
	} elsif ($tag == $_PROP_DESC) {
		return $cons->[$CONS_T_DESC];
	} elsif ($tag == $_PROP_AUTHOR) {
		return $cons->[$CONS_T_AUTHORS]->[$sub_id];
	} elsif ($tag == $_PROP_FORMAT) {
		return $cons->[$CONS_T_FORMAT];
	} elsif ($tag == $_PROP_FREQ) {
		return $cons->[$CONS_T_FREQ];
	} elsif ($tag == $_PROP_EVENT) {
		return $cons->[$CONS_T_EVENT];
	} elsif ($tag == $_PROP_TYPE) {
		return $cons->[$CONS_T_TYPE];
	} elsif ($tag == $_PROP_DIR) {
		return $cons->[$CONS_T_DIR];
	} elsif ($tag == $_PROP_DEFAULT_STATE) {
		return $cons->[$CONS_T_STATE];
	} elsif ($tag == $_PROP_STATE) {
		return config_cons_get_state($cons_id, $profile_id);
	} elsif ($tag == $_PROP_EXTRAFILE) {
		return $cons->[$CONS_T_EXTRAFILES]->[$sub_id];
	} elsif ($tag == $_PROP_PARAM_ID) {
		return $sub_id;
	} elsif ($tag == $_PROP_PARAM_DESC) {
		return $cons->[$CONS_T_PARAM_DB]->{$sub_id}->[$PARAM_T_DESC];
	} elsif ($tag == $_PROP_PARAM_DEFAULT_VALUE) {
		return $cons->[$CONS_T_PARAM_DB]->{$sub_id}->[$PARAM_T_VALUE];
	} elsif ($tag == $_PROP_PARAM_VALUE) {
		return config_cons_get_param($cons_id, $sub_id, $profile_id);
	} elsif ($tag == $_PROP_SYSTEM) {
		return $cons->[$CONS_T_SYSTEM];
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
	my ($tag, $cons_id, $sub_id) = @$prop_id;

	if ($tag == $_PROP_ID) {
		return "$cons_id.id";
	} elsif ($tag == $_PROP_TITLE) {
		return "$cons_id.title";
	} elsif ($tag == $_PROP_DESC) {
		return "$cons_id.desc";
	} elsif ($tag == $_PROP_AUTHOR) {
		return "$cons_id.author.$sub_id";
	} elsif ($tag == $_PROP_FORMAT) {
		return "$cons_id.format";
	} elsif ($tag == $_PROP_FREQ) {
		return "$cons_id.freq";
	} elsif ($tag == $_PROP_EVENT) {
		return "$cons_id.event";
	} elsif ($tag == $_PROP_TYPE) {
		return "$cons_id.type";
	} elsif ($tag == $_PROP_DIR) {
		return "$cons_id.dir";
	} elsif ($tag == $_PROP_DEFAULT_STATE) {
		return "$cons_id.default_state";
	} elsif ($tag == $_PROP_STATE) {
		return "$cons_id.state";
	} elsif ($tag == $_PROP_EXTRAFILE) {
		return "$cons_id.extrafile.$sub_id";
	} elsif ($tag == $_PROP_PARAM_ID) {
		return "$cons_id.param.$sub_id.id";
	} elsif ($tag == $_PROP_PARAM_DESC) {
		return "$cons_id.param.$sub_id.desc";
	} elsif ($tag == $_PROP_PARAM_DEFAULT_VALUE) {
		return "$cons_id.param.$sub_id.default_value";
	} elsif ($tag == $_PROP_PARAM_VALUE) {
		return "$cons_id.param.$sub_id.value";
	} elsif ($tag == $_PROP_SYSTEM) {
		return "$cons_id.system";
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
	my ($tag, @subids) = @$prop_id;
	my $cons_id = $subids[0];

	if ($tag == $_PROP_STATE) {
		my $state = str_to_state($value);
		my $state_str = state_to_str($state);

		info("Setting consumer activation state of '$cons_id' to ".			     "'$state_str'\n");
		config_cons_set_state($cons_id, $state);
	} elsif ($tag == $_PROP_PARAM_VALUE) {
		my $param_id = $subids[1];

		info("Setting consumer parameter '$cons_id.$param_id' to ".
		     "'$value'\n");
		config_cons_set_param($cons_id, $param_id, $value);
	} else {
		die("Consumer property '"._get_property_key($prop_id).
		    "' cannot be modified!\n");
	}
}

#
# cons_select_all()
#
# Add all consumers to selection
#
sub cons_select_all()
{
	my @cons_ids = db_cons_get_ids();
	my $cons_id;

	foreach $cons_id (@cons_ids) {
		$_selected_cons_ids{$cons_id} = 1;
	}
	$_selection_active = 1;
}

#
# cons_select_none()
#
# Remove all consumers from selection.
#
sub cons_select_none()
{
	%_selected_cons_ids = ();
	$_selection_active = 1;
}

# cons_selection_is_empty()
#
# Return non-zero if no consumers are currently selected.
#
sub cons_selection_is_empty()
{
	return !(%_selected_cons_ids);
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
	} elsif ($tag == $_PROP_FORMAT) {
		$actual = _format_to_str($actual);
	} elsif ($tag == $_PROP_FREQ) {
		$actual = _freq_to_str($actual);
	} elsif ($tag == $_PROP_EVENT) {
		$actual = _event_to_str($actual);
	} elsif ($tag == $_PROP_TYPE) {
		$actual = cons_type_to_str($actual);
	} elsif ($tag == $_PROP_STATE || $tag == $_PROP_DEFAULT_STATE) {
		$actual = state_to_str($actual);
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
# _key_to_cons_ids(spec, profile_id)
#
# Return list of cons IDs for which boolean condition defined by SPEC
# evaluates as true.
#
sub _key_to_cons_ids($$)
{
	my ($spec, $profile_id) = @_;
	my $key;
	my $op;
	my $value;
	my $prop_id;
	my $err_prefix;
	my @cons_ids;
	my $cons_id;

	if (!($spec =~ /^([$MATCH_ID_CHAR\.\*\?]+)(=|!=)(.*)$/i)) {
		die("Consumer specification '$spec': unrecognized format!\n");
	}
	($key, $op, $value) = ($1, $2, $3);

	# Convert keys into list of property IDs
	$err_prefix = "Consumer specification '$key': ";
	foreach $prop_id (_get_property_ids("*.$key", $PROP_EXP_NEVER, 1, 0,
					    $err_prefix)) {
		if (!_match_property_value($prop_id, $op, $value,
					   $profile_id)) {
			next;
		}
		$cons_id = $prop_id->[$_PROP_ID_T_CONS_ID];
		push(@cons_ids, $cons_id);

		info2("Consumer '$cons_id' matches '$key$op$value'\n");
	}

	info2("Keyword $key$op$value matched ".scalar(@cons_ids).
	      " consumers\n");

	return @cons_ids;
}

#
# cons_select(spec, intersect, nonex[, profile_id])
#
# Perform selection operation on consumers which match SPEC. If INTERSECT is
# non-zero, reduce selection to those consumers that match SPEC and are already
# selected. If NONEX is non-zero, allow selecting consumers which do not exist.
#
sub cons_select($$$;$)
{
	my ($spec, $intersect, $nonex, $profile_id) = @_;
	my $lspec = lc($spec);
	my @cons_ids;
	my $cons_id;
	my $type;

	$type = get_spec_type($lspec);

	if ($type == $SPEC_T_ID) {
		# This specification is a consumer ID
		if (!db_cons_exists($lspec) && !$nonex) {
			warn("Consumer '$spec' does not exist - skipping\n");
			return;
		}
		@cons_ids = ($lspec);
	} elsif ($type == $SPEC_T_WILDCARD) {
		# This specification contains shell wildcards (? and *)
		@cons_ids = filter_ids_by_wildcard($spec, "cons",
						    db_cons_get_ids());
	} elsif ($type == $SPEC_T_KEY) {
		# This specification consists of a key, operator, value
		# statement
		@cons_ids = _key_to_cons_ids($spec, $profile_id);
	} else {
		die("Unrecognized consumer specification: '$spec'\n");
	}

	if ($intersect) {
		my %new_sel;

		# Create new selection containing intersection of both sets
		foreach $cons_id (@cons_ids) {
			if ($_selected_cons_ids{$cons_id}) {
				$new_sel{$cons_id} = 1;
			}
		}

		# Replace existing selection with intersection
		%_selected_cons_ids = %new_sel;
	} else {
		# Apply list to selection
		foreach $cons_id (@cons_ids) {
			$_selected_cons_ids{$cons_id} = 1;
		}
	}

	$_selection_active = 1;
}

# _print_cons_heading(cons, show_state)
#
# Print consumer heading.
#
sub _print_cons_heading($$)
{
	my ($cons, $show_state) = @_;
	my $cons_id = $cons->[$CONS_T_ID];
	my $heading;

	if ($show_state) {
		my $type = $cons->[$CONS_T_TYPE];
		my $state = config_cons_get_state_or_default($cons_id);

		$state = state_to_str($state);
		$type = cons_type_to_str($type);
		$heading = "Consumer $cons_id ($state $type)";
	} else {
		$heading = "Consumer $cons_id";
	}

	print("$heading\n");
	print(("="x(length($heading)))."\n");
}

#
# _print_cons_title(cons)
#
# Print consumer title.
#
sub _print_cons_title($)
{
	my ($cons) = @_;
	my $title = $cons->[$CONS_T_TITLE];

	print("Title:\n");
	print(get_indented($title, 2));
}

#
# _print_cons_desc(cons)
#
# Print consumer description.
#
sub _print_cons_desc($)
{
	my ($cons) = @_;
	my $desc = $cons->[$CONS_T_DESC];

	print("Description:\n");
	print(format_as_text($desc, 2));
}

#
# _format_to_str(format)
#
# Return string representation of the specified consumer input FORMAT.
#
sub _format_to_str($)
{
	my ($format) = @_;

	if ($format == $CONS_FMT_T_XML) {
		return "xml";
	} elsif ($format == $CONS_FMT_T_ENV) {
		return "env";
	} else {
		return "<unknown>";
	}
}

#
# _freq_to_str(freq)
#
# Return string representation of the specified consumer call FREQ.
#
sub _freq_to_str($)
{
	my ($freq) = @_;

	if ($freq == $CONS_FREQ_T_FOREACH) {
		return "foreach";
	} elsif ($freq == $CONS_FREQ_T_ONCE) {
		return "once";
	} elsif ($freq == $CONS_FREQ_T_BOTH) {
		return "both";
	} else {
		return "<unknown>";
	}
}

#
# _event_to_str(event)
#
# Return string representation of the specified consumer call EVENT.
#
sub _event_to_str($)
{
	my ($event) = @_;

	if ($event == $CONS_EVENT_T_EX) {
		return "exception";
	} elsif ($event == $CONS_EVENT_T_ANY) {
		return "any";
	} else {
		return "<unknown>";
	}
}

#
# _print_cons_data(cons)
#
# Print generic consumer data.
#
sub _print_cons_data($)
{
	my ($cons) = @_;
	my $cons_id = $cons->[$CONS_T_ID];
	my $state = state_to_str(config_cons_get_state_or_default($cons_id));
	my $state_def = state_to_str($cons->[$CONS_T_STATE]);
	my $format = _format_to_str($cons->[$CONS_T_FORMAT]);
	my $freq = _freq_to_str($cons->[$CONS_T_FREQ]);
	my $event = _event_to_str($cons->[$CONS_T_EVENT]);
	my $type = cons_type_to_str($cons->[$CONS_T_TYPE]);
	my $dir = $cons->[$CONS_T_DIR];
	my $system = $cons->[$CONS_T_SYSTEM];
	my @extrafiles = @{$cons->[$CONS_T_EXTRAFILES]};
	my $extrafile;

	print("Consumer data:\n");
	print_padded(2, 24, "State [$state_def]", $state);
	print_padded(2, 24, "Consumer type", $type);
	print_padded(2, 24, "Call frequency", $freq);
	print_padded(2, 24, "Call trigger", $event);
	print_padded(2, 24, "Input format", $format);
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
# _print_cons_authors(cons)
#
# Print consumer authors.
#
sub _print_cons_authors($)
{
	my ($cons) = @_;
	my $author;

	print("Authors:\n");
	foreach $author (@{$cons->[$CONS_T_AUTHORS]}) {
		print("  $author\n");
	}
}

#
# _print_cons_params(cons)
#
# Print consumer parameter.
#
sub _print_cons_params($)
{
	my ($cons) = @_;
	my $cons_id = $cons->[$CONS_T_ID];
	my $param_db = $cons->[$CONS_T_PARAM_DB];
	my @param_ids = keys(%{$param_db});
	my $param_id;
	my $nl;

	# Check if this consumer provides parameters
	if (!@param_ids) {
		return;
	}
	print("Parameters:\n");
	foreach $param_id (sort(@param_ids)) {
		my $param = $param_db->{$param_id};
		my $param_desc = $param->[$PARAM_T_DESC];
		my $value = config_cons_get_param_or_default($cons_id,
							     $param_id);
		my $default = $param->[$PARAM_T_VALUE];
		my $default_text .= "\nDefault value is \"$default\".\n";

		print($nl) if (defined($nl));
		$nl = "\n";
		print("  $param_id=$value\n");
		print(format_as_text($param_desc, 8));
		print(get_indented($default_text, 8));
	}
}

#
# _print_info(cons)
#
# Print basic consumer information for consumer CONS.
#
sub _print_info($)
{
	my ($cons) = @_;

	_print_cons_heading($cons, 1);
	_print_cons_title($cons);
	print("\n");
	_print_cons_desc($cons);
	if (%{$cons->[$CONS_T_PARAM_DB]}) {
		print("\n");
		_print_cons_params($cons);
	}
}

#
# cons_info()
#
# Print basic consumer information for selected consumers.
#
sub cons_info()
{
	my @cons_ids = cons_get_selected_ids();
	my $cons_id;
	my $nl = "";

	if (!@cons_ids) {
		die("No consumer was selected!\n");
	}
	foreach $cons_id (sort(@cons_ids)) {
		my $cons = db_cons_get($cons_id);

		if (!defined($cons)) {
			# Shouldn't happen
			die("No such consumer: $cons_id\n");
		}
		print($nl);
		$nl = "\n";
		_print_info($cons);
	}
}

#
# _print_details(cons)
#
# Print detailed consumer information for consumer CONS.
#
sub _print_details($)
{
	my ($cons) = @_;

	_print_cons_heading($cons, 0);
	_print_cons_title($cons);
	print("\n");
	_print_cons_authors($cons);
	print("\n");
	_print_cons_desc($cons);
	print("\n");
	_print_cons_data($cons);
	if (%{$cons->[$CONS_T_PARAM_DB]}) {
		print("\n");
		_print_cons_params($cons);
	}
}

#
# cons_show()
#
# Print detailed consumer information for selected consumers.
#
sub cons_show()
{
	my @cons_ids = cons_get_selected_ids();
	my $cons_id;
	my $nl = "";

	foreach $cons_id (sort(@cons_ids)) {
		my $cons = db_cons_get($cons_id);

		if (!defined($cons)) {
			# Shouldn't happen
			die("No such consumer: $cons_id\n");
		}
		print($nl);
		$nl = "\n";
		_print_details($cons);
	}
}

#
# _prop_cmp(a, b)
#
# Compare two consumer property IDs.
#
sub _prop_cmp($$)
{
	my ($a, $b) = @_;
	my ($tag_a, $cons_id_a, $sub_id_a) = @$a;
	my ($tag_b, $cons_id_b, $sub_id_b) = @$b;

	if ($cons_id_a ne $cons_id_b) {
		# Sort by consumer ID
		return $cons_id_a cmp $cons_id_b;
	} elsif ($tag_a == $_PROP_AUTHOR && $tag_b == $_PROP_AUTHOR) {
		# Sort authors by author number
		return $sub_id_a <=> $sub_id_b;
	} elsif ($tag_a == $_PROP_EXTRAFILE && $tag_b == $_PROP_EXTRAFILE) {
		# Sort extrafiles by extrafile number
		return $sub_id_a <=> $sub_id_b;
	} elsif ($_PARAM_TAGS{$tag_a} && $_PARAM_TAGS{$tag_b} &&
		 ($sub_id_a ne $sub_id_b)) {
		# Sort parameter properties by parameter ID
		return $sub_id_a cmp $sub_id_b;
	} else {
		return $tag_a <=> $tag_b;
	}
}

#
# cons_show_property(keys)
#
# Print consumer properties specified by KEYS.
#
sub cons_show_property($)
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
# cons_set_property(key, value)
#
# Set value of consumer properties identified by KEY to VALUE.
#
sub cons_set_property($$)
{
	my ($key, $value) = @_;
	my @prop_ids;
	my $prop_id;

	# Convert key into list of property IDs
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
# cons_list()
#
# List contents of consumer database.
#
sub cons_list()
{
	my @cons_ids;
	my $cons_id;
	my $layout = [
		[
			# min   max     weight  align 		delim
			[ 40,	40,	0,	$ALIGN_T_LEFT,	" " ],
			[ 30,	30,	1,	$ALIGN_T_LEFT,	" " ],
			[ 8,	8,	0,	$ALIGN_T_LEFT,	"" ],
		]
	];

	if ($_selection_active) {
		@cons_ids = cons_get_selected_ids();
	} else {
		@cons_ids = db_cons_get_ids();
	}

	return if (!@cons_ids);

	# Print heading
	lprintf($layout, "CONSUMER NAME", "TYPE", "STATE");
	print("\n".("="x(layout_get_width($layout)))."\n");

	# Print entry per installed consumer
	foreach $cons_id (sort(@cons_ids)) {
		my $cons = db_cons_get($cons_id);
		my $type = cons_type_to_str($cons->[$CONS_T_TYPE]);
		my $state;

		# Get activation state
		$state = config_cons_get_state_or_default($cons_id);
		$state = state_to_str($state);

		# Print entry
		lprintf($layout, $cons_id, $type, $state);
		print("\n");
	}
}

#
# cons_set_param(spec[, use_active])
#
# Set consumer parameters according to SPEC. SPEC can take either of the
# following formats:
#   <cons_id>.<param_id>=<value>  -> change parameter of specified consumer
#   <param_id>=<value>            -> change parameters of selected consumers
#
# If USE_ACTIVE is non-zero, parameters for the active consumers are modified
# instead of selected consumers.
#
sub cons_set_param($;$)
{
	my ($spec, $use_active) = @_;
	my @cons_ids;
	my $cons_id;
	my $param_id;
	my $value;
	my $msg;

	if ($spec =~ /^($MATCH_ID)\.($MATCH_ID)=(.*)$/i) {
		($cons_id, $param_id, $value) = (lc($1), lc($2), $3);

		if (!db_cons_exists($cons_id)) {
			$msg = "consumer '$cons_id' does not exist!\n";
			goto err;
		}
		if (!db_cons_param_exists($cons_id, $param_id)) {
			$msg = "parameter does not exist!\n";
			goto err;
		}
		push(@cons_ids, $cons_id);
	} elsif ($spec =~ /^($MATCH_ID)=(.*)$/i) {
		($param_id, $value) = (lc($1), $2);
		my @selected_ids;

		if ($use_active) {
			@selected_ids = config_cons_get_active_ids();
			if (!@selected_ids) {
				# Don't count this as an error
				return;
			}
		} else {
			@selected_ids = cons_get_selected_ids();
			if (!@selected_ids) {
				$msg = "no consumer was selected!\n";
				goto err;
			}
		}
		foreach $cons_id (@selected_ids) {
			if (db_cons_param_exists($cons_id, $param_id)) {
				push(@cons_ids, $cons_id);
			} else {
				warn("Consumer '$cons_id' does not define ".
				     "parameter '$param_id' - skipping\n");
			}
		}
		if (!@cons_ids) {
			my $source = $use_active ? "active" : "selected";

			warn("None of the $source consumers defines parameter ".
			     "'$param_id' - skipping\n");
			return;
		}
	} else {
		my $source = $use_active ? "active" : "selected";

		$msg = <<EOF;
unrecognized parameter format!
Use 'CONS.PARAM=VALUE' to set a parameter for a specific consumer.
Use 'PARAM=VALUE' to set a parameter for all $source consumers.
EOF
		goto err;
	}

	foreach $cons_id (@cons_ids) {
		config_cons_set_param($cons_id, $param_id, $value);
		info("Setting value of parameter $cons_id.$param_id to ".
		     "'$value'\n");
	}
	return;

err:
	die("Cannot set consumer parameter '$spec': $msg");
}

#
# cons_set_state(spec)
#
# Set consumer activation state according to SPEC. SPEC can take either of the
# following formats:
#   <cons_id>=<state>  -> change state of specified consumer
#   <state>            -> change state of selected consumers
#
sub cons_set_state($)
{
	my ($spec) = @_;
	my @cons_ids;
	my $cons_id;
	my $state;
	my $str;
	my $msg;

	if ($spec =~ /^($MATCH_ID)=(.*)$/i) {
		($cons_id, $state) = (lc($1), $2);

		if (!db_cons_exists($cons_id)) {
			$msg = "consumer '$cons_id' does not exist!\n";
			goto err;
		}
		push(@cons_ids, $cons_id);
	} elsif ($spec !~ /=/) {
		@cons_ids = cons_get_selected_ids();

		if (!@cons_ids) {
			$msg = "no consumer was selected!\n";
			goto err;
		}
		$state = $spec;
	} else {
		$msg = <<EOF;
unrecognized state specification!
Try '$main::tool_inv consumer --state CONS_ID=STATE' or
    '$main::tool_inv consumer --state STATE SELECT'
EOF
		goto err;
	}

	$state = str_to_state($state, "Cannot set consumer state '$spec'");
	$str = state_to_str($state);
	foreach $cons_id (@cons_ids) {
		info("Setting state of consumer '$cons_id' to '$str'\n");
		config_cons_set_state($cons_id, $state);
	}

	return;
err:
	die("Cannot set consumer state '$spec': $msg");
}

#
# cons_set_report_state(state)
#
# Set consumer activation state for all report consumers to STATE.
#
sub cons_set_report_state($)
{
	my ($state) = @_;
	my @cons_ids = db_cons_get_ids();
	my $cons_id;

	foreach $cons_id (@cons_ids) {
		if (db_cons_get_type($cons_id) != $CONS_TYPE_T_REPORT) {
			next;
		}
		config_cons_set_state($cons_id, $state);
	}
}

#
# cons_switch_active_report(cons_id)
#
# Make cons_id the only active report consumer.
#
sub cons_switch_active_report($)
{
	my ($cons_id) = @_;

	if (!db_cons_exists($cons_id)) {
		die("Consumer '$cons_id' does not exist!\n");
	}
	if (db_cons_get_type($cons_id) != $CONS_TYPE_T_REPORT) {
		die("Consumer '$cons_id' is not a report consumer!\n");
	}
	info("Setting '$cons_id' as active report consumer\n");
	cons_set_report_state($STATE_T_INACTIVE);
	config_cons_set_state($cons_id, $STATE_T_ACTIVE);
}

#
# cons_set_handler_state(state)
#
# Set consumer activation state for all handler consumers to STATE.
#
sub cons_set_handler_state($)
{
	my ($state) = @_;
	my @cons_ids = db_cons_get_ids();
	my $cons_id;

	foreach $cons_id (@cons_ids) {
		if (db_cons_get_type($cons_id) != $CONS_TYPE_T_HANDLER) {
			next;
		}
		config_cons_set_state($cons_id, $state);
	}
}

#
# cons_set_defaults()
#
# Set configuration for selected consumers to default values.
#
sub cons_set_defaults()
{
	my @cons_ids = cons_get_selected_ids();
	my $cons_id;

	# Set defaults for all selected consumers
	foreach $cons_id (@cons_ids) {
		info("Setting default configuration values for consumer ".
		     "'$cons_id'\n");
		config_cons_set_defaults($cons_id);
	}
}

#
# cons_install(dir)
#
# Install consumer from DIR.
#
sub cons_install($)
{
	my ($dir) = @_;
	my $cons_id = basename($dir);

	# Add to database
	db_cons_install($dir);

	if ($opt_system) {
		info("Installed consumer '$cons_id' in system-wide ".
		     "database\n");
	} else {
		info("Installed consumer '$cons_id' in user database\n");
	}
}

#
# cons_uninstall()
#
# Remove selected consumers.
#
sub cons_uninstall()
{
	my @cons_ids = cons_get_selected_ids();
	my $cons_id;

	if (!@cons_ids) {
		die("No consumer was selected!\n");
	}
	foreach $cons_id (@cons_ids) {
		# Remove from database
		db_cons_uninstall($cons_id);

		if ($opt_system) {
			info("Removed consumer '$cons_id' from system-wide ".
			     "database\n");
		} else {
			info("Removed consumer '$cons_id' from user ".
			     "database\n");
		}
	}
}


#
# Code entry
#

# Indicate successful module initialization
1;
