#
# LNXHC::Ini.pm
#   Linux Health Checker support functions for parsing .ini-files
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

package LNXHC::Ini;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#
use LNXHC::Consts qw($INI_SEC_CONTENT $INI_SEC_LINE $INI_SEC_TYPE $INI_TEXT_TEXT
		     $INI_TYPE_ASSIGNMENT $INI_TYPE_BOOLEAN $INI_TYPE_TEXT
		     $MATCH_ID);
use LNXHC::Misc qw($opt_debug unquote validate_id);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&ini_check_keywords &ini_format_multi &ini_format_single
		    &ini_get_assign_value &ini_get_assign_value_list
		    &ini_get_bool_expr_list &ini_get_multi_ids
		    &ini_get_text_value &ini_print &ini_read_file);


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
# _parse_section_heading(filename, line, heading)
#
# Parse HEADING as a section heading and return the normalized section
# name.
#
sub _parse_section_heading($$$)
{
	my ($filename, $line, $heading) = @_;
	my @argv;
	my $id;

	# Ensure correct brackets
	if (!($heading =~ /\]/)) {
		die("$filename:$line: missing closing bracket\n");
	}
	if (!($heading =~ s/\]\s*$//)) {
		die("$filename:$line: unexpected characters after closing ".
		    "bracket\n");
	}

	# Remove leading and trailing whitespaces
	$heading =~ s/^\s*//;
	$heading =~ s/\s*$//;
	# Split identifiers
	@argv = split(/\s+/, $heading);
	foreach $id (@argv) {
		validate_id("section heading", $id, undef, "$filename:$line");
	}
	# Check for section name
	if (scalar(@argv) == 0) {
		die("$filename:$line: missing section name\n");
	}

	return join(" ", @argv);
}

#
# _parse_text_line(filename, line, text)
#
# Parse TEXT as a text expression and return the corresponding line data set.
#
sub _parse_text_line($$$)
{
	my ($filename, $line, $text) = @_;

	return [ $line, $text ];
}

#
# _parse_boolean_expression(filename, line, expr)
#
# Parse EXPR as a boolean expression line and return the corresponding line
# data set.
#
sub _parse_boolean_expression($$$)
{
	my ($filename, $line, $expr) = @_;

	return [ $line, $expr ];
}

#
# _parse_assignment(filename, line, key, value)
#
# Parse KEY and VALUE as an assignment line and return the corresponding
# line data set.
#
sub _parse_assignment($$$$)
{
	my ($filename, $line, $key, $value) = @_;

	validate_id("keyword", $key, undef, "$filename:$line");
	$value = unquote($value, "$filename:$line");

	return [ $line, $key, $value ];
}

#
# _parse_statement(filename, line, statement)
#
# Parse STATEMENT as a statement line and return the corresponding line data
# set.
#
sub _parse_statement($$$)
{
	my ($filename, $line, $statement) = @_;

	validate_id("keyword", $statement, undef, "$filename:$line");

	return [ $line, $statement, undef ];
}

#
# ini_print(ini)
#
# Print the INI data returned by parse_ini_file.
#
sub ini_print($)
{
	my ($ini) = @_;
	my ($filename, $sections) = @$ini;
	my $id;

	print("$filename:\n[\n");
	foreach $id (sort(keys(%{$sections}))) {
		my $section = $sections->{$id};
		my ($line, $type, $contents) = @$section;
		my $content;
		my $c = "";

		print("  '$id' -> [ line=$line, type=$type, content=[\n");
		$c = "";
		foreach $content (@$contents) {
			if ($type == $INI_TYPE_ASSIGNMENT) {
				my ($l, $key, $value) = @$content;

				print("$c      [ line=$l, key='$key', ".
				      "value='$value' ]");
			} elsif ($type == $INI_TYPE_BOOLEAN) {
				my ($l, $expr) = @$content;

				print("$c      [ line=$l, expr='$expr' ]");
			} elsif ($type == $INI_TYPE_TEXT) {
				my ($l, $text) = @$content;

				print("$c      [ line=$l, text='$text' ]");
			}
			$c = ",\n";
		}
		print("\n    ]\n");
	}
	print("]\n");
}

#
# _add_section(filename, line, sections, id, types)
#
# Add a new section to the SECTIONS hash. Return the newly added section.
#
sub _add_section($$$$$)
{
	my ($filename, $line, $sections, $id, $types) = @_;
	my $type;
	my $section;

	# Check for duplicate section definition
	$section = $sections->{$id};
	if (defined($section)) {
		my $old_line = $section->[$INI_SEC_LINE];

		die("$filename:$line: section '$id' already defined in line ".
		    "$old_line\n");
	}
	# Check if a type was defined for the full ID
	$type = $types->{$id};
	if (!defined($type)) {
		# Check if a type was defined for the section name alone
		my $name = $id;

		$name =~ s/\s.*$//;
		$type = $types->{$name};
	}
	# Use default if no type is specified
	if (!defined($type)) {
		$type = $INI_TYPE_ASSIGNMENT;
	}
	# Create section
	$section = [ $., $type, [] ];
	# Add to hash
	$sections->{$id} = $section;

	return $section;
}

#
# ini_read_file(filename[, format])
#
# Read file FILENAME and parse its contents as an ini file. Returns the RESULT
# as specified below. FORMAT specifies the format against which the ini file
# is checked.
#
# format: [ types, mandatory, strict ]
# types: \{ section name => section type }
# mandatory: \{ section name => is_mandatory }
# is_mandatory: non-zero for sections which are mandatory
# strict: if non-zero, abort if a section heading is specified which is not
#         defined in types
#
# ini: [ filename, sections ]
# sections: section name + ids -> section
# section: [ line, type, content ]
# content = [ content1, content2, ... ]
# content assignment: [ line, key, value ]
# content boolean: [ line, expression ]
# content text: [ line, text ]
#
sub ini_read_file($;$)
{
	my ($filename, $format) = @_;
	my $types;
	my $mandatory;
	my $strict;
	my %sections;
	my $ini = [ $filename, \%sections ];
	my $section;
	my $content;
	my $handle;

	# Apply format if specified
	if (defined($format)) {
		($types, $mandatory, $strict) = @$format;
	}
	$types = {} if (!defined($types));
	$mandatory = {} if (!defined($mandatory));
	$strict = 0 if (!defined($strict));
	# Read file
	open($handle, "<", $filename)
		or die("could not open '$filename': $!\n");
	while (<$handle>) {
		chomp();

		# Section heading
		if (/^\s*\[(.*)$/) {
			my $id = _parse_section_heading($filename, $., $1);
			my $main_id = $id;

			# If specified, check for valid section name
			$main_id =~ s/\s.*$//;
			if ($strict && !defined($types->{$main_id})) {
				die("$filename:$.: unknown section '$id' ".
				    "specified\n");
			}
			# Add a new section
			$section = _add_section($filename, $., \%sections,
					       $id, $types);
			$content = $section->[$INI_SEC_CONTENT];
			next;
		}
		# Handle line in text section
		if (defined($section) &&
		    (@$section[$INI_SEC_TYPE] == $INI_TYPE_TEXT)) {
			push(@$content, _parse_text_line($filename, $., $_));
			next;
		}
		# Skip empty lines
		next if (/^\s*$/);
		# Skip comment lines
		next if /^\s*#/;
		# Add a section with empty name for lines appearing before the
		# first section heading
		if (!defined($section)) {
			$section = _add_section($filename, $., \%sections,
					       "", $types);
			$content = $section->[$INI_SEC_CONTENT];
		}
		# Handle boolean expressions
		if (@$section[$INI_SEC_TYPE] == $INI_TYPE_BOOLEAN) {
			push(@$content,
			     _parse_boolean_expression($filename, $., $_));
			next;
		}
		# Handle keyword-value assignments
		if (/^\s*([^\s=]+)\s*=(.*)$/) {
			my ($key, $value) = ($1, $2);

			push(@$content,
			     _parse_assignment($filename, $., $key, $value));
			next;
		}
		# Handle statements
		if (/^\s*(\S+)\s*$/) {
			my $statement = $1;

			push(@$content,
			     _parse_statement($filename, $., $statement));
			next;
		}
		# Unhandled line
		die("$filename:$.: unrecognized line format: '$_'\n");
	}
	close($handle);
	# Check for mandatory sections
	foreach my $id (keys(%{$mandatory})) {
		if (!$sections{$id}) {
			die("$filename: missing mandatory section '$id'\n");
		}
	}
	if ($opt_debug > 2) {
		ini_print($ini);
	}

	return $ini;
}

#
# ini_check_keywords(ini, sec_id, mandatory)
#
# Check if section SEC_ID in file INI contains mandatory keywords specified
# in hash referenced by MANDATORY. Abort if a mandatory keyword is missing or
# if a keyword is found which is not specified.
#
sub ini_check_keywords($$%)
{
	my ($ini, $sec_id, $mandatory) = @_;
	my ($filename, $sections) = @$ini;
	my $section = $sections->{$sec_id};
	my $contents;
	my %found;

	# Check for missing section
	if (!defined($section)) {
		die("$filename: missing section '$sec_id'\n");
	}
	$contents = $section->[$INI_SEC_CONTENT];

	# Check section for unexpected keywords
	foreach my $content (@$contents) {
		my ($line, $keyword) = @$content;
		my $is_mandatory = $mandatory->{$keyword};

		if (!defined($is_mandatory)) {
			die("$filename:$line: unexpected keyword '$keyword' ".
			    "found in section '$sec_id'\n");
		}
		$found{$keyword} = 1;
	}

	# Check section for missing keywords
	foreach my $keyword (keys(%{$mandatory})) {
		my $is_mandatory = $mandatory->{$keyword};

		if ($is_mandatory && !$found{$keyword}) {
			my $sec_line = $section->[$INI_SEC_LINE];

			die("$filename:$sec_line: missing keyword '$keyword' ".
			    "in section '$sec_id'\n");
		}

	}
}

#
# ini_get_assign_value_list(ini, name, search_key[, mandatory, single])
#
# Search section NAME of file INI for assignments of keyword SEARCH_KEY and
# return a list of occurrences and the line number in which it occurred.
# If MANDATORY is non-zero, abort if no keyword assignment was found.
# If SINGLE is non-zero, abort if more than one assignment was found ofr
# this keyword.
#
# result: ( data1, data2, ... )
# data: [ line, value ]
#
sub ini_get_assign_value_list($$$;$$)
{
	my ($ini, $name, $search_key, $mandatory, $single) = @_;
	my ($filename, $sections) = @$ini;
	my $section;
	my $line;
	my $contents;
	my $content;
	my @result;

	# Get section
	$section = $sections->{$name};
	if (!defined($section)) {
		if ($mandatory) {
			die("$filename: missing mandatory section '$name'\n");
		}
		return @result;
	}
	($line, undef, $contents) = @$section;
	# Search for keyword assignment
	foreach $content (@$contents) {
		my ($key_line, $key, $value) = @$content;

		if ($key eq $search_key) {
			push(@result, [ $key_line, $value ]);
			if ($single && (scalar(@result) > 1)) {
				die("$filename:$key_line: keyword '$key' ".
				    "specified more than once\n");
			}
		}
	}
	# Keyword was not found
	if ((scalar(@result) == 0) && $mandatory) {
		die("$filename:$line: missing mandatory keyword ".
		    "'$search_key' in section '$name'\n");
	}

	return @result;
}

#
# ini_get_assign_value(ini, name, search_key[, mandatory])
#
# Search section NAME of file INI for an assignment of keyword SEARCH_KEY and
# return the value and the line number in which it occurred.
# If MANDATORY is non-zero, abort if no keyword assignment was found.
# Abort if more than one assignment was found for this keyword.
#
# Get a single value for keyword assignment for keyword SEARCH_KEY in section
# NAME of ini file INI. Return a single values. If MANDATORY is non-zero,
# abort if either section or keyword are not found, return empty list
# otherwise. Abort if keyword is specified more than once.
#
sub ini_get_assign_value($$$;$)
{
	my ($ini, $name, $search_key, $mandatory) = @_;
	my @values;

	@values = ini_get_assign_value_list($ini, $name, $search_key,
					    $mandatory, 1);

	return undef if (!defined($values[0]));
	return @{$values[0]};
}

#
# ini_get_bool_expr_list(ini, name[, mandatory])
#
# Get boolean expressions in section NAME of ini file INI. Return a list of
# expressions and line numbers in which the expressions were found. If
# MANDATORY is non-zero, abort if section was not found, return empty list
# otherwise.
#
sub ini_get_bool_expr_list($$$;$)
{
	my ($ini, $name, $mandatory) = @_;
	my ($filename, $sections) = @$ini;
	my $section;
	my $line;
	my $contents;
	my $content;
	my @result;

	# Get section
	$section = $sections->{$name};
	if (!defined($section)) {
		if ($mandatory) {
			die("$filename: missing mandatory section '$name'\n");
		}
		return @result;
	}
	($line, undef, $contents) = @$section;

	# Collect expression
	foreach $content (@$contents) {
		my ($line, $expr) = @$content;
		push(@result, [ $line, $expr ]);
	}

	return @result;
}

#
# ini_get_text_value(ini, name[, mandatory])
#
# Get text from section NAME in file INI. If mandatory is non-zero, abort if
# the section was not found, otherwise return undef.
#
sub ini_get_text_value($$;$)
{
	my ($ini, $name, $mandatory) = @_;
	my ($filename, $sections) = @$ini;
	my $section;
	my $contents;
	my $content;
	my $result = "";

	# Get section
	$section = $sections->{$name};
	if (!defined($section)) {
		if ($mandatory) {
			die("$filename: missing mandatory section '$name'\n");
		}
		return undef;
	}
	$contents = $section->[$INI_SEC_CONTENT];
	# Search for assignment
	foreach $content (@$contents) {
		$result .= $content->[$INI_TEXT_TEXT]."\n";
	}

	return $result;
}

#
# ini_format_single(text)
#
# Apply single-line formatting to TEXT.
#
sub ini_format_single($)
{
	my ($text) = @_;

	# Change newline characters into spaces
	$text =~ s/\n/ /g;
	# Change multiple whitespace characters into a single space
	$text =~ s/\s+/ /g;
	# Remove leading whitespaces
	$text =~ s/^\s*//g;
	# Remove trailing whitespaces
	$text =~ s/\s*$//g;

	return $text;
}

#
# ini_format_multi(text)
#
# Apply multi-line formatting to TEXT:
# - merge lines into paragraphs
# - remove leading and trailing empty lines
# - remove double empty lines
#
sub ini_format_multi($)
{
	my ($text) = @_;
	my $STATE_NONE		= 0;
	my $STATE_PARAGRAPH	= 1;
	my $STATE_LIST		= 2;
	my $STATE_PRE		= 3;
	my $EVENT_EMPTY		= 0;
	my $EVENT_PRE		= 1;
	my $EVENT_LIST		= 2;
	my $EVENT_TEXT		= 3;
	my $state;
	my $new_state;
	my $current;
	my $result = "";
	my $event;

	$state = $STATE_NONE;
	foreach my $line (split(/\n/, $text)) {
		# Normalize empty lines
		$line =~ s/^\s*$//;

		# Determine event and follow-on state
		if ($line eq "") {
			$event = $EVENT_EMPTY;
			$new_state = $STATE_NONE;
		} elsif ($line =~ /^#/) {
			$event = $EVENT_PRE;
			$new_state = $STATE_PRE;
		} elsif ($line =~ /^\s/) {
			$event = $EVENT_LIST;
			$new_state = $STATE_LIST;
		} else {
			$event = $EVENT_TEXT;
			if ($state == $STATE_LIST) {
				$new_state = $STATE_LIST;
			} else {
				$new_state = $STATE_PARAGRAPH;
			}
		}

		# Perform state dependent action
		if ($state == $STATE_NONE) {
			$current = $line;
		} elsif ($state == $STATE_PARAGRAPH) {
			if ($event == $EVENT_TEXT) {
				$current .= " ".$line;
			} else {
				$result .= ini_format_single($current)."\n";
				$current = $line;
			}
		} elsif ($state == $STATE_LIST) {
			if ($event == $EVENT_TEXT) {
				$current .= " ".$line;
			} else {
				$result .= " ".ini_format_single($current).
					   "\n";
				$current = $line;
			}
		} elsif ($state == $STATE_PRE) {
			$result .= $current."\n";
			$current = $line;
		}
		$state = $new_state;
	}
	# Add remaining text
	if ($state == $STATE_PARAGRAPH) {
		$result .= ini_format_single($current)."\n";
	} elsif ($state == $STATE_LIST) {
		$result .= " ".ini_format_single($current)."\n";
	} elsif ($state == $STATE_PRE) {
		$result .= $current."\n";
	}

	return $result;
}

# ini_get_multi_ids(ini, primary_id)
#
# Search INI file for sections whose ID starts with primary_id. Return a
# mapping of secondary IDs to full IDs. Abort if there are more than two IDs.
#
sub ini_get_multi_ids($$)
{
	my ($ini, $primary_id) = @_;
	my ($filename, $sections) = @$ini;
	my $sec_id;
	my %result;

	foreach $sec_id (keys(%{$sections})) {
		my $section = $sections->{$sec_id};
		my $id;
		my $rest;

		# Skip sections which do not match primary_id
		next if ($sec_id !~ /^$primary_id(.*)/);
		$rest = $1;

		# Abort if identifier is missing
		if ($rest eq "") {
			die("$filename:".$section->[$INI_SEC_LINE].": ".
			    "Missing identifier for $primary_id section!\n");
		}

		# Skip sections with IDs starting with primary_id
		next if ($rest !~ /^\s/);

		# Abort on invalid identifiers
		$rest =~ /^\s*($MATCH_ID)(.*)$/;
		($id, $rest) = ($1, $2);
		if ($rest ne "") {
			die("$filename:".$section->[$INI_SEC_LINE].": ".
			    "Unexpected trailing characters: '$rest'!\n");
		}
		$result{$id} = $sec_id;
	}

	return \%result;
}


#
# Code entry
#

# Indicate successful module initialization
1;
