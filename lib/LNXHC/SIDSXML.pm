#
# LNXHC::SIDSXML.pm
#   Linux Health Checker system information data set XML routines
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

package LNXHC::SIDSXML;

use strict;
use warnings;

use Exporter qw(import);
use XML::Parser;


#
# Local imports
#
use LNXHC::Consts qw($SIDS_HOST_T_ID $SIDS_HOST_T_ITEMS $SIDS_HOST_T_SYSVAR_DB
		     $SIDS_INST_T_HOSTS $SIDS_INST_T_ID $SIDS_ITEM_T_DATA
		     $SIDS_ITEM_T_DATA_ID $SIDS_ITEM_T_END_TIME
		     $SIDS_ITEM_T_ERR_DATA $SIDS_ITEM_T_EXIT_CODE
		     $SIDS_ITEM_T_START_TIME $SIDS_T_INSTS);
use LNXHC::DBSIDS qw(db_sids_get db_sids_inst_get db_sids_inst_get_nums
		     db_sids_set db_sids_set_modified);
use LNXHC::Misc qw(info1 xml_decode_data xml_decode_predeclared xml_encode_data
		   xml_encode_predeclared);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&sids_xml_read &sids_xml_write);


#
# Constants
#

# XML contexts used for parsing SIDS data (one context per XML tag)
my $_CONTEXT_NONE		= 0;
my $_CONTEXT_SYSINFO		= 1;
my $_CONTEXT_INST		= 2;
my $_CONTEXT_HOST		= 4;
my $_CONTEXT_SYSVAR		= 6;
my $_CONTEXT_ITEM		= 7;
my $_CONTEXT_EXIT_CODE		= 9;
my $_CONTEXT_START_TIME		= 10;
my $_CONTEXT_END_TIME		= 11;
my $_CONTEXT_DATA		= 12;
my $_CONTEXT_ERR_DATA		= 13;

# Mapping element ID -> context
my %_TAG_TO_CONTEXT = (
	"sysinfo"		=> $_CONTEXT_SYSINFO,
	"instance"		=> $_CONTEXT_INST,
	"host"			=> $_CONTEXT_HOST,
	"sysvar"		=> $_CONTEXT_SYSVAR,
	"item"			=> $_CONTEXT_ITEM,
	"exit_code"		=> $_CONTEXT_EXIT_CODE,
	"start_time"		=> $_CONTEXT_START_TIME,
	"end_time"		=> $_CONTEXT_END_TIME,
	"data"			=> $_CONTEXT_DATA,
	"err_data"		=> $_CONTEXT_ERR_DATA,
);

# Acceptable parent contexts for SIDS parsing
my %_CONTEXT_PARENT = (
	$_CONTEXT_SYSINFO	=> $_CONTEXT_NONE,
	$_CONTEXT_INST		=> $_CONTEXT_SYSINFO,
	$_CONTEXT_HOST		=> $_CONTEXT_INST,
	$_CONTEXT_SYSVAR	=> $_CONTEXT_HOST,
	$_CONTEXT_ITEM		=> $_CONTEXT_HOST,
	$_CONTEXT_EXIT_CODE	=> $_CONTEXT_ITEM,
	$_CONTEXT_START_TIME	=> $_CONTEXT_ITEM,
	$_CONTEXT_END_TIME	=> $_CONTEXT_ITEM,
	$_CONTEXT_DATA		=> $_CONTEXT_ITEM,
	$_CONTEXT_ERR_DATA	=> $_CONTEXT_ITEM,
);

# Field declaration for sids_state
# List of contexts up to current element
my $_SIDS_STATE_CONTEXT_LIST		= 0;
# Context-related data: character data, attributes and list of references to
# to sids structures related to current context
my $_SIDS_STATE_CONTEXT_DATA		= 1;
# Reference to current sids result
my $_SIDS_STATE_CONTEXT_SIDS		= 2;
# Filename of parsed file
my $_SIDS_STATE_CONTEXT_FILENAME	= 3;

# Field declaration for context data
my $_CONTEXT_DATA_CHAR			= 0;
my $_CONTEXT_DATA_ATTRS			= 1;
my $_CONTEXT_DATA_INST			= 2;
my $_CONTEXT_DATA_HOST			= 3;
my $_CONTEXT_DATA_ITEM			= 4;


#
# Global variables
#


#
# Sub-routines
#

#
# _write_xml_encoded_data(handle, indent, element, data)
#
# Write an XML representation of data element ELEMENT with data DATA. If
# data contains a non-printable character or an XML delimiter, encode it in
# MIME base64.
#
sub _write_xml_encoded_data($$$$)
{
	my ($handle, $indent, $element, $data) = @_;
	my $encoding;

	$indent = " "x$indent;
	($encoding, $data) = xml_encode_data($data);
	print($handle <<EOF);
$indent<$element encoding="$encoding">$data</$element>
EOF
}

#
# _write_xml_item(handle, item)
#
# Write and XML representation of sids item ITEM to HANDLE.
#
sub _write_xml_item($$)
{
	my ($handle, $item) = @_;
	my ($data_id, $start_time, $end_time, $exit_code, $data, $err_data) =
	    @$item;

	$data_id	= xml_encode_predeclared($data_id);
	$exit_code	= xml_encode_predeclared($exit_code);
	$start_time	= xml_encode_predeclared($start_time);
	$end_time	= xml_encode_predeclared($end_time);

	# SIDS item XML prolog
	print($handle <<EOF);

      <item id="$data_id">
        <exit_code>$exit_code</exit_code>
        <start_time>$start_time</start_time>
        <end_time>$end_time</end_time>
EOF

	if (defined($data)) {
		_write_xml_encoded_data($handle, 8, "data", $data);
	}

	if (defined($err_data)) {
		_write_xml_encoded_data($handle, 8, "err_data", $err_data);
	}

	# SIDS item XML epilog
	print($handle <<EOF);
      </item>
EOF
}

#
# _write_xml_host(handle, host)
#
# Write an XML representation of sids host HOST to HANDLE.
#
sub _write_xml_host($$)
{
	my ($handle, $host) = @_;
	my ($host_id, $sysvar_db, $items) = @$host;
	my $sysvar_id;
	my $item;

	$host_id = xml_encode_predeclared($host_id);

	# SIDS host XML prolog
	print($handle <<EOF);

    <host id="$host_id">
EOF

	# Per sysvar
	foreach $sysvar_id (sort(keys(%{$sysvar_db}))) {
		my $value = $sysvar_db->{$sysvar_id};

		# Escape XML special characters
		$value = xml_encode_predeclared($value);

		print($handle <<EOF);
      <sysvar key="$sysvar_id">$value</sysvar>
EOF
	}

	# Per item
	foreach $item (@$items) {
		_write_xml_item($handle, $item);
	}

	# SIDS host XML epilog
	print($handle <<EOF);
    </host>
EOF
}

#
# _write_xml_inst(handle, inst)
#
# Write an XML representation of sids instance INST to HANDLE.
#
sub _write_xml_inst($$)
{
	my ($handle, $inst) = @_;
	my ($inst_id, $hosts) = @$inst;
	my $host;

	$inst_id = xml_encode_predeclared($inst_id);

	# SIDS instance XML prolog
	print($handle <<EOF);
  <instance id="$inst_id">
EOF

	# Per sids ost data
	foreach $host (@$hosts) {
		_write_xml_host($handle, $host);
	}

	# SIDS instance XML epilog
	print($handle <<EOF);
  </instance>
EOF
}

#
# sids_xml_write(handle)
#
# Write an XML representation of the current sids database to HANDLE.
#
sub sids_xml_write($)
{
	my ($handle) = @_;
	my @inst_nums = db_sids_inst_get_nums();
	my $inst_num;

	info1("Writing XML file for ".scalar(@inst_nums)." sysinfo ".
	      "instances\n");

	# XML prolog
	print($handle <<EOF);
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE sysinfo SYSTEM "$main::lib_dir/sysinfo.dtd">

<sysinfo version="1">
EOF

	# Per instance data
	foreach $inst_num (@inst_nums) {
		my $inst = db_sids_inst_get($inst_num);

		_write_xml_inst($handle, $inst);
	}

	# XML epilog
	print($handle <<EOF);
</sysinfo>
EOF
}

#
# _xml_sids_handle_start(state, expat, elem, attrs)
#
# Handle start tags for a sids xml file.
#
sub _xml_sids_handle_start($@)
{
	my ($sids_state, $expat, $elem, %attrs) = @_;
	my ($context_list, $context_data, $sids, $filename) = @$sids_state;
	my $elem_context;
	my $current_context;
	my $required_context;
	my $sids_inst;
	my $sids_host;
	my $sids_item;
	my $err;

	# Check for correct context
	$elem_context = $_TAG_TO_CONTEXT{$elem};
	if (!defined($elem_context)) {
		$err = "unknown xml tag '$elem'";
		goto err;
	}
	if (@$context_list) {
		$current_context = $context_list->[scalar(@$context_list) - 1];
	}
	$required_context = $_CONTEXT_PARENT{$elem_context};
	if (defined($current_context)) {
		if ($required_context != $current_context) {
			$err = "incorrect context for xml tag '$elem'";
			goto err;
		}
	} elsif ($required_context != $_CONTEXT_NONE) {
		$err = "incorrect context for xml tag '$elem'";
		goto err;
	}

	# Check for correct attributes
	if ($elem_context == $_CONTEXT_SYSINFO) {
		my $version = $attrs{"version"};

		if (!defined($version)) {
			$err = "missing attribute 'version'";
			goto err;
		} elsif ($version != 1) {
			$err = "unknown version '$version'";
			goto err;
		}
		if (scalar(keys(%attrs)) != 1) {
			$err = "incorrect attributes";
		}
	} elsif ($elem_context == $_CONTEXT_INST ||
		 $elem_context == $_CONTEXT_HOST ||
		 $elem_context == $_CONTEXT_ITEM) {
		my $id = $attrs{"id"};

		if (!defined($id)) {
			$err = "missing attribute 'id'";
			goto err;
		}
		if (scalar(keys(%attrs)) != 1) {
			$err = "incorrect attributes";
			goto err;
		}
	} elsif ($elem_context == $_CONTEXT_SYSVAR) {
		my $key = $attrs{"key"};

		if (!defined($key)) {
			$err = "missing attribute 'key'";
			goto err;
		}
		if (scalar(keys(%attrs)) != 1) {
			$err = "incorrect attributes";
			goto err;
		}
	} elsif ($elem_context == $_CONTEXT_DATA ||
		 $elem_context == $_CONTEXT_ERR_DATA) {
		my $encoding = $attrs{"encoding"};

		if (!defined($encoding)) {
			$encoding = "none";
			$attrs{"encoding"} = $encoding;
		}
		if ($encoding ne "none" && $encoding ne "base64") {
			$err = "unknown encoding '$encoding'";
			goto err;
		}
		if (scalar(keys(%attrs)) != 1) {
			$err = "incorrect attributes";
			goto err;
		}
	} else {
		if (%attrs) {
			$err = "unexpected attributes";
			goto err;
		}
	}

	# Update context data
	if (defined($context_data)) {
		$sids_inst = $context_data->[$_CONTEXT_DATA_INST];
		$sids_host = $context_data->[$_CONTEXT_DATA_HOST];
		$sids_item = $context_data->[$_CONTEXT_DATA_ITEM];
	}
	if ($elem_context == $_CONTEXT_INST) {
		# Initialize empty sids_inst_t
		$sids_inst = [ $attrs{"id"}, [] ];
	} elsif ($elem_context == $_CONTEXT_HOST) {
		# Initialize empty sids_host_t
		$sids_host = [ $attrs{"id"}, {}, [] ];
	} elsif ($elem_context == $_CONTEXT_ITEM) {
		# Initialize empty sids_item_t
		$sids_item = [ $attrs{"id"} ];
	}
	$sids_state->[$_SIDS_STATE_CONTEXT_DATA] = [ "", \%attrs, $sids_inst,
						    $sids_host, $sids_item ];

	# Update context
	push(@$context_list, $elem_context);
	return;

err:
	if (defined($filename)) {
		die("File format error: $filename:".$expat->current_line().
		    ": $err\n");
	} else {
		die("File format error: line ".$expat->current_line().
		    ": $err\n");
	}
}

#
# _xml_sids_handle_end(state, @)
#
# Handle end tags for a sids xml file.
#
sub _xml_sids_handle_end($@)
{
	my ($sids_state, $expat, $elem) = @_;
	my ($context_list, $context_data, $sids, $filename) = @$sids_state;
	my $context = $context_list->[scalar(@$context_list) - 1];
	my $content = $context_data->[$_CONTEXT_DATA_CHAR];
	my $sids_inst = $context_data->[$_CONTEXT_DATA_INST];
	my $sids_host = $context_data->[$_CONTEXT_DATA_HOST];
	my $sids_item = $context_data->[$_CONTEXT_DATA_ITEM];
	my $attrs = $context_data->[$_CONTEXT_DATA_ATTRS];
	my $err;

	if ($context == $_CONTEXT_INST) {
		my $inst_id = $sids_inst->[$SIDS_INST_T_ID];
		my $inst;

		# Prevent re-definition
		foreach $inst (@{$sids->[$SIDS_T_INSTS]}) {
			if ($inst->[$SIDS_INST_T_ID] eq $inst_id) {
				$err = "instance '$inst_id' re-defined";
				goto err;
			}
		}

		# Add this sids_inst_t to sids_t
		push(@{$sids->[$SIDS_T_INSTS]}, $sids_inst);

		# Remove reference to this instance since it was closed
		$context_data->[$_CONTEXT_DATA_INST] = undef;
	} elsif ($context == $_CONTEXT_HOST) {
		my $host_id = $sids_host->[$SIDS_HOST_T_ID];
		my $host;

		# Prevent re-definition
		foreach $host (@{$sids_inst->[$SIDS_INST_T_HOSTS]}) {
			if ($host->[$SIDS_HOST_T_ID] eq $host_id) {
				$err = "host '$host_id' re-defined";
				goto err;
			}
		}

		# Add this sids_host_t to sids_t
		push(@{$sids_inst->[$SIDS_INST_T_HOSTS]}, $sids_host);

		# Remove reference to this host since it was closed
		$context_data->[$_CONTEXT_DATA_HOST] = undef;
	} elsif ($context == $_CONTEXT_SYSVAR) {
		my $key = $attrs->{"key"};

		# Prevent re-definition
		if (defined($sids_host->[$SIDS_HOST_T_SYSVAR_DB]->{$key})) {
			$err = "sysvar '$key' re-defined";
			goto err;
		}
		$sids_host->[$SIDS_HOST_T_SYSVAR_DB]->{$key} = $content;
	} elsif ($context == $_CONTEXT_ITEM) {
		my ($data_id, $start_time, $end_time, $exit_code, $data,
		    $err_data) = @$sids_item;
		my $item;

		# Check for completeness
		if (!defined($data_id) || !defined($exit_code) ||
		    !defined($start_time) || !defined($end_time) ||
		    !(defined($data) || defined($err_data))) {
			$err = "incomplete item data set\n";
			goto err;
		}
		# Prevent re-definition
		foreach $item (@{$sids_host->[$SIDS_HOST_T_ITEMS]}) {
			if ($item->[$SIDS_ITEM_T_DATA_ID] eq $data_id) {
				$err = "item '$data_id' re-defined";
				goto err;
			}
		}

		# Add this sids_item_t to sids_host_t
		push(@{$sids_host->[$SIDS_HOST_T_ITEMS]}, $sids_item);

		# Remove reference to this item since it was closed
		$context_data->[$_CONTEXT_DATA_ITEM] = undef;
	} elsif ($context == $_CONTEXT_EXIT_CODE) {
		# Prevent re-definition
		if (defined($sids_item->[$SIDS_ITEM_T_EXIT_CODE])) {
			$err = "element 'exit_code' re-defined";
			goto err;
		}
		$sids_item->[$SIDS_ITEM_T_EXIT_CODE] = $content;
	} elsif ($context == $_CONTEXT_START_TIME) {
		# Prevent re-definition
		if (defined($sids_item->[$SIDS_ITEM_T_START_TIME])) {
			$err = "element 'start_time' re-defined";
			goto err;
		}
		$sids_item->[$SIDS_ITEM_T_START_TIME] = $content;
	} elsif ($context == $_CONTEXT_END_TIME) {
		# Prevent re-definition
		if (defined($sids_item->[$SIDS_ITEM_T_END_TIME])) {
			$err = "element 'end_time' re-defined";
			goto err;
		}
		$sids_item->[$SIDS_ITEM_T_END_TIME] = $content;
	} elsif ($context == $_CONTEXT_DATA) {
		my $encoding = $attrs->{"encoding"};

		# Prevent re-definition
		if (defined($sids_item->[$SIDS_ITEM_T_DATA])) {
			$err = "element 'data' re-defined";
			goto err;
		}
		# Decode data
		$content = xml_decode_data($content, $encoding);
		$sids_item->[$SIDS_ITEM_T_DATA] = $content;
	} elsif ($context == $_CONTEXT_ERR_DATA) {
		my $encoding = $attrs->{"encoding"};

		# Prevent re-definition
		if (defined($sids_item->[$SIDS_ITEM_T_ERR_DATA])) {
			$err = "element 'err_data' re-defined";
			goto err;
		}
		# Decode data
		$content = xml_decode_data($content, $encoding);
		$sids_item->[$SIDS_ITEM_T_ERR_DATA] = $content;
	}

	# Update context
	pop(@$context_list);

	return;

err:
	if (defined($filename)) {
		die("File format error: $filename:".$expat->current_line().
		    ": $err\n");
	} else {
		die("File format error: line ".$expat->current_line().
		    ": $err\n");
	}
}

#
# _xml_sids_handle_char(state, @)
#
# Handle character data for a sids xml file.
#
sub _xml_sids_handle_char($@)
{
	my ($sids_state, $expat, $string) = @_;
	my ($context_list, $context_data, $sids, $filename) = @$sids_state;
	my $context = $context_list->[scalar(@$context_list) - 1];
	my $content;
	my $err;

	if ($context == $_CONTEXT_SYSINFO ||
	    $context == $_CONTEXT_INST ||
	    $context == $_CONTEXT_HOST ||
	    $context == $_CONTEXT_ITEM) {
		# Ignore whitespace
		if ($string =~ /^\s*$/) {
			return;
		}
		$err = "unexpected character data";
		goto err;
	}

	# Add to context data
	$content = $context_data->[$_CONTEXT_DATA_CHAR];
	$content .= xml_decode_predeclared($string);
	$context_data->[$_CONTEXT_DATA_CHAR] = $content;
	return;

err:
	if (defined($filename)) {
		die("File format error: $filename:".$expat->current_line().
		    ": $err\n");
	} else {
		die("File format error: line ".$expat->current_line().
		    ": $err\n");
	}
}

#
# _xml_sids_handle_final(state, @)
#
# Handle final event for a sids xml file.
#
sub _xml_sids_handle_final($@)
{
	my ($sids_state, $expat) = @_;

	return $sids_state->[$_SIDS_STATE_CONTEXT_SIDS];
}

#
# _merge_host(old, new)
#
# Merge host data from OLD and NEW and store result in OLD. In case a
# data point is available in both data sets, NEW takes precedence.
#
sub _merge_host($$)
{
	my ($old, $new) = @_;
	my $sysvar_db_new = $new->[$SIDS_HOST_T_SYSVAR_DB];

	# Copy sysvars
	foreach my $sysvar_id (keys(%{$sysvar_db_new})) {
		my $value = $sysvar_db_new->{$sysvar_id};

		$old->[$SIDS_HOST_T_SYSVAR_DB]->{$sysvar_id} = $value;
	}

	# Copy/merge sids items
item:
	foreach my $item_new (@{$new->[$SIDS_HOST_T_ITEMS]}) {
		my $data_id = $item_new->[$SIDS_ITEM_T_DATA_ID];

		foreach my $item_old (@{$old->[$SIDS_HOST_T_ITEMS]}) {
			if ($item_old->[$SIDS_ITEM_T_DATA_ID] eq $data_id) {
				# Overwrite previous data
				@$item_old = @$item_new;
				next item;
			}
		}
		push(@{$old->[$SIDS_HOST_T_ITEMS]}, $item_new);
	}
}

#
# _merge_inst(old, new)
#
# Merge instance data from OLD and NEW and store result in OLD. In case a
# data point is available in both data sets, NEW takes precedence.
#
sub _merge_inst($$)
{
	my ($old, $new) = @_;

	# Copy/merge sids hosts
host:
	foreach my $host_new (@{$new->[$SIDS_INST_T_HOSTS]}) {
		my $host_id = $host_new->[$SIDS_HOST_T_ID];

		foreach my $host_old (@{$old->[$SIDS_INST_T_HOSTS]}) {
			if ($host_old->[$SIDS_HOST_T_ID] eq $host_id) {
				_merge_host($host_old, $host_new);
				next host;
			}
		}
		push(@{$old->[$SIDS_INST_T_HOSTS]}, $host_new);
	}
}

#
# _merge_sids(old, new)
#
# Merge sids data from OLD and NEW and store result in OLD. In case a data
# point is available in both data sets, NEW takes precedence.
#
sub _merge_sids($$)
{
	my ($old, $new) = @_;

	# Copy/merge sids instances
inst:
	foreach my $inst_new (@{$new->[$SIDS_T_INSTS]}) {
		my $inst_id = $inst_new->[$SIDS_INST_T_ID];

		foreach my $inst_old (@{$old->[$SIDS_T_INSTS]}) {
			if ($inst_old->[$SIDS_INST_T_ID] eq $inst_id) {
				_merge_inst($inst_old, $inst_new);
				next inst;
			}
		}
		push(@{$old->[$SIDS_T_INSTS]}, $inst_new);
	}
}

#
# _replace_inst_id(sids, inst_id)
#
# Replace all instance IDs in SIDS with INST_ID.
#
sub _replace_inst_id($$)
{
	my ($sids, $inst_id) = @_;
	my $insts = $sids->[$SIDS_T_INSTS];
	my $inst;
	my $new;

	# Replace all instance IDs
	foreach $inst (@$insts) {
		$inst->[$SIDS_INST_T_ID] = $inst_id;
	}

	# Dummy merge operation to remove multiple instances with the same ID
	$new = [ [] ];
	_merge_sids($new, $sids);
	@$sids = @$new;
}

#
# _replace_host_id(sids, host_id)
#
# Replace all host IDs in SIDS with HOST_ID.
#
sub _replace_host_id($$)
{
	my ($sids, $host_id) = @_;
	my $insts = $sids->[$SIDS_T_INSTS];
	my $inst;
	my $new;

	# Replace all host IDs
	foreach $inst (@$insts) {
		my $hosts = $inst->[$SIDS_INST_T_HOSTS];
		my $host;

		foreach $host (@$hosts) {
			$host->[$SIDS_HOST_T_ID] = $host_id;
		}
	}

	# Dummy merge operation to remove multiple instances with the same ID
	$new = [ [] ];
	_merge_sids($new, $sids);
	@$sids = @$new;
}

#
# sids_xml_read(handle[, filename, merge, inst_id, host_id])
#
# Read sysinfo data set XML file from HANDLE and add it to database.
# If MERGE is non-zero, merge the read data to current data. If INST_ID
# is specified, replace all instance IDs found in the XML file with INST_ID.
# If HOST_ID is specified, replace all host IDs found in the XML file with
# INST_ID.
#
sub sids_xml_read($;$$$$)
{
	my ($handle, $filename, $merge, $inst_id, $host_id) = @_;
	my $sids_state = [ [], undef, [ [] ], $filename ];
	my $parser = new XML::Parser();
	my $sids;

	$parser->setHandlers(
		Start	=> sub { _xml_sids_handle_start($sids_state, @_) },
		End	=> sub { _xml_sids_handle_end($sids_state, @_) },
		Char	=> sub { _xml_sids_handle_char($sids_state, @_) },
		Final	=> sub { _xml_sids_handle_final($sids_state, @_) },
	);

	eval {
		local $SIG{__DIE__};
		$sids = $parser->parse($handle);
	};
	# Handle parse errors
	if (!defined($sids)) {
		my $err = $@;

		# Reformat parser errors
		$err =~ s/\n/ /g;
		$err =~ s/^\s*(\S.*) at .* line \d+\s*$/$1/;
		if ($err =~ /^File format/) {
			die("$err\n");
		} elsif (defined($filename)) {
			die("File format error: $filename: $err\n");
		} else {
			die("File format error: $err\n");
		}
	}

	if (defined($inst_id)) {
		_replace_inst_id($sids, $inst_id);
	}
	if (defined($host_id)) {
		_replace_host_id($sids, $host_id);
	}

	if ($merge) {
		my $old_sids = db_sids_get();

		_merge_sids($old_sids, $sids);
		db_sids_set_modified(1);
	} else {
		db_sids_set($sids);
	}
}


#
# Code entry
#

# Indicate successful module initialization
1;
