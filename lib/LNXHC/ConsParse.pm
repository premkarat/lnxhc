#
# LNXHC::ConsParse.pm
#   Linux Health Checker consumer parsing functions
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

package LNXHC::ConsParse;

use strict;
use warnings;

use Exporter qw(import);
use Cwd qw(abs_path);
use File::Basename qw(basename);
use File::Spec::Functions qw(file_name_is_absolute splitdir no_upwards
			     splitpath catfile);


#
# Local imports
#
use LNXHC::Consts qw($CONS_DEFAULT_STATE $CONS_DEF_CONS $CONS_DEF_CONS_AUTHOR
		     $CONS_DEF_CONS_EVENT $CONS_DEF_CONS_EXTRAFILE
		     $CONS_DEF_CONS_FORMAT $CONS_DEF_CONS_FREQ
		     $CONS_DEF_CONS_KEYWORDS $CONS_DEF_CONS_STATE
		     $CONS_DEF_CONS_TYPE $CONS_DEF_FILENAME $CONS_DEF_FORMAT
		     $CONS_DEF_PARAM $CONS_DEF_PARAM_DEFAULT
		     $CONS_DEF_PARAM_KEYWORDS $CONS_DESC_DESC
		     $CONS_DESC_FILENAME $CONS_DESC_FORMAT $CONS_DESC_PARAM
		     $CONS_DESC_TITLE $CONS_EVENT_T_ANY $CONS_EVENT_T_EX
		     $CONS_FMT_T_ENV $CONS_FMT_T_XML $CONS_FREQ_T_BOTH
		     $CONS_FREQ_T_FOREACH $CONS_FREQ_T_ONCE $CONS_PROG_FILENAME
		     $CONS_TYPE_T_HANDLER $CONS_TYPE_T_REPORT $INI_FILENAME);
use LNXHC::Ini qw(ini_check_keywords ini_format_single ini_get_assign_value
		  ini_get_assign_value_list ini_get_multi_ids ini_get_text_value
		  ini_read_file);
use LNXHC::Locale qw(localify);
use LNXHC::Misc qw(str_to_state validate_id);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&cons_parse_from_dir);


#
# Constants
#


#
# Global variables
#


#
# Sub-routines
#

#
# _get_cons_title(ini_desc)
#
# Retrieve and return the consumer title from description file INI_DESC.
#
sub _get_cons_title($)
{
	my ($ini_desc) = @_;

	return ini_format_single(ini_get_text_value($ini_desc,
						    $CONS_DESC_TITLE, 1));
}

#
# _get_cons_description(ini_desc)
#
# Retrieve and return the consumer description from INI_DESC.
#
sub _get_cons_description($)
{
	my ($ini_desc) = @_;

	return ini_get_text_value($ini_desc, $CONS_DESC_DESC, 1);
}

#
# _get_cons_authors(ini_def)
#
# Retrieve and return the consumer author list from INI_DEF.
#
sub _get_cons_authors($)
{
	my ($ini_def) = @_;
	my @values;
	my @authors;
	my $entry;

	@values = ini_get_assign_value_list($ini_def, $CONS_DEF_CONS,
					    $CONS_DEF_CONS_AUTHOR, 1);

	foreach $entry (@values) {
		my ($line, $value) = @$entry;

		push(@authors, $value);
	}

	return @authors;
}

#
# _get_cons_format(ini_def)
#
# Retrieve and return the consumer input format from definitions file INI_DEF.
#
sub _get_cons_format($)
{
	my ($ini_def) = @_;
	my ($filename) = @$ini_def;
	my ($line, $value) = ini_get_assign_value($ini_def, $CONS_DEF_CONS,
						  $CONS_DEF_CONS_FORMAT, 1);

	if ($value =~ /^\s*xml\s*$/i) {
		return $CONS_FMT_T_XML;
	} elsif ($value =~ /^\s*env\s*$/i) {
		return $CONS_FMT_T_ENV;
	}

	die("$filename:$line: unrecognized value for keyword ".
	    "'$CONS_DEF_CONS_FORMAT': '$value'\n");
}

#
# _get_cons_frequency(ini_def)
#
# Retrieve and return the consumer call frequency from definitions file INI_DEF.
#
sub _get_cons_frequency($)
{
	my ($ini_def) = @_;
	my ($filename) = @$ini_def;
	my ($line, $value) = ini_get_assign_value($ini_def, $CONS_DEF_CONS,
						  $CONS_DEF_CONS_FREQ, 1);

	if ($value =~ /^\s*foreach\s*$/i) {
		return $CONS_FREQ_T_FOREACH;
	} elsif ($value =~ /^\s*once\s*$/i) {
		return $CONS_FREQ_T_ONCE;
	} elsif ($value =~ /^\s*both\s*$/i) {
		return $CONS_FREQ_T_BOTH;
	}

	die("$filename:$line: unrecognized value for keyword ".
	    "'$CONS_DEF_CONS_FREQ': '$value'\n");
}

#
# _get_cons_event(ini_def)
#
# Retrieve and return the consumer event type from definitions file INI_DEF.
#
sub _get_cons_event($)
{
	my ($ini_def) = @_;
	my ($filename) = @$ini_def;
	my ($line, $value) = ini_get_assign_value($ini_def, $CONS_DEF_CONS,
						  $CONS_DEF_CONS_EVENT, 1);

	if ($value =~ /^\s*exception\s*$/i) {
		return $CONS_EVENT_T_EX;
	} elsif ($value =~ /^\s*any\s*$/i) {
		return $CONS_EVENT_T_ANY;
	}

	die("$filename:$line: unrecognized value for keyword ".
	    "'$CONS_DEF_CONS_EVENT': '$value'\n");
}

#
# _get_cons_type(ini_def)
#
# Retrieve and return the consumer type from definitions file INI_DEF.
#
sub _get_cons_type($)
{
	my ($ini_def) = @_;
	my ($filename) = @$ini_def;
	my ($line, $value) = ini_get_assign_value($ini_def, $CONS_DEF_CONS,
						  $CONS_DEF_CONS_TYPE, 1);

	if ($value =~ /^\s*handler\s*$/i) {
		return $CONS_TYPE_T_HANDLER;
	} elsif ($value =~ /^\s*report\s*$/i) {
		return $CONS_TYPE_T_REPORT;
	}

	die("$filename:$line: unrecognized value for keyword ".
	    "'$CONS_DEF_CONS_TYPE': '$value'\n");
}

#
# _get_cons_state(ini)
#
# Retrieve and return the default activation state from definitions file INI.
#
sub _get_cons_state($)
{
	my ($ini) = @_;
	my ($filename) = @$ini;
	my ($line, $value) = ini_get_assign_value($ini, $CONS_DEF_CONS,
						  $CONS_DEF_CONS_STATE, 0);
	if (!defined($value)) {
		# Use default value
		return $CONS_DEFAULT_STATE;
	}

	return str_to_state($value, "$filename:$line");
}

#
# _get_cons_parameters(ini_def, ini_desc)
#
# result: parameter id -> struct param_t
#
sub _get_cons_parameters($$)
{
	my ($ini_def, $ini_desc) = @_;
	my $filename_desc = $ini_desc->[$INI_FILENAME];
	my $id_def;
	my $id_desc;
	my $id;
	my %result;

	# Get list of parameter IDs from definitions file
	$id_def = ini_get_multi_ids($ini_def, $CONS_DEF_PARAM);
	# Get list of parameter IDs from descriptions file
	$id_desc = ini_get_multi_ids($ini_desc, $CONS_DESC_PARAM);

	# Ensure that IDs in definitions file are specified in descriptions file
	# as well
	foreach $id (keys(%{$id_def})) {
		if (!defined($id_desc->{$id})) {
			die("$filename_desc: missing section for ".
			    "parameter '$id'\n");
		}
	}

	# Retrieve parameter values from ini files
	foreach $id (keys(%{$id_desc})) {
		my $sec_id = $id_desc->{$id};
		my $desc;
		my $value;

		# Check keywords in parameter section
		ini_check_keywords($ini_def, $sec_id,
				   $CONS_DEF_PARAM_KEYWORDS);

		# Get parameter data
		$desc = ini_get_text_value($ini_desc, $sec_id, 1);
		(undef, $value) = ini_get_assign_value($ini_def, $sec_id,
						$CONS_DEF_PARAM_DEFAULT, 0);
		# Use empty string if no default is specified
		$value = "" if (!defined($value));
		$result{$id} = [ $id, $desc, $value ];
	}

	return \%result;
}

#
# _get_sec_extrafiles(ini, section, keyword, cons_dir)
#
# Return list of extrafile specifications found in file INI, section SECTION.
#
sub _get_sec_extrafiles($$$$)
{
	my ($ini, $section, $keyword, $cons_dir) = @_;
	my ($ini_filename) = @$ini;
	my @values;
	my @extrafiles;
	my $entry;
	my %known;

	@values = ini_get_assign_value_list($ini, $section, $keyword);
	foreach $entry (@values) {
		my ($line, $value) = @$entry;
		my (undef, $dir) = splitpath($value);
		my @path = splitdir($dir);
		my $full_file = catfile($cons_dir, $value);

		# Path must
		# 1. be relative
		if (file_name_is_absolute($value)) {
			die("$ini_filename:$line: Path '$value' is ".
			    "absolute!\n");
		}
		# 2. not leave cons directory
		if (scalar(no_upwards(@path)) != scalar(@path)) {
			die("$ini_filename:$line: Path '$value' contains ".
			    "relative components!\n");
		}
		# 3. must not be specified more than once
		if ($known{$value}) {
			die("$ini_filename:$line: Path '$value' already ".
			    "specified in line ".$known{$value}."!\n");
		}
		# 4. must exist
		if (! -e $full_file) {
			die("$ini_filename:$line: File '$full_file' does not ".
			    "exist!\n");
		}

		push(@extrafiles, $value);
		$known{$value} = $line;
	}

	return @extrafiles;
}

#
# _get_cons_extrafiles(ini)
#
# Retrieve and return the list of extra files from definitions file INI.
#
sub _get_cons_extrafiles($$)
{
	my ($ini, $cons_dir) = @_;

	return _get_sec_extrafiles($ini, $CONS_DEF_CONS,
				   $CONS_DEF_CONS_EXTRAFILE, $cons_dir);
}

#
# _cons_from_ini(cons_id, cons_dir, ini_def, ini_desc)
#
# Create a struct cons_t from the specified consumer ID cons_ID, directory
# name cons_dir, definitions file data ini_def and description file data
# ini_desc.
#
# result: cons_t
# cons_t: [ cons_id, title, desc, author, format, freq, event, type,
#           param_db, dir ]
#
sub _cons_from_ini($$$$)
{
	my ($cons_id, $dir, $ini_def, $ini_desc) = @_;
	my $title;
	my $desc;
	my @authors;
	my $format;
	my $freq;
	my $event;
	my $type;
	my $state;
	my $param_db;
	my @extrafiles;

	# Check keywords in consumer section
	ini_check_keywords($ini_def, $CONS_DEF_CONS, $CONS_DEF_CONS_KEYWORDS);

	# Get consumer data
	$title		= _get_cons_title($ini_desc);
	$desc		= _get_cons_description($ini_desc);
	@authors	= _get_cons_authors($ini_def);
	$format		= _get_cons_format($ini_def);
	$freq		= _get_cons_frequency($ini_def);
	$event		= _get_cons_event($ini_def);
	$type		= _get_cons_type($ini_def);
	$state		= _get_cons_state($ini_def);
	$param_db	= _get_cons_parameters($ini_def, $ini_desc);
	@extrafiles	= _get_cons_extrafiles($ini_def, $dir);

	return [ $cons_id, $title, $desc, \@authors, $format, $freq, $event,
		 $type, $param_db, $dir, $state, \@extrafiles ];
}

#
# cons_get_from_dir(directory)
#
# Read consumer from directory and return the resulting struct cons_t.
#
sub cons_parse_from_dir($)
{
	my ($directory) = @_;
	my $id;
	my $ini_def;
	my $ini_desc;
	my $cons_dir;
	my $err;
	my @cons_files = ( [ $CONS_PROG_FILENAME,	1 ], # Name, executable
			   [ $CONS_DEF_FILENAME,	0 ],
			   [ $CONS_DESC_FILENAME,	0 ],
			 );

	$directory =~ s/\/+$//;
	$cons_dir = abs_path($directory);
	# Check if directory exists
	if (!defined($cons_dir) || ! -e $cons_dir) {
		$err = "directory not found";
		goto err;
	}
	if (! -d $cons_dir) {
		$err = "not a directory";
		goto err;
	}

	# Ensure that ID is valid
	$id = basename($cons_dir);
	validate_id("consumer name", $id);

	# Ensure valid files
	foreach my $entry (@cons_files) {
		my ($filename, $is_executable) = @$entry;

		$filename = catfile($directory, $filename);
		if (!-e $filename) {
			$err = "missing file '$filename'";
			goto err;
		}
		if (!-f $filename) {
			$err = "'$filename' must be a plain file";
			goto err;
		}
		if ($is_executable && !-x $filename) {
			$err = "file '$filename' must be executable";
			goto err;
		}
	}

	# Read definitions file
	$ini_def = ini_read_file(catfile($directory, $CONS_DEF_FILENAME),
				 $CONS_DEF_FORMAT);
	# Read descriptions file
	$ini_desc = ini_read_file(localify($directory, $CONS_DESC_FILENAME),
				  $CONS_DESC_FORMAT);

	return _cons_from_ini($id, $cons_dir, $ini_def, $ini_desc);

err:
	die("Could not read consumer from '$directory': $err!\n");
}


#
# Code entry
#

# Indicate successful module initialization
1;
