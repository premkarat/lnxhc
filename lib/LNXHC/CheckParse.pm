#
# LNXHC::CheckParse.pm
#   Linux Health Checker check parsing functions
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

package LNXHC::CheckParse;

use strict;
use warnings;

use Exporter qw(import);
use Cwd qw(abs_path);
use File::Basename qw(basename dirname);
use File::Spec::Functions qw(file_name_is_absolute splitdir no_upwards
			     splitpath catfile);


#
# Local imports
#
use LNXHC::Consts qw($CHECK_DEFAULT_REPEAT $CHECK_DEFAULT_STATE $CHECK_DEF_CHECK
		     $CHECK_DEF_CHECK_AUTHOR $CHECK_DEF_CHECK_COMPONENT
		     $CHECK_DEF_CHECK_EXTRAFILE $CHECK_DEF_CHECK_KEYWORDS
		     $CHECK_DEF_CHECK_MULTIHOST $CHECK_DEF_CHECK_MULTITIME
		     $CHECK_DEF_CHECK_REPEAT $CHECK_DEF_CHECK_STATE
		     $CHECK_DEF_CHECK_TAG $CHECK_DEF_DEPS $CHECK_DEF_EX
		     $CHECK_DEF_EX_KEYWORDS $CHECK_DEF_EX_SEVERITY
		     $CHECK_DEF_EX_STATE $CHECK_DEF_FILENAME $CHECK_DEF_FORMAT
		     $CHECK_DEF_PARAM $CHECK_DEF_PARAM_DEFAULT
		     $CHECK_DEF_PARAM_KEYWORDS $CHECK_DEF_SI
		     $CHECK_DEF_SI_EXT_EXTERNAL $CHECK_DEF_SI_EXT_KEYWORDS
		     $CHECK_DEF_SI_FILE_FILE $CHECK_DEF_SI_FILE_KEYWORDS
		     $CHECK_DEF_SI_FILE_USER $CHECK_DEF_SI_PROG_EXTRAFILE
		     $CHECK_DEF_SI_PROG_IGNORERC $CHECK_DEF_SI_PROG_KEYWORDS
		     $CHECK_DEF_SI_PROG_PROGRAM $CHECK_DEF_SI_PROG_USER
		     $CHECK_DEF_SI_REC_DURATION $CHECK_DEF_SI_REC_EXTRAFILE
		     $CHECK_DEF_SI_REC_KEYWORDS $CHECK_DEF_SI_REC_START
		     $CHECK_DEF_SI_REC_STOP $CHECK_DEF_SI_REC_USER
		     $CHECK_DEF_SI_REF_KEYWORDS $CHECK_DEF_SI_REF_REF
		     $CHECK_DESC_DESC $CHECK_DESC_FILENAME $CHECK_DESC_FORMAT
		     $CHECK_DESC_PARAM $CHECK_DESC_TITLE $CHECK_DIR_VAR
		     $CHECK_EX_EXPLANATION $CHECK_EX_FILENAME $CHECK_EX_FORMAT
		     $CHECK_EX_REFERENCE $CHECK_EX_SOLUTION $CHECK_EX_SUMMARY
		     $CHECK_PROG_FILENAME $INI_FILENAME $INI_SEC_LINE $MATCH_ID
		     $SI_TYPE_T_EXT $SI_TYPE_T_FILE $SI_TYPE_T_PROG
		     $SI_TYPE_T_REC $SI_TYPE_T_REF);
use LNXHC::Expr qw(expr_parse);
use LNXHC::Ini qw(ini_check_keywords ini_format_single ini_get_assign_value
		  ini_get_assign_value_list ini_get_bool_expr_list
		  ini_get_multi_ids ini_get_text_value ini_read_file);
use LNXHC::Locale qw(localify);
use LNXHC::Misc qw(str_to_sev str_to_state unique validate_duration
		   validate_id);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&check_parse_from_dir);


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
# _get_check_title(ini)
#
# Retrieve and return the check title from description file INI.
#
sub _get_check_title($)
{
	my ($ini) = @_;

	return ini_format_single(ini_get_text_value($ini,
						    $CHECK_DESC_TITLE, 1));
}

#
# _get_check_description(ini)
#
# Retrieve and return the check description from description file INI.
#
sub _get_check_description($)
{
	my ($ini) = @_;

	return ini_get_text_value($ini, $CHECK_DESC_DESC, 1);
}

#
# _get_check_authors(ini)
#
# Retrieve and return the list of check authors from definitions file INI.
#
sub _get_check_authors($)
{
	my ($ini) = @_;
	my @values;
	my @authors;
	my $entry;

	@values = ini_get_assign_value_list($ini, $CHECK_DEF_CHECK,
					    $CHECK_DEF_CHECK_AUTHOR, 1);
	foreach $entry (@values) {
		my ($line, $value) = @$entry;

		push(@authors, $value);
	}

	return @authors;
}

#
# _get_check_tags(ini)
#
# Retrieve and return the list of check tags from definitions file INI.
#
sub _get_check_tags($)
{
	my ($ini) = @_;
	my ($filename) = @$ini;
	my @values;
	my @tags;
	my $entry;

	@values = ini_get_assign_value_list($ini, $CHECK_DEF_CHECK,
					    $CHECK_DEF_CHECK_TAG, 0);
	foreach $entry (@values) {
		my ($line, $value) = @$entry;

		# Ensure that only identifiers are used as tags
		validate_id("tag", $value, undef, "$filename:$line");
		push(@tags, $value);
	}

	return @tags;
}

#
# _get_check_state(ini)
#
# Retrieve and return the default activation state from definitions file INI.
#
sub _get_check_state($)
{
	my ($ini) = @_;
	my ($filename) = @$ini;
	my ($line, $value) = ini_get_assign_value($ini, $CHECK_DEF_CHECK,
						  $CHECK_DEF_CHECK_STATE, 0);
	if (!defined($value)) {
		# Use default value
		return $CHECK_DEFAULT_STATE;
	}

	return str_to_state($value, "$filename:$line");
}

#
# _get_check_repeat(ini)
#
# Retrieve and return the default repeat interval from definitions file INI.
#
sub _get_check_repeat($)
{
	my ($ini) = @_;
	my ($filename) = @$ini;
	my ($line, $value) = ini_get_assign_value($ini, $CHECK_DEF_CHECK,
						  $CHECK_DEF_CHECK_REPEAT, 0);

	if (!defined($value)) {
		# Use default value
		return $CHECK_DEFAULT_REPEAT;
	}

	validate_duration($value, 1, "$filename:$line");

	return $value;
}

#
# _get_check_dependencies(ini)
#
# Retrieve and return the list of dependencies from definitions file INI.
#
sub _get_check_dependencies($)
{
	my ($ini) = @_;
	my ($filename) = @$ini;
	my @list;
	my @deps;
	my $entry;

	@list = ini_get_bool_expr_list($ini, $CHECK_DEF_DEPS, 0);
	foreach $entry (@list) {
		my ($line, $dep) = @$entry;
		my $expr;

		$expr = expr_parse("$filename:$line", $dep);

		push(@deps, [ $dep, $expr ]);
	}

	return @deps;
}

#
# _get_check_parameters(ini_def, ini_desc)
#
# Retrieve and return check parameters from definitions file CHECK_DEF and
# description file INI_DESC.
#
# result: \{ parameter id -> struct param_t }
#
sub _get_check_parameters($$)
{
	my ($ini_def, $ini_desc) = @_;
	my $filename_desc = $ini_desc->[$INI_FILENAME];
	my $id_def;
	my $id_desc;
	my $id;
	my %result;

	# Get list of parameter IDs from definitions file
	$id_def = ini_get_multi_ids($ini_def, $CHECK_DEF_PARAM);
	# Get list of parameter IDs from descriptions file
	$id_desc = ini_get_multi_ids($ini_desc, $CHECK_DESC_PARAM);

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
				   $CHECK_DEF_PARAM_KEYWORDS);

		# Get parameter data
		$desc = ini_get_text_value($ini_desc, $sec_id, 1);
		(undef, $value) = ini_get_assign_value($ini_def, $sec_id,
						$CHECK_DEF_PARAM_DEFAULT, 0);
		# Use empty string if no default is specified
		$value = "" if (!defined($value));
		$result{$id} = [ $id, $desc, $value ];
	}

	return \%result;
}

#
# _get_exception_variables(text)
#
# Return a list of exception variables found in TEXT.
#
sub _get_exception_variables($)
{
	my ($text) = @_;
	my @result;

	# Remove escaped characters first
	$text =~ s/\\.//g;
	# Collect all variables
	while ($text =~ s/&($MATCH_ID);//) {
		push(@result, $1);
	}

	return @result;
}

#
# _get_check_exceptions(ini_def, ini_ex)
#
# Retrieve and return check exceptions from definitions file CHECK_DEF and
# exceptions file INI_EX.
#
# result: \{ exception id -> struct ex_t }
#
sub _get_check_exceptions($$)
{
	my ($ini_def, $ini_ex) = @_;
	my ($def_filename) = @$ini_def;
	my $id_def;
	my $id_summary;
	my $id_explanation;
	my $id_solution;
	my $id_reference;
	my $id;
	my @ids;
	my %result;

	# Get list of exception IDs from definitions file
	$id_def = ini_get_multi_ids($ini_def, $CHECK_DEF_EX);
	# Get list of exception IDs from exceptions file
	$id_summary	= ini_get_multi_ids($ini_ex, $CHECK_EX_SUMMARY);
	$id_explanation	= ini_get_multi_ids($ini_ex, $CHECK_EX_EXPLANATION);
	$id_solution	= ini_get_multi_ids($ini_ex, $CHECK_EX_SOLUTION);
	$id_reference	= ini_get_multi_ids($ini_ex, $CHECK_EX_REFERENCE);
	# Collect IDs
	@ids = sort(unique(keys(%{$id_def}), keys(%{$id_summary}),
			   keys(%{$id_explanation}), keys(%{$id_solution}),
			   keys(%{$id_reference})));

	# Retrieve exception values from ini files
	foreach $id (@ids) {
		my $summary;
		my $explanation;
		my $solution;
		my $reference;
		my $severity;
		my $state;
		my $value;
		my $line;
		my @variables;
		my $def_sec_id = "$CHECK_DEF_EX $id";

		# Check keywords in exception section
		ini_check_keywords($ini_def, $def_sec_id,
				   $CHECK_DEF_EX_KEYWORDS);

		# Retrieve exception description text
		$summary	= ini_get_text_value($ini_ex,
						 "$CHECK_EX_SUMMARY $id", 1);
		$explanation	= ini_get_text_value($ini_ex,
					"$CHECK_EX_EXPLANATION $id", 1);
		$solution	= ini_get_text_value($ini_ex,
						 "$CHECK_EX_SOLUTION $id", 1);
		$reference	= ini_get_text_value($ini_ex,
						 "$CHECK_EX_REFERENCE $id", 1);
		# Format texts
		$summary	= ini_format_single($summary);
		$explanation	= $explanation;
		$solution	= $solution;
		$reference	= $reference;

		# Retrieve exception settings from definitions file
		($line, $value) = ini_get_assign_value($ini_def,
					$def_sec_id, $CHECK_DEF_EX_SEVERITY, 1);
		$severity = str_to_sev($value, "$def_filename:$line");
		($line, $value) = ini_get_assign_value($ini_def,
					$def_sec_id, $CHECK_DEF_EX_STATE, 0);
		if (!defined($line)) {
			$line = "";
		}
		if (defined($value)) {
			$state = str_to_state($value, "$def_filename:$line");
		} else {
			# Use default value
			$state = $CHECK_DEFAULT_STATE;
		}

		# Determine exception variables
		push(@variables, _get_exception_variables($summary));
		push(@variables, _get_exception_variables($explanation));
		push(@variables, _get_exception_variables($solution));
		push(@variables, _get_exception_variables($reference));
		@variables = unique(@variables);

		$result{$id} = [ $id, $summary, $explanation, $solution,
				 $reference, $severity, $state, \@variables ];
	}

	return \%result;
}

#
# _validate_sysinfo_file(source, filename)
#
# Check if the specified filename is valid in the context of a sysinfo file
# section.
#
sub _validate_sysinfo_file($$)
{
	my ($source, $filename) = @_;

	# Accept absolute file specifications
	if (!file_name_is_absolute($filename)) {
		die("$source: file path '$filename' is not absolute\n");
	}
}

#
# _validate_sysinfo_prog(source, cmdline)
#
# Check if the specified command line CMDLINE is valid in the context of a
# sysinfo program or record section.
#
sub _validate_sysinfo_prog($$)
{
	my ($source, $cmdline) = @_;
	my $program;
	my $dirname;
	my @path;

	# Check for empty command
	if (!($cmdline =~ /^\s*(\S+)/)) {
		die("$source: empty command line\n");
	}
	$program = $1;
	$dirname = dirname($program);
	# Does program specification contain a path?
	if ($dirname eq ".") {
		return 0;
	}
	@path = splitdir($dirname);
	# Is path absolute (first directory is root directory)?
	if ($path[0] eq "") {
		return 0;
	}
	# Are there .. or . in the path?
	if (scalar(no_upwards(@path)) != scalar(@path)) {
		die("$source: unsupported path components in '$program'\n");
	}
	# Is the first path a reference to the check directory?
	if ($path[0] eq "\$$CHECK_DIR_VAR") {
		return;
	}
	# Are there sub-directories?
	if (@path) {
		die("$source: unsupported relative path '$program'\n");
	}
}

#
# _get_sec_extrafiles(ini, section, keyword, check_dir)
#
# Return list of extrafile specifications found in file INI, section SECTION.
#
sub _get_sec_extrafiles($$$$)
{
	my ($ini, $section, $keyword, $check_dir) = @_;
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
		my $full_file = catfile($check_dir, $value);

		# Path must
		# 1. be relative
		if (file_name_is_absolute($value)) {
			die("$ini_filename:$line: Path '$value' is ".
			    "absolute!\n");
		}
		# 2. not leave check directory
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
# _get_check_sysinfo_data(ini, id, check_dir)
#
# Retrieve sysinfo type and data from section ID of file INI.
#
sub _get_check_sysinfo_data($$$)
{
	my ($ini, $id, $check_dir) = @_;
	my ($filename, $sections) = @$ini;
	my $sec_id = "$CHECK_DEF_SI $id";
	my $section = $sections->{$sec_id};
	my $sec_line = $section->[$INI_SEC_LINE];
	my $line;
	my $value;

	# Check for file keyword in sysinfo section
	($line, $value) = ini_get_assign_value($ini, $sec_id,
					       $CHECK_DEF_SI_FILE_FILE, 0);
	if (defined($value)) {
		my $user;

		# Check section keywords
		ini_check_keywords($ini, $sec_id, $CHECK_DEF_SI_FILE_KEYWORDS);
		# File type sysinfo item
		_validate_sysinfo_file("$filename:$line", $value);
		(undef, $user) = ini_get_assign_value($ini, $sec_id,
						$CHECK_DEF_SI_FILE_USER, 0);
		$user = "" if (!defined($user));

		return ($SI_TYPE_T_FILE, [ $value, $user ]);
	}

	# Check for program keyword in sysinfo section
	($line, $value) = ini_get_assign_value($ini, $sec_id,
					       $CHECK_DEF_SI_PROG_PROGRAM, 0);
	if (defined($value)) {
		my $user;
		my $ignorerc;
		my @extrafiles;

		# Check section keywords
		ini_check_keywords($ini, $sec_id, $CHECK_DEF_SI_PROG_KEYWORDS);
		# Program type sysinfo item
		_validate_sysinfo_prog("$filename:$line", $value);
		# Get user keyword data
		(undef, $user) = ini_get_assign_value($ini, $sec_id,
					      $CHECK_DEF_SI_PROG_USER, 0);
		$user = "" if (!defined($user));
		# Get ignorerc keyword data
		(undef, $ignorerc) = ini_get_assign_value($ini, $sec_id,
					      $CHECK_DEF_SI_PROG_IGNORERC, 0);
		$ignorerc = 0 if (!defined($ignorerc));
		# Get extrafile keyword data
		@extrafiles = _get_sec_extrafiles($ini, $sec_id,
						  $CHECK_DEF_SI_PROG_EXTRAFILE,
						  $check_dir);

		return ($SI_TYPE_T_PROG, [ $value, $user, $ignorerc,
					   \@extrafiles ]);
	}

	# Check for start keyword in sysinfo section
	($line, $value) = ini_get_assign_value($ini, $sec_id,
					       $CHECK_DEF_SI_REC_START, 0);
	if (defined($value)) {
		my $stop;
		my $duration;
		my $user;
		my @extrafiles;

		# Check section keywords
		ini_check_keywords($ini, $sec_id, $CHECK_DEF_SI_REC_KEYWORDS);
		# Record type sysinfo item
		_validate_sysinfo_prog("$filename:$line", $value);
		($line, $stop) = ini_get_assign_value($ini, $sec_id,
					$CHECK_DEF_SI_REC_STOP, 1);
		_validate_sysinfo_prog("$filename:$line", $stop);
		# Get duration keyword data
		($line, $duration) = ini_get_assign_value($ini, $sec_id,
					$CHECK_DEF_SI_REC_DURATION, 1);
		validate_duration($duration, 0, "$filename:$line");
		# Get user keyword data
		(undef, $user) = ini_get_assign_value($ini, $sec_id,
					$CHECK_DEF_SI_REC_USER, 0);
		$user = "" if (!defined($user));
		# Get extrafile keyword data
		@extrafiles = _get_sec_extrafiles($ini, $sec_id,
						  $CHECK_DEF_SI_REC_EXTRAFILE,
						  $check_dir);

		return ($SI_TYPE_T_REC, [ $value, $stop, $duration,
					  $user, \@extrafiles ]);
	}

	# Check for ref keyword in sysinfo section
	($line, $value) = ini_get_assign_value($ini, $sec_id,
					       $CHECK_DEF_SI_REF_REF, 0);
	if (defined($value)) {
		my $ref_check;
		my $ref_si_id;

		# Check section keywords
		ini_check_keywords($ini, $sec_id, $CHECK_DEF_SI_REF_KEYWORDS);
		if (!($value =~ /^(.*)\.(.*)$/)) {
			die("$filename: $line: unsupported reference format\n");
		}
		($ref_check, $ref_si_id) = ($1, $2);
		validate_id("check name", $ref_check, undef, "$filename:$line");
		validate_id("sysinfo ID", $ref_si_id, undef, "$filename:$line");
		# Reference type sysinfo item
		return ($SI_TYPE_T_REF, [ $ref_check, $ref_si_id ]);
	}

	# Check for external keyword in sysinfo section
	($line, $value) = ini_get_assign_value($ini, $sec_id,
					       $CHECK_DEF_SI_EXT_EXTERNAL, 0);
	# Note: we need to test for line here because external is statement
	# without a value
	if (defined($line)) {
		# Check section keywords
		ini_check_keywords($ini, $sec_id, $CHECK_DEF_SI_EXT_KEYWORDS);
		# External type sysinfo item
		return ($SI_TYPE_T_EXT, []);
	}

	# No valid type
	die("$filename:$sec_line: could not determine type of sysinfo ".
	    "section '$sec_id'\n");
}

#
# _get_check_sysinfo(ini, check_dir)
#
# Retrieve and return check sysinfo items the from definitions file INI.
#
# result: \{ sysinfo id -> struct sysinfo_t }
#
sub _get_check_sysinfo($$)
{
	my ($ini, $check_dir) = @_;
	my $ids;
	my $id;
	my %result;

	# Get list of sysinfo IDs from definitions file
	$ids = ini_get_multi_ids($ini, $CHECK_DEF_SI);
	foreach $id (keys(%{$ids})) {
		my $type;
		my $data;

		($type, $data) = _get_check_sysinfo_data($ini, $id, $check_dir);
		$result{$id} = [ $id, $type, $data ];
	}

	return \%result;
}

#
# _get_check_multihost(ini)
#
# Retrieve and return the multihost flag from definitions file INI.
#
sub _get_check_multihost($)
{
	my ($ini) = @_;
	my ($filename) = @$ini;
	my ($line, $value) = ini_get_assign_value($ini, $CHECK_DEF_CHECK,
						$CHECK_DEF_CHECK_MULTIHOST, 0);

	if (!defined($line)) {
		# Default value is an empty string
		return "";
	}
	if (!($value =~ s/^\s*([01])\s*/$1/)) {
		die("$filename:$line: invalid value for keyword ".
		    "'$CHECK_DEF_CHECK_MULTIHOST' found: '$value'\n");
	}

	return $value;
}

#
# _get_check_multitime(ini)
#
# Retrieve and return the multitime flag from definitions file INI.
#
sub _get_check_multitime($)
{
	my ($ini) = @_;
	my ($filename) = @$ini;
	my ($line, $value) = ini_get_assign_value($ini, $CHECK_DEF_CHECK,
						$CHECK_DEF_CHECK_MULTITIME, 0);

	if (!defined($line)) {
		# Default value is an empty string
		return "";
	}
	if (!($value =~ s/^\s*([01])\s*/$1/)) {
		die("$filename:$line: invalid value for keyword ".
		    "'$CHECK_DEF_CHECK_MULTITIME' found: '$value'\n");
	}

	return $value;
}

#
# _get_check_component(ini)
#
# Retrieve and return the check component from definitions file INI.
#
sub _get_check_component($)
{
	my ($ini) = @_;
	my ($filename) = @$ini;
	my ($line, $value) = ini_get_assign_value($ini, $CHECK_DEF_CHECK,
					$CHECK_DEF_CHECK_COMPONENT, 1);

	# Remove leading and trailing whitespaces
	$value =~ s/^\s*//;
	$value =~ s/\s*$//;

	# Check for empty value
	if ($value eq "") {
		die("$filename:$line: invalid value for keyword ".
		    "'$CHECK_DEF_CHECK_COMPONENT' found: '$value'\n");
	}

	return $value;
}

#
# _get_check_extrafiles(ini)
#
# Retrieve and return the list of extra files from definitions file INI.
#
sub _get_check_extrafiles($$)
{
	my ($ini, $check_dir) = @_;

	return _get_sec_extrafiles($ini, $CHECK_DEF_CHECK,
				   $CHECK_DEF_CHECK_EXTRAFILE, $check_dir);
}

#
# _check_from_ini(id, directory, definitions, description, exceptions)
#
# Create and return a check data structure (struct check_t) from ini-file data
# DEFINITIONS, DESCRIPTION and EXCEPTIONS.
#
sub _check_from_ini($$$$$)
{
	my ($id, $directory, $ini_def, $ini_desc, $ini_ex) = @_;
	my $title;
	my $desc;
	my @authors;
	my @tags;
	my $state;
	my $repeat;
	my @deps;
	my $params;
	my $exceptions,
	my $sysinfo;
	my $multihost;
	my $multitime;
	my $component;
	my @extrafiles;

	# Check keywords in check section
	ini_check_keywords($ini_def, $CHECK_DEF_CHECK,
			   $CHECK_DEF_CHECK_KEYWORDS);
	# Get check data
	$title		= _get_check_title($ini_desc);
	$desc		= _get_check_description($ini_desc);
	@authors	= _get_check_authors($ini_def);
	@tags		= _get_check_tags($ini_def);
	$state		= _get_check_state($ini_def);
	$repeat		= _get_check_repeat($ini_def);
	@deps		= _get_check_dependencies($ini_def);
	$params		= _get_check_parameters($ini_def, $ini_desc);
	$exceptions	= _get_check_exceptions($ini_def, $ini_ex);
	$sysinfo	= _get_check_sysinfo($ini_def, $directory);
	$multihost	= _get_check_multihost($ini_def);
	$multitime	= _get_check_multitime($ini_def);
	$component	= _get_check_component($ini_def);
	@extrafiles	= _get_check_extrafiles($ini_def, $directory);

	return [ $id, $title, $desc, \@authors, \@tags, $state, $repeat,
		 \@deps, $params, $exceptions, $sysinfo, $multihost,
		 $multitime, $directory, $component, \@extrafiles ];
}

#
# check_parse_from_dir(directory)
#
# Read check from directory and return the resulting struct check_t.
#
sub check_parse_from_dir($)
{
	my ($directory) = @_;
	my $id;
	my $ini_def;
	my $ini_desc;
	my $ini_ex;
	my $check_dir;
	my $err;
	my @check_files = ( [ $CHECK_PROG_FILENAME,	1 ], # Name, executable?
			    [ $CHECK_DEF_FILENAME,	0 ],
			    [ $CHECK_DESC_FILENAME,	0 ],
			    [ $CHECK_EX_FILENAME,	0 ],
			  );

	$directory =~ s/\/+$//;
	$check_dir = abs_path($directory);
	# Check if directory exists
	if (!defined($check_dir) || ! -e $check_dir) {
		$err = "directory not found";
		goto err;
	}
	if (! -d $check_dir) {
		$err = "not a directory";
		goto err;
	}

	# Ensure that ID is valid
	$id = basename($check_dir);
	validate_id("check name", $id);

	# Ensure valid files
	foreach my $entry (@check_files) {
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
	$ini_def = ini_read_file(catfile($directory, $CHECK_DEF_FILENAME),
				 $CHECK_DEF_FORMAT);
	# Read descriptions file
	$ini_desc = ini_read_file(localify($directory, $CHECK_DESC_FILENAME),
				  $CHECK_DESC_FORMAT);
	# Read exceptions file
	$ini_ex = ini_read_file(localify($directory, $CHECK_EX_FILENAME),
				$CHECK_EX_FORMAT);

	return _check_from_ini($id, $check_dir, $ini_def, $ini_desc, $ini_ex);

err:
	die("Could not read check from '$directory': $err!\n");
}


#
# Code entry
#

# Indicate successful module initialization
1;
