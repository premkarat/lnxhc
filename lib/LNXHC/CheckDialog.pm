#
# LNXHC::CheckDialog.pm
#   Linux Health Checker dialog for creating new health checks
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

package LNXHC::CheckDialog;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catfile);
use File::Basename qw(basename dirname);


#
# Local imports
#
use LNXHC::Consts qw($CHECK_DEF_FILENAME $CHECK_DESC_FILENAME
		     $CHECK_DIALOG_FILENAME $CHECK_DIALOG_TEMPL_BASH_CHECK
		     $CHECK_DIALOG_TEMPL_PYTHON_CHECK
		     $CHECK_DIALOG_TEMPL_C_CHECK $CHECK_DIALOG_TEMPL_C_MAKEFILE
		     $CHECK_DIALOG_TEMPL_PERL_CHECK $CHECK_EX_FILENAME);
use LNXHC::Misc qw(print_indented quiet_retrieve quiet_store quote read_file
		   resolve_entities validate_duration_nodie validate_id
		   write_file);
use LNXHC::UData qw(udata_get_path);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&check_dialog);


#
# Constants
#

# Dialog states
my $_STATE_FIRST		= 0;
my $_STATE_LANGUAGE		= 0;
my $_STATE_AUTHOR		= 1;
my $_STATE_COMPONENT		= 2;
my $_STATE_RUN_REGULARLY	= 3;
my $_STATE_RUN_REPEAT_INTERVAL	= 4;
my $_STATE_MULTIHOST		= 5;
my $_STATE_MULTITIME		= 6;
my $_STATE_EXTRA_FILES		= 7;
my $_STATE_WORKS_NOCONFIG	= 8;
my $_STATE_WORKS_DEFAULT_SOFT	= 9;
my $_STATE_FIRST_SI_ID		= 10;
my $_STATE_SI_TYPE		= 11;
my $_STATE_SI_FILE_FILENAME	= 12;
my $_STATE_SI_USER_ID		= 13;
my $_STATE_SI_PROG_CMDLINE	= 14;
my $_STATE_SI_REC_START		= 15;
my $_STATE_SI_REC_STOP		= 16;
my $_STATE_SI_REC_DURATION	= 17;
my $_STATE_SI_REF_CHECK_ID	= 18;
my $_STATE_SI_REF_SI_ID		= 19;
my $_STATE_SI_ID		= 20;
my $_STATE_FIRST_EX_ID		= 21;
my $_STATE_EX_SEVERITY		= 22;
my $_STATE_EX_ID		= 23;
my $_STATE_PARAM_ID		= 24;
my $_STATE_PARAM_DEFAULT	= 25;
my $_STATE_END			= 26;

# Dialog data
my $_DATA_STATE			= 0;
my $_DATA_LANGUAGE		= 1;
my $_DATA_AUTHOR		= 2;
my $_DATA_COMPONENT		= 3;
my $_DATA_RUN_REGULARLY		= 4;
my $_DATA_RUN_REPEAT_INTERVAL	= 5;
my $_DATA_MULTIHOST		= 6;
my $_DATA_MULTITIME		= 7;
my $_DATA_EXTRA_FILES		= 8;
my $_DATA_WORKS_NOCONFIG	= 9;
my $_DATA_WORKS_DEFAULT_SOFT	= 10;
my $_DATA_SI_ID			= 11;
my $_DATA_SI_TYPE		= 12;
my $_DATA_SI_FILE_FILENAME	= 13;
my $_DATA_SI_USER_ID		= 14;
my $_DATA_SI_PROG_CMDLINE	= 15;
my $_DATA_SI_REC_START		= 16;
my $_DATA_SI_REC_STOP		= 17;
my $_DATA_SI_REC_DURATION	= 18;
my $_DATA_SI_REF_CHECK_ID	= 19;
my $_DATA_SI_REF_SI_ID		= 20;
my $_DATA_EX_ID			= 21;
my $_DATA_EX_SEVERITY		= 22;
my $_DATA_PARAM_ID		= 23;
my $_DATA_PARAM_DEFAULT		= 24;

# Data index per State
my %_DATA_INDEX = (
	$_STATE_LANGUAGE		=> $_DATA_LANGUAGE,
	$_STATE_AUTHOR			=> $_DATA_AUTHOR,
	$_STATE_COMPONENT		=> $_DATA_COMPONENT,
	$_STATE_RUN_REGULARLY		=> $_DATA_RUN_REGULARLY,
	$_STATE_RUN_REPEAT_INTERVAL	=> $_DATA_RUN_REPEAT_INTERVAL,
	$_STATE_MULTIHOST		=> $_DATA_MULTIHOST,
	$_STATE_MULTITIME		=> $_DATA_MULTITIME,
	$_STATE_EXTRA_FILES		=> $_DATA_EXTRA_FILES,
	$_STATE_WORKS_NOCONFIG		=> $_DATA_WORKS_NOCONFIG,
	$_STATE_WORKS_DEFAULT_SOFT	=> $_DATA_WORKS_DEFAULT_SOFT,
	$_STATE_FIRST_SI_ID		=> $_DATA_SI_ID,
	$_STATE_SI_ID			=> $_DATA_SI_ID,
	$_STATE_SI_TYPE			=> $_DATA_SI_TYPE,
	$_STATE_SI_FILE_FILENAME	=> $_DATA_SI_FILE_FILENAME,
	$_STATE_SI_USER_ID		=> $_DATA_SI_USER_ID,
	$_STATE_SI_PROG_CMDLINE		=> $_DATA_SI_PROG_CMDLINE,
	$_STATE_SI_REC_START		=> $_DATA_SI_REC_START,
	$_STATE_SI_REC_STOP		=> $_DATA_SI_REC_STOP,
	$_STATE_SI_REC_DURATION		=> $_DATA_SI_REC_DURATION,
	$_STATE_SI_REF_CHECK_ID		=> $_DATA_SI_REF_CHECK_ID,
	$_STATE_SI_REF_SI_ID		=> $_DATA_SI_REF_SI_ID,
	$_STATE_FIRST_EX_ID		=> $_DATA_EX_ID,
	$_STATE_EX_SEVERITY		=> $_DATA_EX_SEVERITY,
	$_STATE_EX_ID			=> $_DATA_EX_ID,
	$_STATE_PARAM_ID		=> $_DATA_PARAM_ID,
	$_STATE_PARAM_DEFAULT		=> $_DATA_PARAM_DEFAULT,
);

# Non-zero if data item is an array
my %_DATA_IS_ARRAY = (
	$_DATA_EXTRA_FILES		=> 1,
	$_DATA_EX_ID			=> 1,
	$_DATA_EX_SEVERITY		=> 1,
	$_DATA_PARAM_ID			=> 1,
	$_DATA_PARAM_DEFAULT		=> 1,
	$_DATA_SI_ID			=> 1,
	$_DATA_SI_TYPE			=> 1,
	$_DATA_SI_FILE_FILENAME		=> 1,
	$_DATA_SI_USER_ID		=> 1,
	$_DATA_SI_PROG_CMDLINE		=> 1,
	$_DATA_SI_REC_START		=> 1,
	$_DATA_SI_REC_STOP		=> 1,
	$_DATA_SI_REC_DURATION		=> 1,
	$_DATA_SI_REF_CHECK_ID		=> 1,
	$_DATA_SI_REF_SI_ID		=> 1,
);

# Non-zero if user can specify an "add" operation for this data item
my %_DATA_CAN_ADD = (
	$_DATA_EXTRA_FILES		=> 1,
	$_DATA_EX_ID			=> 1,
	$_DATA_PARAM_ID			=> 1,
	$_DATA_SI_ID			=> 1,
);

# Non-zero if array requires at least one item
my %_DATA_NON_EMPTY_ARRAY = (
	$_DATA_EX_ID			=> 1,
	$_DATA_SI_ID			=> 1,
);

# Programming languages
my @_LANGUAGES = (
	"Perl",
	"Python",
	"Bash",
	"C",
	"Other scripting language",
	"Other compiled language",
);

# Programming languages constants - must match array order
my $_LANG_PERL		= 1;
my $_LANG_PYTHON	= 2;
my $_LANG_BASH		= 3;
my $_LANG_C		= 4;
my $_LANG_OTHER_SCRIPT	= 5;
my $_LANG_OTHER_COMP	= 6;

# Severities
my @_SEVERITIES = (
	"Low",
	"Medium",
	"High",
);

# Sysinfo item types
my @_SI_TYPES = (
	"File",
	"Program",
	"Record",
	"Reference",
	"External",
);

# Sysinfo item type constants - must match array order
my $_SI_TYPE_FILE	= 1;
my $_SI_TYPE_PROG	= 2;
my $_SI_TYPE_REC	= 3;
my $_SI_TYPE_REF	= 4;
my $_SI_TYPE_EXT	= 5;

# Acceptable input types for a dialog data field

# Accept yes and no
my $_INPUT_TYPE_YES_NO			= 0;

# Accept decimal number, parameters: [ min, max ]
my $_INPUT_TYPE_NUMBER			= 1;

# Accept check ID
my $_INPUT_TYPE_CHECK_ID		= 2;

# Accept sysinfo ID
my $_INPUT_TYPE_SI_ID			= 3;

# Accept exception ID
my $_INPUT_TYPE_EX_ID			= 4;

# Accept parameter ID
my $_INPUT_TYPE_PARAM_ID		= 5;

# Accept any string except an empty string
my $_INPUT_TYPE_STRING_NONEMPTY	= 6;

# Accept any string including the empty string
my $_INPUT_TYPE_STRING			= 7;

# Accept a valid duration string
my $_INPUT_TYPE_DURATION		= 8;

# Acceptable input types per data index
my %_INPUT_TYPE = (
	$_DATA_LANGUAGE			=> [ $_INPUT_TYPE_NUMBER, 1,
					     scalar(@_LANGUAGES) ],
	$_DATA_AUTHOR			=> [ $_INPUT_TYPE_STRING_NONEMPTY ],
	$_DATA_COMPONENT		=> [ $_INPUT_TYPE_STRING_NONEMPTY ],
	$_DATA_RUN_REGULARLY		=> [ $_INPUT_TYPE_YES_NO ],
	$_DATA_RUN_REPEAT_INTERVAL	=> [ $_INPUT_TYPE_DURATION ],
	$_DATA_MULTIHOST		=> [ $_INPUT_TYPE_YES_NO ],
	$_DATA_MULTITIME		=> [ $_INPUT_TYPE_YES_NO ],
	$_DATA_EXTRA_FILES		=> [ $_INPUT_TYPE_STRING_NONEMPTY ],
	$_DATA_WORKS_NOCONFIG		=> [ $_INPUT_TYPE_YES_NO ],
	$_DATA_WORKS_DEFAULT_SOFT	=> [ $_INPUT_TYPE_YES_NO ],
	$_DATA_SI_ID			=> [ $_INPUT_TYPE_SI_ID ],
	$_DATA_SI_TYPE			=> [ $_INPUT_TYPE_NUMBER, 1,
					     scalar(@_SI_TYPES) ],
	$_DATA_SI_FILE_FILENAME		=> [ $_INPUT_TYPE_STRING_NONEMPTY ],
	$_DATA_SI_USER_ID		=> [ $_INPUT_TYPE_STRING ],
	$_DATA_SI_PROG_CMDLINE		=> [ $_INPUT_TYPE_STRING_NONEMPTY ],
	$_DATA_SI_REC_START		=> [ $_INPUT_TYPE_STRING_NONEMPTY ],
	$_DATA_SI_REC_STOP		=> [ $_INPUT_TYPE_STRING_NONEMPTY ],
	$_DATA_SI_REC_DURATION		=> [ $_INPUT_TYPE_DURATION ],
	$_DATA_SI_REF_CHECK_ID		=> [ $_INPUT_TYPE_CHECK_ID ],
	$_DATA_SI_REF_SI_ID		=> [ $_INPUT_TYPE_SI_ID ],
	$_DATA_EX_ID			=> [ $_INPUT_TYPE_EX_ID ],
	$_DATA_EX_SEVERITY		=> [ $_INPUT_TYPE_NUMBER, 1,
					     scalar(@_SEVERITIES) ],
	$_DATA_PARAM_ID			=> [ $_INPUT_TYPE_PARAM_ID ],
	$_DATA_PARAM_DEFAULT		=> [ $_INPUT_TYPE_STRING ],
);

# Non-zero if empty input is acceptable
my %_DATA_INPUT_TYPE_EMPTY = (
	$_DATA_PARAM_DEFAULT		=> 1,
);

# List data indices which are associated with a main index
my %_DATA_ASSOC = (
	$_DATA_EX_ID			=> [ $_DATA_EX_SEVERITY ],
	$_DATA_PARAM_ID			=> [ $_DATA_PARAM_DEFAULT ],
	$_DATA_SI_ID			=>
		[ $_DATA_SI_TYPE, $_DATA_SI_FILE_FILENAME,
		  $_DATA_SI_PROG_CMDLINE, $_DATA_SI_REC_START,
		  $_DATA_SI_REC_STOP, $_DATA_SI_REC_DURATION,
		  $_DATA_SI_REF_CHECK_ID, $_DATA_SI_REF_SI_ID,
		  $_DATA_SI_USER_ID ],
);

# Dialog data names
my %_DATA_NAMES = (
	$_DATA_LANGUAGE			=> "Programming language",
	$_DATA_AUTHOR			=> "Check author",
	$_DATA_COMPONENT		=> "Checked component",
	$_DATA_RUN_REGULARLY		=> "Run regularly",
	$_DATA_RUN_REPEAT_INTERVAL	=> "Repeat interval",
	$_DATA_MULTIHOST		=> "Multiple host data",
	$_DATA_MULTITIME		=> "Multiple time data",
	$_DATA_EXTRA_FILES		=> "Extra files",
	$_DATA_WORKS_NOCONFIG		=> "Works without configuration",
	$_DATA_WORKS_DEFAULT_SOFT	=> "Works with default software",
	$_DATA_SI_ID			=> "Sysinfo item ID",
	$_DATA_SI_TYPE			=> "    Type",
	$_DATA_SI_FILE_FILENAME		=> "    Filename",
	$_DATA_SI_USER_ID		=> "    User ID",
	$_DATA_SI_PROG_CMDLINE		=> "    Command line",
	$_DATA_SI_REC_START		=> "    Start command line",
	$_DATA_SI_REC_STOP		=> "    Stop command line",
	$_DATA_SI_REC_DURATION		=> "    Duration",
	$_DATA_SI_REF_CHECK_ID		=> "    Reference check name",
	$_DATA_SI_REF_SI_ID		=> "    Reference sysinfo ID",
	$_DATA_EX_ID			=> "Exception ID",
	$_DATA_EX_SEVERITY		=> "    Severity",
	$_DATA_PARAM_ID			=> "Parameter ID",
	$_DATA_PARAM_DEFAULT		=> "    Default value",
);

# Maximum width in characters needed to fit any dialog data name
my $_DATA_NAME_MAX_WIDTH	= 30;

# Dialog data defaults
my %_DATA_DEFAULTS = (
	$_DATA_RUN_REGULARLY		=> "n",
	$_DATA_MULTIHOST		=> "n",
	$_DATA_MULTITIME		=> "n",
	$_DATA_WORKS_NOCONFIG		=> "y",
	$_DATA_WORKS_DEFAULT_SOFT	=> "y",
	$_DATA_SI_USER_ID		=> "",
	$_DATA_PARAM_DEFAULT		=> "",
);

# Data list items
my $_DATA_LIST_NUMBER		= 0;
my $_DATA_LIST_STATE		= 1;
my $_DATA_LIST_DATA_INDEX	= 2;
my $_DATA_LIST_INDEX		= 3;
my $_DATA_LIST_VALUE		= 4;

# Sections
my $_SECTION_GENERIC		= 0;
my $_SECTION_ACTIVATION		= 1;
my $_SECTION_SYSINFO		= 2;
my $_SECTION_EXCEPTIONS		= 3;
my $_SECTION_PARAMETERS		= 4;

# Section per State
my %_SECTION = (
	$_STATE_LANGUAGE		=> $_SECTION_GENERIC,
	$_STATE_AUTHOR			=> $_SECTION_GENERIC,
	$_STATE_COMPONENT		=> $_SECTION_GENERIC,
	$_STATE_RUN_REGULARLY		=> $_SECTION_GENERIC,
	$_STATE_RUN_REPEAT_INTERVAL	=> $_SECTION_GENERIC,
	$_STATE_MULTIHOST		=> $_SECTION_GENERIC,
	$_STATE_MULTITIME		=> $_SECTION_GENERIC,
	$_STATE_EXTRA_FILES		=> $_SECTION_GENERIC,
	$_STATE_WORKS_NOCONFIG		=> $_SECTION_ACTIVATION,
	$_STATE_WORKS_DEFAULT_SOFT	=> $_SECTION_ACTIVATION,
	$_STATE_FIRST_SI_ID		=> $_SECTION_SYSINFO,
	$_STATE_SI_ID			=> $_SECTION_SYSINFO,
	$_STATE_SI_TYPE			=> $_SECTION_SYSINFO,
	$_STATE_SI_FILE_FILENAME	=> $_SECTION_SYSINFO,
	$_STATE_SI_USER_ID		=> $_SECTION_SYSINFO,
	$_STATE_SI_PROG_CMDLINE		=> $_SECTION_SYSINFO,
	$_STATE_SI_REC_START		=> $_SECTION_SYSINFO,
	$_STATE_SI_REC_STOP		=> $_SECTION_SYSINFO,
	$_STATE_SI_REC_DURATION		=> $_SECTION_SYSINFO,
	$_STATE_SI_REF_CHECK_ID		=> $_SECTION_SYSINFO,
	$_STATE_SI_REF_SI_ID		=> $_SECTION_SYSINFO,
	$_STATE_FIRST_EX_ID		=> $_SECTION_EXCEPTIONS,
	$_STATE_EX_SEVERITY		=> $_SECTION_EXCEPTIONS,
	$_STATE_EX_ID			=> $_SECTION_EXCEPTIONS,
	$_STATE_PARAM_ID		=> $_SECTION_PARAMETERS,
	$_STATE_PARAM_DEFAULT		=> $_SECTION_PARAMETERS,
);

# Dialog operations
my $_DIA_OP_EDIT	= 1;
my $_DIA_OP_ADD		= 2;
my $_DIA_OP_DEL		= 3;

# Finalization operations
my $_FIN_OP_EDIT	= 0;
my $_FIN_OP_ADD		= 1;
my $_FIN_OP_DEL		= 2;
my $_FIN_OP_END		= 3;


#
# Global variables
#

# Last section heading printed
my $_current_section;

# Dialog state and data
my $_data;


#
# Sub-routines
#

#
# _dump_data(data)
#
# Dump current dialog data in raw format.
#
sub _dump_data($)
{
	my ($data) = @_;
	my $entry;

	print("[\n");
	foreach $entry (@$data) {
		my $sub_entry;

		print("  ");
		if (!defined($entry)) {
			print("<undefined>,\n");
			next;
		}
		if (ref($entry) ne "ARRAY") {
			print("\"$entry\",\n");
			next;
		}
			print("[ ");
		foreach $sub_entry (@$entry) {
			if (!defined($sub_entry)) {
				print("<undefined>, ");
				next;
			}
			print("\"$sub_entry\", ");
		}
		print("],\n");
	}
	print("]\n");
}

#
# _get_empty_data()
#
# Return a reference to an empty dialog data set.
#
sub _get_empty_data()
{
	my @data;
	my $state;

	# Initialize state
	$data[$_DATA_STATE] = $_STATE_FIRST;

	# Initialize array
	for ($state = $_STATE_FIRST; $state != $_STATE_END; $state++) {
		my $data_index = $_DATA_INDEX{$state};

		if ($_DATA_IS_ARRAY{$data_index}) {
			$data[$data_index] = [];
		}
	}

	return \@data;
}

#
# _get_data_copy(data)
#
# Return a copy of dialog data DATA.
#
sub _get_data_copy($)
{
	my ($data) = @_;
	my @result;
	my $entry;

	foreach $entry (@$data) {
		if (ref($entry) eq "ARRAY") {
			push(@result, [ @$entry ]);
		} else {
			push(@result, $entry);
		}
	}

	return \@result;
}

#
# _delete_saved_data()
#
# Delete saved dialog data.
#
sub _delete_saved_data()
{
	my $filename = udata_get_path($CHECK_DIALOG_FILENAME);

	# Do nothing if file does not exist
	if (! -e $filename) {
		return;
	}

	unlink($filename) or
		warn("could not remove dialog data file '$filename'\n");
}

#
# _write_saved_data()
#
# Write current dialog data to file.
#
sub _write_saved_data()
{
	my $filename = udata_get_path($CHECK_DIALOG_FILENAME);

	quiet_store($_data, $filename) or
		warn("Could not write dialog data file '$filename'\n");
}

#
# _read_saved_data()
#
# Read saved dialog data and return reference if data was available, undef
# otherwise.
#
sub _read_saved_data()
{
	my $filename = udata_get_path($CHECK_DIALOG_FILENAME);

	# Do nothing if no data file exists
	if (! -e $filename) {
		return undef;
	}

	return quiet_retrieve($filename);
}

#
# _interrupt()
#
# Handle dialog interruption.
#
sub _interrupt()
{
	if ($_data->[$_DATA_STATE] != $_STATE_FIRST) {
		print("\nDialog was interrupted, saving data.\n");
		_write_saved_data();
		print("Done\n");
	} else {
		print("\nDialog was interrupted\n");
	}

	exit(1);
}

#
# _print_intro()
#
# Print introduction for health check creation dialog dialog.
#
sub _print_intro()
{
	print(<<EOF);
Health check creation dialog
============================
This dialog supports the creation of a new health check. It queries the user
for answers to several questions. Once the dialog is finished, a directory
containing a skeleton of files will be created.

Some questions provide default answers which are shown in square brackets
("[]"). These answers are used if an empty value is entered. All answers can
be modified at the end of the dialog.

The following input options are available to control the dialog:
  ?.......: show help text for the current dialog question
  CTRL-C..: save data and end dialog, restart the dialog to continue

EOF
}

#
# _print_finalize()
#
# Print text to announce finalization step.
#
sub _print_finalize()
{
	print(<<EOF);
Finalization dialog
===================
Below is the summary of information entered for the new check. You can
adjust each data item or finalize the check.

EOF
}

#
# _get_section_text(section)
#
# Return text for SECTION.
#
sub _get_section_text($)
{
	my ($section) = @_;

	if ($section == $_SECTION_GENERIC) {
		return <<EOF;
Generic health check characteristics
====================================
EOF
	} elsif ($section == $_SECTION_ACTIVATION) {
		return <<EOF;
Initial activation state
========================
The initial activation state specifies if a health check should run in
the default profile. The following questions attempt to identify the
correct state for your check.
EOF
	} elsif ($section == $_SECTION_SYSINFO) {
		return <<EOF;
System information
==================
A health check requires data about a system to perform its check function.
This data must not be collected by the check program itself. Instead you need
to specify this data as so-called "sysinfo items" so that the lnxhc framework
can obtain the data and provide it to the check program.
EOF
	} elsif ($section == $_SECTION_EXCEPTIONS) {
		return <<EOF;
Exceptions
==========
A problem that can be reported by a health check is called an "exception".
Each health check must be able to report at least one exception.
EOF
	} elsif ($section == $_SECTION_PARAMETERS) {
		return <<EOF;
Health check parameters
=======================
Parameters are untyped string values which can be modified by users and
which are passed to the health check program. Parameters can be used to
allow users to customize some aspects of health check execution.
EOF
	}

	return "";
}

#
# _print_section_heading(state)
#
# Print section heading for STATE if necessary.
#
sub _print_section_heading($)
{
	my ($state) = @_;
	my $section = $_SECTION{$state};

	# Check if section is available
	if (!defined($section)) {
		return;
	}
	# Check if section has changed
	if (defined($_current_section) && $_current_section == $section) {
		return;
	}

	$_current_section = $section;
	print(_get_section_text($section)."\n");
}

#
# _get_question_text(state)
#
# Return question text for STATE.
#
sub _get_question_text($)
{
	my ($state) = @_;

	if ($state == $_STATE_LANGUAGE) {
		return <<EOF;
What programming language will be used to implement the check program?
(&lang_range;)&default;

&lang_list;
EOF
	} elsif ($state == $_STATE_AUTHOR) {
		return <<EOF;
Enter the name and e-mail address of the check author:&default;
EOF
	} elsif ($state == $_STATE_COMPONENT) {
		return <<EOF;
Enter the name of the component that is being checked:&default;
EOF
	} elsif ($state == $_STATE_RUN_REGULARLY) {
		return <<EOF;
Should the check run regularly? (y/n)&default;
EOF
	} elsif ($state == $_STATE_RUN_REPEAT_INTERVAL) {
		return <<EOF;
At what intervals should the check run:&default;
EOF
	} elsif ($state == $_STATE_MULTIHOST) {
		return <<EOF;
Does the check require data from multiple hosts at once? (y/n)&default;
EOF
	} elsif ($state == $_STATE_MULTITIME) {
		return <<EOF;
Does the check require data from multiple points in time at once (y/n)&default;
EOF
	} elsif ($state == $_STATE_EXTRA_FILES) {
		return <<EOF;
List all paths to additional files provided by the check relative to the check
directory (empty input to continue):&default;
EOF
	} elsif ($state == $_STATE_WORKS_NOCONFIG) {
		return <<EOF;
Does the check produce meaningful results with default parameters on a standard
Linux installation? (y/n)&default;
EOF
	} elsif ($state == $_STATE_WORKS_DEFAULT_SOFT) {
		return <<EOF;
Is the component being checked part of a standard Linux installation? (y/n)&default;
EOF
	} elsif ($state == $_STATE_FIRST_SI_ID) {
		return <<EOF;
Enter the ID of a sysinfo item that is required by the check program:&default;
EOF
	} elsif ($state == $_STATE_SI_TYPE) {
		return <<EOF;
What is the type of sysinfo item '&si_id;'?&default;

&si_type_list;
EOF
	} elsif ($state == $_STATE_SI_FILE_FILENAME) {
		return <<EOF;
Specify the absolute path to the file to be read for file sysinfo item
'&si_id;':&default;
EOF
	} elsif ($state == $_STATE_SI_USER_ID) {
		return <<EOF;
Specify the user-ID that has access permissions to obtain the data of sysinfo
item '&si_id;' (empty ID if no special permissions are required):&default;
EOF
	} elsif ($state == $_STATE_SI_PROG_CMDLINE) {
		return <<EOF;
Specify the command line of the program to be run for program sysinfo item
'&si_id;', including path information and parameters:&default;
EOF
	} elsif ($state == $_STATE_SI_REC_START) {
		return <<EOF;
Specify the command line of the start program to be run for record sysinfo item
'&si_id;', including path information and parameters:&default;
EOF
	} elsif ($state == $_STATE_SI_REC_STOP) {
		return <<EOF;
Specify the command line of the stop program to be run for record sysinfo item
'&si_id;', including path information and parameters:&default;
EOF
	} elsif ($state == $_STATE_SI_REC_DURATION) {
		return <<EOF;
Specify the time interval after which the stop program of record sysinfo item
'&si_id;' should be called:&default;
EOF
	} elsif ($state == $_STATE_SI_REF_CHECK_ID) {
		return <<EOF;
Specify the check name of the check referenced by sysinfo item
'&si_id;':&default;
EOF
	} elsif ($state == $_STATE_SI_REF_SI_ID) {
		return <<EOF;
Specify the sysinfo ID of check '&ref_check_id;' that is referenced by sysinfo
item '&si_id;':&default;
EOF
	} elsif ($state == $_STATE_SI_ID) {
		return <<EOF;
Enter the ID of an additional sysinfo item that is needed by check (empty ID
to continue):&default;
EOF
	} elsif ($state == $_STATE_FIRST_EX_ID) {
		return <<EOF;
Enter the ID of an exception that the check can report:&default;
EOF
	} elsif ($state == $_STATE_EX_SEVERITY) {
		return <<EOF;
What is the severity of exception '&ex_id;'? (&sev_range;)&default;

&sev_list;
EOF
	} elsif ($state == $_STATE_EX_ID) {
		return <<EOF;
Enter the ID of an additional exception that the check can report (empty ID to
continue):&default;
EOF
	} elsif ($state == $_STATE_PARAM_ID) {
		return <<EOF;
Enter the ID of a health check parameter (empty ID to continue):&default;
EOF
	} elsif ($state == $_STATE_PARAM_DEFAULT) {
		return <<EOF;
Enter a default value for parameter '&param_id;':&default;
EOF
	}

	return "";
}

#
# _get_question_edit_text(state, edit)
#
# Return question text for STATE in edit mode.
#
sub _get_question_edit_text($$)
{
	my ($state, $edit) = @_;

	if ($state == $_STATE_EXTRA_FILES) {
		if ($edit == $_DIA_OP_EDIT) {
			return <<EOF;
Enter the modified path:&default;
EOF
		} elsif ($edit == $_DIA_OP_ADD) {
			return <<EOF;
Enter the path to an additional file (empty input to skip):
EOF
		}
	} elsif ($state == $_STATE_FIRST_EX_ID ||
		 $state == $_STATE_EX_ID) {
		if ($edit == $_DIA_OP_EDIT) {
			return <<EOF;
Enter the modified exception ID:&default;
EOF
		} elsif ($edit == $_DIA_OP_ADD) {
			return <<EOF;
Enter the ID of an additional exception that the check can report (empty ID to
skip):&default;
EOF
		}
	} elsif ($state == $_STATE_SI_ID ||
		 $state == $_STATE_FIRST_SI_ID) {
		if ($edit == $_DIA_OP_EDIT) {
			return <<EOF;
Enter the modified sysinfo ID:&default;
EOF
		} elsif ($edit == $_DIA_OP_ADD) {
			return <<EOF;
Enter the ID of an additional sysinfo item that is required by the check
program (empty ID to skip):
EOF
		}
	} elsif ($state == $_STATE_PARAM_ID) {
		if ($edit == $_DIA_OP_EDIT) {
			return <<EOF;
Enter the modified parameter ID:&default;
EOF
		} elsif ($edit == $_DIA_OP_ADD) {
			return <<EOF;
Enter the ID of an additional health check parameter (empty ID to skip):
EOF
		}
	}

	return undef;
}

#
# _get_default(data, data_index, edit, index)
#
# Return default value for dialog data DATA_INDEX and edit mode EDIT.
#
sub _get_default($$$$)
{
	my ($data, $data_index, $edit, $index) = @_;
	my $default;

	# Check for pre-specified values in edit mode
	if ($edit) {
		if ($_DATA_IS_ARRAY{$data_index}) {
			$default = $data->[$data_index]->[$index];
		} else {
			$default = $data->[$data_index];
		}
	}

	# Fall back to defined defaults
	if (!defined($default)) {
		$default = $_DATA_DEFAULTS{$data_index};
	}

	return $default;
}

#
# _print_question(data, state, edit[, index])
#
# Print question for STATE. If EDIT is non-zero, print a variation of the
# question to indicate that an existing entry is modified. In case of
# a question with multiple answers, INDEX specifies the entry to be modified.
#
sub _print_question($$$;$)
{
	my ($data, $state, $edit, $index) = @_;
	my $data_index = $_DATA_INDEX{$state};
	my $text;
	my %entities;
	my $default;

	# Get edit text
	if ($edit) {
		$text = _get_question_edit_text($state, $edit);
	}

	# Get base text
	if (!defined($text)) {
		$text = _get_question_text($state);
	}

	# Provide entity values
	if ($state == $_STATE_LANGUAGE) {
		my $lang_list = "";
		my $i;

		# Get &lang_list;
		for ($i = 0; $i < scalar(@_LANGUAGES); $i++) {
			$lang_list .= sprintf("%2d..%s\n", $i + 1,
					      $_LANGUAGES[$i]);
		}
		$entities{"lang_list"} = $lang_list;
		# Get &lang_range;
		$entities{"lang_range"} = "1..".scalar(@_LANGUAGES);
	} elsif ($state == $_STATE_EX_SEVERITY) {
		my $sev_list = "";
		my $i;

		# Get &sev_list;
		for ($i = 0; $i < scalar(@_SEVERITIES); $i++) {
			$sev_list .= sprintf("%2d.. %s\n", $i + 1,
					     $_SEVERITIES[$i]);
		}
		$entities{"sev_list"} = $sev_list;
		# Get &sev_range;
		$entities{"sev_range"} = "1..".scalar(@_SEVERITIES);
		# Get &ex_id;
		if (!$edit) {
			$index = scalar(@{$data->[$_DATA_EX_ID]}) - 1;
		}
		$entities{"ex_id"} = $data->[$_DATA_EX_ID]->[$index];
	} elsif ($state == $_STATE_PARAM_DEFAULT) {
		# Get &param_id;
		if (!$edit) {
			$index = scalar(@{$data->[$_DATA_PARAM_ID]}) - 1;
		}
		$entities{"param_id"} = $data->[$_DATA_PARAM_ID]->[$index];
	} elsif ($state == $_STATE_SI_TYPE) {
		my $type_list = "";
		my $i;

		# Get &si_id;
		if (!$edit) {
			$index = scalar(@{$data->[$_DATA_SI_ID]}) - 1;
		}
		$entities{"si_id"} = $data->[$_DATA_SI_ID]->[$index];
		# Get &si_type_list;
		for ($i = 0; $i < scalar(@_SI_TYPES); $i++) {
			$type_list .= sprintf("%2d.. %s\n", $i + 1,
					     $_SI_TYPES[$i]);
		}
		$entities{"si_type_list"} = $type_list;
	} elsif ($state == $_STATE_SI_FILE_FILENAME ||
		 $state == $_STATE_SI_USER_ID ||
		 $state == $_STATE_SI_PROG_CMDLINE ||
		 $state == $_STATE_SI_REC_START ||
		 $state == $_STATE_SI_REC_STOP ||
		 $state == $_STATE_SI_REC_DURATION ||
		 $state == $_STATE_SI_REF_CHECK_ID) {
		# Get &si_id;
		if (!$edit) {
			$index = scalar(@{$data->[$_DATA_SI_ID]}) - 1;
		}
		$entities{"si_id"} = $data->[$_DATA_SI_ID]->[$index];
	} elsif ( $state == $_STATE_SI_REF_SI_ID) {
		# Get &si_id;
		if (!$edit) {
			$index = scalar(@{$data->[$_DATA_SI_ID]}) - 1;
		}
		$entities{"si_id"} = $data->[$_DATA_SI_ID]->[$index];
		# Get &ref_check_id;
		$entities{"ref_check_id"} =
			$data->[$_DATA_SI_REF_CHECK_ID]->[$index];
	}

	# Add default to entities
	$default = _get_default($data, $data_index, $edit, $index);
	if (defined($default)) {
		$default = " [$default]";
	} else {
		$default = "";
	}
	$entities{"default"} = $default;

	# Resolve entities
	$text = resolve_entities($text, \%entities);

	print_indented($text, 0);
}

#
# _ask_question(data, state, edit[, index])
#
# Ask question associated with STATE. If EDIT is non-zero, the question is
# asked in the edit context and INDEX indicates the index into the answer list
# for questions which accept multiple answers.
#
sub _ask_question($$$;$)
{
	my ($data, $state, $edit, $index) = @_;
	my $input;

	_print_question($data, $state, $edit, $index);

	$input = <STDIN>;

	# Check for EOF (e.g. CTRL-D)
	if (!defined($input)) {
		_interrupt();
	}

	# Normalize input
	chomp($input);

	return $input;
}

#
# _get_help_text(state)
#
# Return help text for specified state.
#
sub _get_help_text($)
{
	my ($state) = @_;
	my $data_index;

	$data_index = $_DATA_INDEX{$state};

	if ($data_index == $_DATA_LANGUAGE) {
		return <<EOF;
Depending on the programming language to be used for this health check,
the dialog will provide a skeleton check program and build environment.
When choosing a language you should take into account if a standard system
includes the required run-time environment.
EOF
	} elsif ($data_index == $_DATA_AUTHOR) {
		return <<EOF;
The author address is required to allow users to provide feedback on
health checks.
EOF
	} elsif ($data_index == $_DATA_COMPONENT) {
		return <<EOF;
The component name is used to allow users to search checks which work on the
same component. For this reason it is recommended to use an identical component
name for each check that checks the same component.
EOF
	} elsif ($data_index == $_DATA_RUN_REGULARLY) {
		return <<EOF;
If the aspect that is being checked changes regularly the health check
should run regularly.
EOF
	} elsif ($data_index == $_DATA_RUN_REPEAT_INTERVAL) {
		return <<EOF;
The health check interval should match the frequency at which the checked
aspect can change. Interval specifications may consist of one or more numbers
followed by a time unit:
- d for days
- h for fours
- m for minutes
- s or no unit for seconds

Example:
1d 12h 30m 10s
EOF
	} elsif ($data_index == $_DATA_MULTIHOST) {
		return <<EOF;
Some checks require data from multiple hosts at once to identify a specific
problem. Choose "y" here if you intend to implement such a check.
EOF
	} elsif ($data_index == $_DATA_MULTITIME) {
		return <<EOF;
Some checks require data from multiple points in time at once to identify
a specific problem. Choose "y" here if you intend to implement such a
check.
EOF
	} elsif ($data_index == $_DATA_EXTRA_FILES) {
		return <<EOF;
The lnxhc tool needs to be aware of which extra files are required by a
health check so that it knows which files to install. Provide filenames
relative to the health check directory.
EOF
	} elsif ($data_index == $_DATA_WORKS_NOCONFIG) {
		return <<EOF;
If a health check requires that users need to set health check parameters
before it can produce meaningful results, it should be inactive by default.
EOF
	} elsif ($data_index == $_DATA_WORKS_DEFAULT_SOFT) {
		return <<EOF;
If a health check applies to a component which is not pat of a default
Linux installation, it should be inactive by default.
EOF
	} elsif ($data_index == $_DATA_SI_ID) {
		return <<EOF;
A sysinfo ID is a string of 3 to 40 characters length which may consist
of lowercase-letters a-z, digits 0-9 and the underscore sign ("_").
EOF
	} elsif ($data_index == $_DATA_SI_TYPE) {
		return <<EOF;
The sysinfo item type determines what type of action needs to be performed by
the lnxhc framework to obtain the requested system information.

- File: read a file
- Program: run a program and store its output
- Record: run a start program, wait a duration, run a stop program and store
its output
- Reference: use another check's sysinfo definition
- External: this data cannot be obtained actively - it must be imported by
the user.
EOF
	} elsif ($data_index == $_DATA_SI_FILE_FILENAME) {
		return <<EOF;
Provide absolute paths to the requested files.
EOF
	} elsif ($data_index == $_DATA_SI_USER_ID) {
		return <<EOF;
If a requested system information item cannot be obtained by a normal user,
specify the user-ID of a user which has the corresponding access rights.
The information will then be obtained as that user.
EOF
	} elsif ($data_index == $_DATA_SI_PROG_CMDLINE ||
		 $data_index == $_DATA_SI_REC_START ||
		 $data_index == $_DATA_SI_REC_STOP) {
		return <<EOF;
Provide the complete command line including path and parameters. If no path
is specified, the system search path is used to locate the command. If an
absolute path is specified, that path is used. To specify a path relative to
the check directory, the path has to start with \$LNXHC_CHECK_DIR. Such a path
must not contain '..'.
EOF
	} elsif ($data_index == $_DATA_SI_REC_DURATION) {
		return <<EOF;
Specify the time between calls to the start and stop programs respectively.
Duration specifications may consist of one or more numbers followed by a time
unit:
- d for days
- h for fours
- m for minutes
- s or no unit for seconds

Example:
1d 12h 30m 10s
EOF
	} elsif ($data_index == $_DATA_SI_REF_CHECK_ID) {
		return <<EOF;
A check name is a string of 3 to 40 characters length which may consist
of lowercase-letters a-z, digits 0-9 and the underscore sign ("_").
EOF
	} elsif ($data_index == $_DATA_SI_REF_SI_ID) {
		return <<EOF;
A sysinfo ID is a string of 3 to 40 characters length which may consist
of lowercase-letters a-z, digits 0-9 and the underscore sign ("_").
EOF
	} elsif ($data_index == $_DATA_EX_ID) {
		return <<EOF;
An exception ID is a string of 3 to 40 characters length which may consist
of lowercase-letters a-z, digits 0-9 and the underscore sign ("_").
EOF
	} elsif ($data_index == $_DATA_EX_SEVERITY) {
		return <<EOF;
The severity of an exception indicates how critical the identified problem
is. Aspects to consider when choosing a severity:
 - chance for an outage
 - significance of a performance impact
 - immediateness of impact on the system
EOF
	} elsif ($data_index == $_DATA_PARAM_ID) {
		return <<EOF;
A parameter ID is a string of 3 to 40 characters length which may consist
of lowercase-letters a-z, digits 0-9 and the underscore sign ("_").
EOF
	} elsif ($data_index == $_DATA_PARAM_DEFAULT) {
		return <<EOF;
In the absence of a default value, an empty string will be used if no other
value is specified by the user.
EOF
	}

	return "No help text available.\n"
}

#
# _print_help_text(state)
#
# Print help text for the specified STATE.
#
sub _print_help_text($)
{
	my ($state) = @_;
	my $text;

	$text = _get_help_text($state);

	print("\nHelp:\n");
	print_indented($text, 2);
	print("\n");
}

#
# _check_number(input, from, to, default)
#
# Check if INPUT is a number between FROM and TO. If true, return
# (undef, number). Otherwise return (msg, undef), where MSG is an error
# message indicating why the input does not match the required input pattern.
#
sub _check_number($$$;$)
{
	my ($input, $from, $to, $default) = @_;
	my $number;
	my $msg;

	# Check for empty input
	if (defined($default) && ($input =~ /^\s*$/)) {
		return (undef, $default);
	}

	# Check for valid digits
	if (!($input =~ /^\s*(\d+)\s*$/)) {
		goto err;
	}

	$number = int($1);

	# Check range
	if ($number < $from || $number > $to) {
		goto err;
	}

	return (undef, $number);

err:
	if ($input =~ /^\s*$/) {
		$msg = "input cannot be empty";
	} else {
		$msg = "unrecognized input '$input'";
	}
	$msg .= ": please enter a number between $from and $to";

	return ($msg, undef);
}

#
# _check_yes_no(input, default)
#
# Check if INPUT is y/yes or n/no. If true, return (undef, n) for no and
# (undef, y) for yes. Otherwise return (msg, undef), where MSG is an error
# message indicating why the input does not match the required input pattern.
# If DEFAULT is specified and INPUT is empty, use this value instead.
#
sub _check_yes_no($;$)
{
	my ($input, $default) = @_;
	my $msg;

	# Use default if necessary
	if (($input =~ /^\s*$/) && defined($default)) {
		$input = $default;
	}

	# Check for yes and no
	if ($input =~ /^\s*y(es)?\s*$/) {
		return (undef, "y");
	} elsif ($input =~ /^\s*no?\s*$/) {
		return (undef, "n");
	}

	# Provide descriptive error message
	if ($input =~ /^\s*$/) {
		$msg = "input cannot be empty";
	} else {
		$msg = "unrecognized input '$input'";
	}
	$msg .= ": please enter 'y' for yes or 'n' for no";

	return ($msg, undef);
}

#
# _validate_unique(data, data_index, input, index, type_name)
#
# Check if an array entry is unique. Return an error message if it is not
# unique.
#
sub _validate_unique($$$$$)
{
	my ($data, $data_index, $input, $index, $type_name) = @_;
	my $array = $data->[$data_index];
	my $i;

	for ($i = 0; $i < scalar(@{$array}); $i++) {
		my $entry = $array->[$i];

		# Don't compare with oneself (e.g. edit operation with
		# empty input)
		if (defined($index) && $i == $index) {
			next;
		}

		# Check if this entry already exists
		if ($entry eq $input) {
			return "$type_name '$input': already specified";
		}
	}

	return undef;
}

#
# _check_input(data, input, state[, edit, index])
#
# Check INPUT for correctness. If input is correct, return (undef, input),
# otherwise (msg, undef), where MSG is an error message describing why the
# input is not correct.
#
sub _check_input($$$;$$)
{
	my ($data, $input, $state, $edit, $index) = @_;
	my $data_index = $_DATA_INDEX{$state};
	my $default;
	my $msg;
	my $type;
	my @params;

	# Abort add operation on empty input
	if (defined($edit) && $edit == $_DIA_OP_ADD && ($input =~ /^\s*$/) && (
		$state == $_STATE_EXTRA_FILES ||
		$state == $_STATE_FIRST_SI_ID ||
		$state == $_STATE_FIRST_EX_ID ||
		$state == $_STATE_PARAM_ID)) {
		return (undef, "");
	}

	# Determine possible default values
	$default = _get_default($data, $data_index, $edit, $index);

	# Apply default if available
	if (defined($default) && ($input =~ /^\s*$/)) {
		$input = $default;
	}

	# Filter out "end of list/input" markers
	if (($input =~ /^\s*$/) &&
	    ($state == $_STATE_EXTRA_FILES ||
	     $state == $_STATE_SI_ID ||
	     $state == $_STATE_EX_ID ||
	     $state == $_STATE_PARAM_ID)) {
		return (undef, "");
	}

	# Determine acceptable input types for this question
	($type, @params) = @{$_INPUT_TYPE{$data_index}};

	# Perform type specific checking
	if ($type == $_INPUT_TYPE_YES_NO) {
		($msg, $input) = _check_yes_no($input);
	} elsif ($type == $_INPUT_TYPE_NUMBER) {
		my ($min, $max) = @params;

		($msg, $input) = _check_number($input, $min, $max);
	} elsif ($type == $_INPUT_TYPE_CHECK_ID) {
		$msg = validate_id("check name", $input, 1);
		if (!defined($msg)) {
			$msg = _validate_unique($data, $data_index, $input,
						$index, "check name");
		}
	} elsif ($type == $_INPUT_TYPE_SI_ID) {
		$msg = validate_id("sysinfo ID", $input, 1);
		if (!defined($msg)) {
			$msg = _validate_unique($data, $data_index, $input,
						$index, "sysinfo ID");
		}
	} elsif ($type == $_INPUT_TYPE_EX_ID) {
		$msg = validate_id("exception ID", $input, 1);
		if (!defined($msg)) {
			$msg = _validate_unique($data, $data_index, $input,
						$index, "exception ID");
		}
	} elsif ($type == $_INPUT_TYPE_PARAM_ID) {
		$msg = validate_id("parameter ID", $input, 1);
		if (!defined($msg)) {
			$msg = _validate_unique($data, $data_index, $input,
						$index, "parameter ID");
		}
	} elsif ($type == $_INPUT_TYPE_STRING_NONEMPTY) {
		if ($input =~ /^\s*$/) {
			$msg = "input cannot be empty";
		}
	} elsif ($type == $_INPUT_TYPE_DURATION) {
		$msg = validate_duration_nodie($input);
	}

	# Normalize error message
	if (defined($msg)) {
		chomp($msg);
	}

	return ($msg, $input);
}

sub _get_parent_index($);

#
# _add_data(data, input, state)
#
# Add dialog data according to input.
#
sub _add_data($$$)
{
	my ($data, $input, $state) = @_;
	my $data_index = $_DATA_INDEX{$state};
	my ($type) = @{$_INPUT_TYPE{$data_index}};

	# Some dialog questions use empty input as end of input marker.
	# Delete input in these cases
	if ($input eq "" && $type != $_INPUT_TYPE_STRING) {
		$input = undef;
	}

	if ($_DATA_IS_ARRAY{$data_index}) {
		if (defined($input)) {
			my $parent_index = _get_parent_index($data_index);

			if (defined($parent_index)) {
				# Add item to the same index as the parent index
				my $i = scalar(@{$data->[$parent_index]}) - 1;
				$data->[$data_index]->[$i] = $input;
			} else {
				# Add item to the end of this array
				push(@{$data->[$data_index]}, $input);
			}
		}
	} else {
		# Store input
		$data->[$data_index] = $input;
	}
}

#
# _edit_data(data, input, state, edit, index)
#
# Edit dialog data according to input.
#
sub _edit_data($$$$$)
{
	my ($data, $input, $state, $edit, $index) = @_;
	my $data_index = $_DATA_INDEX{$state};
	my $old_value;
	my ($type) = @{$_INPUT_TYPE{$data_index}};

	# Abort add operation on empty input
	if ($edit == $_DIA_OP_ADD && ($input eq "") && (
		$state == $_STATE_EXTRA_FILES ||
		$state == $_STATE_FIRST_SI_ID ||
		$state == $_STATE_FIRST_EX_ID ||
		$state == $_STATE_PARAM_ID)) {
		return;
	}

	# Some dialog questions use empty input as "not specified" markers.
	# Delete input in these cases
	if ($input eq "" && $type != $_INPUT_TYPE_STRING) {
		$input = undef;
	}

	if ($_DATA_IS_ARRAY{$data_index}) {
		# Overwrite entry in list
		$old_value = $data->[$data_index]->[$index];
		$data->[$data_index]->[$index] = $input;
	} else {
		# Store input
		$old_value = $data->[$data_index];
		$data->[$data_index] = $input;
	}

	# Special handling
	if (($state == $_STATE_RUN_REGULARLY) &&
	     defined($input) && $input eq "n") {
		$data->[$_DATA_RUN_REPEAT_INTERVAL] = undef;
	} elsif ($state == $_STATE_SI_TYPE && defined($input) &&
		 defined($old_value) && $input ne $old_value) {
		# Clear type-specific data as well
		$data->[$_DATA_SI_FILE_FILENAME]->[$index] = undef;
		$data->[$_DATA_SI_USER_ID]->[$index] = undef;
		$data->[$_DATA_SI_PROG_CMDLINE]->[$index] = undef;
		$data->[$_DATA_SI_REC_START]->[$index] = undef;
		$data->[$_DATA_SI_REC_STOP]->[$index] = undef;
		$data->[$_DATA_SI_REC_DURATION]->[$index] = undef;
		$data->[$_DATA_SI_REF_CHECK_ID]->[$index] = undef;
		$data->[$_DATA_SI_REF_SI_ID]->[$index] = undef;
	}
}

#
# _delete_data(data, state, index)
#
# Delete an entry from a dialog question that accepts a list of entries.
# Return zero if deletion was successful, non-zero otherwise.
#
sub _delete_data($$$)
{
	my ($data, $state, $index) = @_;
	my $data_index = $_DATA_INDEX{$state};
	my $i;

	if ($state == $_STATE_EXTRA_FILES ||
	    $state == $_STATE_FIRST_SI_ID ||
	    $state == $_STATE_SI_ID ||
	    $state == $_STATE_FIRST_EX_ID ||
	    $state == $_STATE_EX_ID ||
	    $state == $_STATE_PARAM_ID) {
		my @assoc = ($data_index);
		my $num = scalar(@{$data->[$data_index]});

		# Check if we're deleting last element
		if ($num == 0) {
			print("Error: cannot delete an entry from an empty ".
			      "list!\n");
			return 1;
		} elsif ($num == 1) {
			if ($_DATA_NON_EMPTY_ARRAY{$data_index}) {
				print("Error: cannot delete last entry of ".
				      "this list\n");
				return 1;
			}
		}

		# Add associated arrays
		if (defined($_DATA_ASSOC{$data_index})) {
			push(@assoc, @{$_DATA_ASSOC{$data_index}} );
		}

		# Remove item in all associated array
		foreach $i (@assoc) {
			if ($index <= scalar(@{$data->[$i]})) {
				splice(@{$data->[$i]}, $index, 1);
			}
		}
	} elsif ($state == $_STATE_SI_USER_ID) {
		# Clear user ID entry
		$data->[$data_index]->[$index] = "";
	} elsif ($state == $_STATE_PARAM_DEFAULT) {
		# Clear parameter default
		$data->[$data_index]->[$index] = "";
		print("Entry has been cleared.\n");
		return 0;
	} else {
		print("Error: this entry cannot be deleted!\n");
		return 1;
	}

	print("Entry has been deleted.\n");

	return 0;
}

#
# _get_next_dialog_state(input, state)
#
# Get next state in dialog according to INPUT.
#
sub _get_next_dialog_state($$)
{
	my ($input, $state) = @_;
	my $new_state = $state + 1;

	if ($state == $_STATE_RUN_REGULARLY) {
		# If y, ask for repeat interval
		if ($input eq "y") {
			$new_state = $_STATE_RUN_REPEAT_INTERVAL;
		} else {
			$new_state = $_STATE_MULTIHOST;
		}
	} elsif ($state == $_STATE_EXTRA_FILES) {
		# If non-empty, repeat extra files dialog
		if ($input eq "") {
			$new_state = $_STATE_WORKS_NOCONFIG;
		} else {
			$new_state = $_STATE_EXTRA_FILES;
		}
	} elsif ($state == $_STATE_SI_TYPE) {
		# Branch dialog depending on sysinfo item type
		if ($input == $_SI_TYPE_FILE) {
			$new_state = $_STATE_SI_FILE_FILENAME;
		} elsif ($input == $_SI_TYPE_PROG) {
			$new_state = $_STATE_SI_PROG_CMDLINE;
		} elsif ($input == $_SI_TYPE_REC) {
			$new_state = $_STATE_SI_REC_START;
		} elsif ($input == $_SI_TYPE_REF) {
			$new_state = $_STATE_SI_REF_CHECK_ID;
		} elsif ($input == $_SI_TYPE_EXT) {
			$new_state = $_STATE_SI_ID;
		}
	} elsif ($state == $_STATE_SI_FILE_FILENAME ||
		 $state == $_STATE_SI_PROG_CMDLINE ||
		 $state == $_STATE_SI_REC_DURATION) {
		$new_state = $_STATE_SI_USER_ID;
	} elsif ($state == $_STATE_SI_USER_ID ||
		 $state == $_STATE_SI_REF_SI_ID) {
		$new_state = $_STATE_SI_ID;
		$new_state = $_STATE_SI_ID;
	} elsif ($state == $_STATE_SI_ID) {
		# If non-empty, repeat sysinfo dialog
		if ($input eq "") {
			$new_state = $_STATE_FIRST_EX_ID;
		} else {
			$new_state = $_STATE_SI_TYPE;
		}
	} elsif ($state == $_STATE_EX_ID) {
		# If non-empty, repeat exception dialog
		if ($input eq "") {
			$new_state = $_STATE_PARAM_ID;
		} else {
			$new_state = $_STATE_EX_SEVERITY;
		}
	} elsif ($state == $_STATE_PARAM_ID) {
		# If non-empty, perform parameter dialog
		if ($input eq "") {
			$new_state = $_STATE_END;
		} else {
			$new_state = $_STATE_PARAM_DEFAULT;
		}
	} elsif ($state == $_STATE_PARAM_DEFAULT) {
		$new_state = $_STATE_PARAM_ID;
	}

	return $new_state;
}

#
# _get_next_edit_state(input, state, end_state, edit)
#
# Get next state in edit dialog according to INPUT.
#
sub _get_next_edit_state($$$$)
{
	my ($input, $state, $end_state, $edit) = @_;
	my $new_state = $_STATE_END;

	# Abort add operation on empty input
	if ($edit == $_DIA_OP_ADD && $input eq "" && (
		$state == $_STATE_EXTRA_FILES ||
		$state == $_STATE_FIRST_SI_ID ||
		$state == $_STATE_FIRST_EX_ID ||
		$state == $_STATE_PARAM_ID)) {
		return $_STATE_END;
	}

	if (defined($end_state)) {
		$new_state = _get_next_dialog_state($input, $state);
		if ($new_state == $end_state) {
			$new_state = $_STATE_END;
		}
	}

	return $new_state;
}

#
# _process_input(data, input, state, end_state, edit, index)
#
# Check input and store data. Return next state.
#
sub _process_input($$$;$$$)
{
	my ($data, $input, $state, $end_state, $edit, $index) = @_;
	my $msg;

	# Check for help request
	if ($input =~ /^\s*\?\s*$/) {
		_print_help_text($state);
		return $state;
	}

	# Check input for correctness
	($msg, $input) = _check_input($data, $input, $state, $edit, $index);
	if (defined($msg)) {
		print("Error: $msg!\n\n");
		return $state;
	}

	# Store input and determine follow-on state
	if ($edit) {
		_edit_data($data, $input, $state, $edit, $index);
		$state = _get_next_edit_state($input, $state, $end_state,
					      $edit);
	} else {
		_add_data($data, $input, $state);
		$state = _get_next_dialog_state($input, $state);
	}

	return $state;
}

#
# _dialog(data, [start_state, end_state, edit, index])
#
# Perform dialog starting at STATE. If EDIT is non-zero, do not complete full
# dialog but only an edit action for the specified state. During an edit
# operation, INDEX indicates the item index to be edited in case of answers
# which accept a list of items as answer.
#
sub _dialog($;$$$$)
{
	my ($data, $start_state, $end_state, $edit, $index) = @_;
	my $state = $start_state;

	# Continue where we left off
	if (!defined($state)) {
		$state = $data->[$_DATA_STATE];
	}

	while ($state != $_STATE_END) {
		my $input;

		if (!$edit) {
			# Update section heading
			_print_section_heading($state);
		}

		# Ask current question
		$input = _ask_question($data, $state, $edit, $index);

		# Add new line if input was not empty
		if (!($input =~ /^\s*$/)) {
			print("\n");
		}

		# Process input
		$state = _process_input($data, $input, $state, $end_state,
					$edit, $index);

		if (!$edit) {
			$data->[$_DATA_STATE] = $state;
		}
	}
}

#
# _get_formatted_data(value, data_index)
#
# Return a formatted version of the dialog data entered for DATA_INDEX.
#
sub _get_formatted_data($$)
{
	my ($value, $data_index) = @_;
	my ($type) = @{$_INPUT_TYPE{$data_index}};

	if (!defined($value)) {
		return undef;
	}

	if ($type ==$_INPUT_TYPE_YES_NO) {
		if ($value eq "y") {
			return "Yes";
		} else {
			return "No";
		}
	} elsif ($type == $_INPUT_TYPE_NUMBER) {
		my $array;

		if ($data_index == $_DATA_LANGUAGE) {
			$array = \@_LANGUAGES;
		} elsif ($data_index == $_DATA_SI_TYPE) {
			$array = \@_SI_TYPES;
		} elsif ($data_index == $_DATA_EX_SEVERITY) {
			$array = \@_SEVERITIES;
		} else {
			return $value;
		}

		return $array->[$value - 1];
	}

	return $value;
}

#
# _get_state_from_data_index(data_index)
#
# Return state corresponding to DATA_INDEX.
#
sub _get_state_from_data_index($)
{
	my ($data_index) = @_;
	my $state;

	foreach $state (sort {$a <=> $b} keys(%_DATA_INDEX)) {
		if ($_DATA_INDEX{$state} == $data_index) {
			return $state;
		}
	}
}

#
# _get_data_list(data)
#
# Return a list in which each item corresponds to a line of dialog DATA.
#
# result: (item1, item2, ...)
# item: [ number, state, data_index, index, value ]
#
sub _get_data_list($)
{
	my ($data) = @_;
	my $state;
	my $last_state = $data->[$_DATA_STATE];
	my @result;
	my $number = 1;

	# Add an entry for each dialog data type
	for ($state = $_STATE_FIRST; $state != $last_state; $state++) {
		my $data_index = $_DATA_INDEX{$state};

		if ($state == $_STATE_EXTRA_FILES ||
		    $state == $_STATE_FIRST_SI_ID ||
		    $state == $_STATE_FIRST_EX_ID ||
		    $state == $_STATE_PARAM_ID) {
			my @array_index = ( $data_index );
			my $assoc = $_DATA_ASSOC{$data_index};
			my $num = scalar(@{$data->[$data_index]});
			my $i;
			my $idx;

			# Add a single entry if list is empty
			if (scalar(@{$data->[$data_index]}) == 0) {
				push(@result,
					[ $number++, $state, $data_index, 0,
					  "<empty list>" ]);
				next;
			}

			# Traverse all associated arrays for this entry
			if (defined($assoc)) {
				push(@array_index, @{$assoc});
			}

			# For each item in the main array
			for ($i = 0; $i < $num; $i++) {
				# Get the item for all associated arrays
				foreach $idx (@array_index) {
					my $value = $data->[$idx]->[$i];
					my $s;

					if (!defined($value)) {
						next;
					}

					$s = _get_state_from_data_index($idx);

					push(@result, [ $number++, $s, $idx, $i,
						_get_formatted_data(
							$value, $idx) ]);
				}
			}

		} elsif ($state == $_STATE_LANGUAGE ||
			 $state == $_STATE_AUTHOR ||
			 $state == $_STATE_COMPONENT ||
			 $state == $_STATE_RUN_REGULARLY ||
			 $state == $_STATE_RUN_REPEAT_INTERVAL ||
			 $state == $_STATE_MULTIHOST ||
			 $state == $_STATE_MULTITIME ||
			 $state == $_STATE_WORKS_NOCONFIG ||
			 $state == $_STATE_WORKS_DEFAULT_SOFT) {
			my $value = $data->[$data_index];

			# Simply add the value
			if (defined($value)) {
				push(@result,
					[ $number++, $state, $data_index, undef,
					  _get_formatted_data($value,
							      $data_index) ]);
			}
		} elsif ($state == $_STATE_EX_ID ||
			 $state == $_STATE_EX_SEVERITY ||
			 $state == $_STATE_PARAM_DEFAULT ||
			 $state == $_STATE_SI_ID ||
			 $state == $_STATE_SI_TYPE ||
			 $state == $_STATE_SI_FILE_FILENAME ||
			 $state == $_STATE_SI_USER_ID ||
			 $state == $_STATE_SI_PROG_CMDLINE ||
			 $state == $_STATE_SI_REC_START ||
			 $state == $_STATE_SI_REC_STOP ||
			 $state == $_STATE_SI_REC_DURATION ||
			 $state == $_STATE_SI_REF_CHECK_ID ||
			 $state == $_STATE_SI_REF_SI_ID) {
			# Skip - already covered by association with another
			# data index
		}
	}

	return @result;
}

#
# _print_data(data_list)
#
# Print dialog data from DATA_LIST.
#
sub _print_data(@)
{
	my @data_list = @_;
	my $item;

	foreach $item (@data_list) {
		my ($num, undef, $data_index, undef, $value) = @$item;
		my $str = $_DATA_NAMES{$data_index};

		printf("%2d. %s%s: %s\n", $num, $str,
		       "."x($_DATA_NAME_MAX_WIDTH - length($str)), $value);
	}
}

#
# _ask_reuse()
#
# Ask if user wants to continue with saved dialog data. Return zero if not,
# non-zero otherwise.
#
sub _ask_reuse()
{
	my $input;

	print(<<EOF);

Do you want to continue this interrupted dialog? (y/n)
EOF

	while (!defined($input) || !($input =~ /^y|n$/)) {
		my $msg;

		$input = <STDIN>;

		# Check for EOF (e.g. CTRL-D)
		if (!defined($input)) {
			exit(1);
		}
		chomp($input);

		if ($input =~ /^\s*\?\s*$/) {
			print("\nHelp:\n");
			print_indented(<<EOF, 2);
If you say "y", the displayed dialog data will be used as base for this dialog. Saying "n" will discard this data.
EOF
			next;
		}

		($msg, $input) = _check_yes_no($input);

		if (defined($msg)) {
			print("Error: $msg!\n");
			next;
		}
	}

	if ($input eq "y") {
		return 1;
	}

	return 0;
}

#
# _get_end_state(state, op)
#
# Return ending state of a dialog edit session.
#
sub _get_end_state($$)
{
	my ($state, $op) = @_;
	my $end_state;

	if ($state == $_STATE_RUN_REGULARLY) {
		# Need to also ask for duration
		$end_state = $_STATE_MULTIHOST;
	} elsif ($state == $_STATE_SI_TYPE) {
		# Change in sysinfo type may invalidate all associated
		# information
		$end_state = $_STATE_SI_ID;
	} elsif ($op == $_FIN_OP_ADD &&
		  ($state == $_STATE_SI_ID ||
		   $state == $_STATE_FIRST_SI_ID)) {
		# A newly added sysinfo item needs the full sysinfo dialog
		$end_state = $_STATE_SI_ID;
	} elsif ($op == $_FIN_OP_ADD &&
		  ($state == $_STATE_EX_ID ||
		   $state == $_STATE_FIRST_EX_ID)) {
		# A newly added exception needs the full exception dialog
		$end_state = $_STATE_EX_ID;
	} elsif ($op == $_FIN_OP_ADD && $state == $_STATE_PARAM_ID) {
		# A newly added parameter needs the full parameter dialog
		$end_state = $_STATE_PARAM_ID;
	}

	return $end_state;
}

#
# _ask_edit(data_list, data)
#
# As if user wants to edit dialog data. Return (op, state, index), where
# OP is the ID of an operation, STATE is the state that is used to edit the
# item and INDEX is the index of the affected item.
#
sub _ask_edit($$)
{
	my ($data_list, $data) = @_;
	my $max_num;
	my $number;
	my $item;
	my $op;

	$max_num = $data_list->[-1]->[$_DATA_LIST_NUMBER];

	while (!defined($number)) {
		my $msg;
		my $input;

		print(<<EOF);
To modify an entry, enter its number. To delete an entry, enter "d" + its
number. To add a new item, enter "a" + its number. Empty input to finish
dialog and create health check.
EOF

		$input = <STDIN>;

		if (!defined($input)) {
			_interrupt();
		}

		chomp($input);

		# Debugging aid
		if ($input eq "dump") {
			_dump_data($_data);
			print("\n");
			next;
		}

		if ($input =~ /^\s*$/) {
			return ($_FIN_OP_END, undef, undef, undef);
		}

		# Add new line if input was not empty
		print("\n");

		if ($input =~ /^\s*d\s*(\d+)\s*$/) {
			# Handle delete request
			$op = $_FIN_OP_DEL;
			$input = $1;
			($msg, $number) = _check_number($input, 1, $max_num);
		} elsif ($input =~ /^\s*a\s*(\d+)\s*$/) {
			# Handle add request
			$op = $_FIN_OP_ADD;
			$input = $1;
			($msg, $number) = _check_number($input, 1, $max_num);
		} elsif ($input =~ /^\s*(\d+)\s*$/) {
			# Handle edit request
			$op = $_FIN_OP_EDIT;
			($msg, $number) = _check_number($input, 1, $max_num);
		} else {
			$msg = "unrecognized input: '$input'";
		}

		if (defined($msg)) {
			print("Error: $msg!\n\n");
			next;
		}
	}

	# Find and return data associated with number
	foreach $item (@$data_list) {
		my $start_state;
		my $end_state;
		my $index;
		my $data_index;

		if ($item->[$_DATA_LIST_NUMBER] != $number) {
			next;
		}

		$start_state = $item->[$_DATA_LIST_STATE];
		$data_index = $_DATA_INDEX{$start_state};

		# Convert an edit op on an empty list to an add op
		if ($op == $_FIN_OP_EDIT && $_DATA_IS_ARRAY{$data_index} &&
		    scalar(@{$data->[$data_index]}) == 0) {
			$op = $_FIN_OP_ADD;
		}

		$end_state = _get_end_state($start_state, $op);
		$index = $item->[$_DATA_LIST_INDEX];

		return ($op, $start_state, $end_state, $index);
	}
}

#
# _get_multi(data)
#
# Return values for multihost= and multitime= from dialog DATA.
#
sub _get_multi($)
{
	my ($data) = @_;
	my $multihost;
	my $multitime;

	# multihost =
	if ($data->[$_DATA_MULTIHOST] eq "y") {
		$multihost = 1;
	} else {
		$multihost = 0;
	}
	# multitime =
	if ($data->[$_DATA_MULTITIME] eq "y") {
		$multitime = 1;
	} else {
		$multitime = 0;
	}

	return ($multihost, $multitime);
}

#
# _get_check_program_perl(check_id, data)
#
# Return a hash of file contents required to implement a Perl check program
# based on dialog data.
#
sub _get_check_program_perl($$)
{
	my ($check_id, $data) = @_;
	my $filename;
	my $ex_id_list = $data->[$_DATA_EX_ID];
	my $param_id_list = $data->[$_DATA_PARAM_ID];
	my $si_id_list = $data->[$_DATA_SI_ID];
	my ($multihost, $multitime) = _get_multi($data);
	my $ex_id;
	my $param_id;
	my $si_id;
	my $perl_ex_def_list = "";
	my $perl_ex_report_list = "";
	my $perl_param_def_list = "";
	my $perl_si_def_list = "";
	my %entities;
	my $perl_file;
	my %result;

	# Get C health check program template
	$filename = catfile($main::lib_dir, $CHECK_DIALOG_TEMPL_PERL_CHECK);
	$perl_file = read_file($filename);

	# Build entity values
	$entities{"amp"} = "&";
	$entities{"check_id"} = $check_id;
	$entities{"check_author"} = $data->[$_DATA_AUTHOR];

	# Construct code for exceptions
	foreach $ex_id (@{$ex_id_list}) {
		my $ex_id_uc = uc($ex_id);

		$perl_ex_def_list .= <<EOF;
my \$LNXHC_EXCEPTION_$ex_id_uc = "$ex_id";
EOF
		$perl_ex_report_list .= <<EOF;
lnxhc_exception(\$LNXHC_EXCEPTION_$ex_id_uc);
EOF
	}
	if ($perl_ex_def_list ne "") {
		$perl_ex_def_list = <<EOF;
# Exception IDs
$perl_ex_def_list
EOF
}
	$entities{"perl_ex_def_list"} = $perl_ex_def_list;
	$entities{"perl_ex_report_list"} = $perl_ex_report_list;

	# Construct code for parameters
	foreach $param_id (@{$param_id_list}) {
		$perl_param_def_list .= <<EOF;
# Value of parameter '$param_id'.
my \$param_$param_id = \$ENV{"LNXHC_PARAM_$param_id"};

EOF
	}
	$entities{"perl_param_def_list"} = $perl_param_def_list;

	# Construct code for sysinfo items
	foreach $si_id (@{$si_id_list}) {
		if ($multihost == 0 && $multitime == 0) {
			# Provide variable to access sysinfo data file
			$perl_si_def_list .= <<EOF;
# Path to the file containing data for sysinfo item '$si_id'.
my \$sysinfo_$si_id = \$ENV{"LNXHC_SYSINFO_$si_id"};

EOF
		} else {
			# Mention ID
			$perl_si_def_list .= <<EOF;
#   $si_id
EOF
		}
	}
	chomp($perl_si_def_list);
	if ($multihost == 1 || $multitime == 1) {
		$perl_si_def_list = <<EOF;
# Sysinfo IDs
$perl_si_def_list
#
# Note: see 'man lnxhc_check_program' for information on how to access
# sysinfo data of multihost/multitime checks.
EOF
	}
	$entities{"perl_si_def_list"} = $perl_si_def_list;

	# Resolve entities
	$perl_file = resolve_entities($perl_file, \%entities);
	$result{"check"} = $perl_file;

	return \%result;
}

#
# _get_check_program_bash(check_id, data)
#
# Return a hash of file contents required to implement a bash check program
# based on dialog data.
#
sub _get_check_program_bash($$)
{
	my ($check_id, $data) = @_;
	my $filename;
	my $ex_id_list = $data->[$_DATA_EX_ID];
	my $param_id_list = $data->[$_DATA_PARAM_ID];
	my $si_id_list = $data->[$_DATA_SI_ID];
	my ($multihost, $multitime) = _get_multi($data);
	my $ex_id;
	my $param_id;
	my $si_id;
	my $bash_ex_def_list = "";
	my $bash_ex_report_list = "";
	my $bash_param_def_list = "";
	my $bash_si_def_list = "";
	my %entities;
	my $bash_file;
	my %result;

	# Get C health check program template
	$filename = catfile($main::lib_dir, $CHECK_DIALOG_TEMPL_BASH_CHECK);
	$bash_file = read_file($filename);

	# Build entity values
	$entities{"check_id"} = $check_id;
	$entities{"check_author"} = $data->[$_DATA_AUTHOR];

	# Construct code for exceptions
	foreach $ex_id (@{$ex_id_list}) {
		my $ex_id_uc = uc($ex_id);

		$bash_ex_def_list .= <<EOF;
LNXHC_EXCEPTION_$ex_id_uc="$ex_id"
EOF
		$bash_ex_report_list .= <<EOF;
lnxhc_exception "\$LNXHC_EXCEPTION_$ex_id_uc"
EOF
	}
	if ($bash_ex_def_list ne "") {
		$bash_ex_def_list = <<EOF;
# Exception IDs
$bash_ex_def_list
EOF
	}
	$entities{"bash_ex_def_list"} = $bash_ex_def_list;
	$entities{"bash_ex_report_list"} = $bash_ex_report_list;

	# Construct code for parameters
	foreach $param_id (@{$param_id_list}) {
		my $param_id_uc = uc($param_id);

		$bash_param_def_list .= <<EOF;
# Value of parameter '$param_id'
PARAM_$param_id_uc="\$LNXHC_PARAM_$param_id"

EOF
	}
	$entities{"bash_param_def_list"} = $bash_param_def_list;

	# Construct code for sysinfo items
	foreach $si_id (@{$si_id_list}) {
		my $si_id_uc = uc($si_id);

		if ($multihost == 0 && $multitime == 0) {
			# Provide variable to access sysinfo data file
			$bash_si_def_list .= <<EOF;
# Path to the file containing data for sysinfo item '$si_id'
SYSINFO_$si_id_uc="\$LNXHC_SYSINFO_$si_id"

EOF
		} else {
			# Mention ID
			$bash_si_def_list .= <<EOF;
#   $si_id
EOF
		}
	}
	chomp($bash_si_def_list);
	if ($multihost == 1 || $multitime == 1) {
		$bash_si_def_list = <<EOF;
# Sysinfo IDs
$bash_si_def_list
#
# Note: see 'man lnxhc_check_program' for information on how to access
# sysinfo data of multihost/multitime checks.
EOF
	}
	$entities{"bash_si_def_list"} = $bash_si_def_list;

	# Resolve entities
	$bash_file = resolve_entities($bash_file, \%entities);
	$result{"check"} = $bash_file;

	return \%result;
}

#
# _get_check_program_python(check_id, data)
#
# Return a hash of file contents required to implement a python check program
# based on dialog data.
#
sub _get_check_program_python($$)
{
	my ($check_id, $data) = @_;
	my $filename;
	my $ex_id_list = $data->[$_DATA_EX_ID];
	my $param_id_list = $data->[$_DATA_PARAM_ID];
	my $si_id_list = $data->[$_DATA_SI_ID];
	my ($multihost, $multitime) = _get_multi($data);
	my $ex_id;
	my $param_id;
	my $si_id;
	my $python_ex_def_list = "";
	my $python_ex_report_list = "";
	my $python_param_def_list = "";
	my $python_si_def_list = "";
	my %entities;
	my $python_file;
	my %result;

	# Get python health check program template
	$filename = catfile($main::lib_dir, $CHECK_DIALOG_TEMPL_PYTHON_CHECK);
	$python_file = read_file($filename);

	# Build entity values
	$entities{"check_id"} = $check_id;
	$entities{"check_author"} = $data->[$_DATA_AUTHOR];

	# Construct code for exceptions
	foreach $ex_id (@{$ex_id_list}) {
		my $ex_id_uc = uc($ex_id);

                $python_ex_def_list .= <<EOF;
		ex_$ex_id = LnxhcException('$ex_id')
EOF
		$python_ex_report_list .= <<EOF;
		# uncomment below to set exception variable(s)
		# ex_$ex_id.setxvar("var", "value")
		self.cause(ex_$ex_id)

EOF
	}

	$entities{"python_ex_def_list"} = $python_ex_def_list;
	$entities{"python_ex_report_list"} = $python_ex_report_list;

	# Construct code for parameters
	foreach $param_id (@{$param_id_list}) {
		my $param_id_uc = uc($param_id);

		$python_param_def_list .= <<EOF;
		# Value of parameter '$param_id'
		param_$param_id = self.get_param('$param_id')

EOF
	}
	$entities{"python_param_def_list"} = $python_param_def_list;

	# Construct code for sysinfo items
	foreach $si_id (@{$si_id_list}) {
		my $si_id_uc = uc($si_id);

		if ($multihost == 0 && $multitime == 0) {
			# Provide variable to access sysinfo data file
			$python_si_def_list .= <<EOF;
		# Path to the file containing data for sysinfo item '$si_id'
		si_$si_id = self.get_sysinfo('$si_id')

EOF
		} else {
			# Mention ID
			$python_si_def_list .= <<EOF;
#   $si_id
EOF
		}
	}
	chomp($python_si_def_list);
	if ($multihost == 1 || $multitime == 1) {
		$python_si_def_list = <<EOF;
# Sysinfo IDs
$python_si_def_list

#
# Note: see 'man lnxhc_check_program' for information on how to access
# sysinfo data of multihost/multitime checks.
EOF
	}
	$entities{"python_si_def_list"} = $python_si_def_list;

	# Resolve entities
	$python_file = resolve_entities($python_file, \%entities);
	$result{"check"} = $python_file;

	return \%result;
}

#
# _get_check_program_c(check_id, data)
#
# Return a hash of file contents required to implement a C check program
# based on dialog data.
#
sub _get_check_program_c($$)
{
	my ($check_id, $data) = @_;
	my $filename;
	my $ex_id_list = $data->[$_DATA_EX_ID];
	my $param_id_list = $data->[$_DATA_PARAM_ID];
	my $si_id_list = $data->[$_DATA_SI_ID];
	my ($multihost, $multitime) = _get_multi($data);
	my $ex_id;
	my $param_id;
	my $si_id;
	my $c_ex_def_list = "";
	my $c_ex_report_list = "";
	my $c_param_def_list = "";
	my $c_param_get_list = "";
	my $c_si_def_list = "";
	my $c_si_get_list = "";
	my %entities;
	my $c_file;
	my $makefile;
	my %result;

	# Get C health check Makefile template
	$filename = catfile($main::lib_dir, $CHECK_DIALOG_TEMPL_C_MAKEFILE);
	$makefile = read_file($filename);

	# Get C health check program template
	$filename = catfile($main::lib_dir, $CHECK_DIALOG_TEMPL_C_CHECK);
	$c_file = read_file($filename);

	# Build entity values
	$entities{"check_id"} = $check_id;
	$entities{"check_author"} = $data->[$_DATA_AUTHOR];

	# Construct code for exceptions
	foreach $ex_id (@{$ex_id_list}) {
		my $ex_id_uc = uc($ex_id);

		$c_ex_def_list .= <<EOF;
#define	LNXHC_EXCEPTION_$ex_id_uc	"$ex_id"
EOF
		$c_ex_report_list .= <<EOF;
	lnxhc_exception(LNXHC_EXCEPTION_$ex_id_uc);
EOF
	}
	$entities{"c_ex_def_list"} = $c_ex_def_list;
	$entities{"c_ex_report_list"} = $c_ex_report_list;

	# Construct code for parameters
	foreach $param_id (@{$param_id_list}) {
		$c_param_def_list .= <<EOF;
/* Value of parameter '$param_id'. */
static char *param_$param_id;

EOF
		$c_param_get_list .= <<EOF;
	param_$param_id = getenv("LNXHC_PARAM_$param_id");
EOF
	}
	$entities{"c_param_def_list"} = $c_param_def_list;
	$entities{"c_param_get_list"} = $c_param_get_list;

	# Construct code for sysinfo items
	foreach $si_id (@{$si_id_list}) {
		if ($multihost == 0 && $multitime == 0) {
			$c_si_def_list .= <<EOF;
/* Path to the file containing data for sysinfo item '$si_id'. */
static char *sysinfo_$si_id;

EOF
			$c_si_get_list .= <<EOF;
	sysinfo_$si_id = getenv("LNXHC_SYSINFO_$si_id");
EOF
		} else {
			$c_si_def_list .= <<EOF;
 *  $si_id
EOF
		}
	}
	chomp($c_si_def_list);
	if ($multihost == 1 || $multitime == 1) {
		$c_si_def_list = <<EOF;
/* Sysinfo IDs
$c_si_def_list
 *
 * Note: see 'man lnxhc_check_program' for information on how to access
 * sysinfo data of multihost/multitime checks. */
EOF
	}
	$entities{"c_si_def_list"} = $c_si_def_list;
	$entities{"c_si_get_list"} = $c_si_get_list;

	# Resolve entities
	$c_file = resolve_entities($c_file, \%entities);
	$result{"check.c"} = $c_file;
	$result{"Makefile"} = $makefile;

	return \%result;
}

#
# _get_check_program_file(check_id, data)
#
# Return hash filename -> contents of files implementing a check program
# based on dialog data.
#
sub _get_check_program_file($$)
{
	my ($check_id, $data) = @_;
	my $lang = $data->[$_DATA_LANGUAGE];
	my $result = {};

	if ($lang == $_LANG_PERL) {
		$result = _get_check_program_perl($check_id, $data);
	} elsif ($lang == $_LANG_BASH) {
		$result = _get_check_program_bash($check_id, $data);
	} elsif ($lang == $_LANG_PYTHON) {
		$result = _get_check_program_python($check_id, $data);
	} elsif ($lang == $_LANG_C) {
		$result = _get_check_program_c($check_id, $data);
	} elsif ($lang == $_LANG_OTHER_SCRIPT) {
		$result->{"check"} = "";
	}

	return $result;
}

#
# _get_check_definitions_sysinfo(data)
#
# Return string containing the sysinfo definitions from DATA.
#
sub _get_check_definitions_sysinfo($)
{
	my ($data) = @_;
	my $si_id_list = $data->[$_DATA_SI_ID];
	my $si_type_list = $data->[$_DATA_SI_TYPE];
	my $si_file_filename_list = $data->[$_DATA_SI_FILE_FILENAME];
	my $si_user_id_list = $data->[$_DATA_SI_USER_ID];
	my $si_prog_cmdline_list = $data->[$_DATA_SI_PROG_CMDLINE];
	my $si_rec_start_list = $data->[$_DATA_SI_REC_START];
	my $si_rec_stop_list = $data->[$_DATA_SI_REC_STOP];
	my $si_rec_duration_list = $data->[$_DATA_SI_REC_DURATION];
	my $si_ref_check_id_list = $data->[$_DATA_SI_REF_CHECK_ID];
	my $si_ref_si_id_list = $data->[$_DATA_SI_REF_SI_ID];
	my $i;
	my $result = "";

	for ($i = 0; $i < scalar(@{$si_id_list}); $i++) {
		my $si_id = $si_id_list->[$i];
		my $type = $si_type_list->[$i];

		if ($i > 0) {
			$result .= "\n";
		}

		$result .= "[sysinfo $si_id]\n";

		if ($type == $_SI_TYPE_FILE) {
			my $file = $si_file_filename_list->[$i];
			my $user = $si_user_id_list->[$i];

			# Sysinfo file type item
			$result .= "file = ".quote($file)."\n";
			if (defined($user) && $user ne "") {
				$result .= "user = ".quote($user)."\n";
			}
		} elsif ($type == $_SI_TYPE_PROG) {
			my $cmdline = $si_prog_cmdline_list->[$i];
			my $user = $si_user_id_list->[$i];

			# Sysinfo program type item
			$result .= "program = ".quote($cmdline)."\n";
			if (defined($user) && $user ne "") {
				$result .= "user = ".quote($user)."\n";
			}
		} elsif ($type == $_SI_TYPE_REC) {
			my $start = $si_rec_start_list->[$i];
			my $stop = $si_rec_stop_list->[$i];
			my $duration = $si_rec_duration_list->[$i];
			my $user = $si_user_id_list->[$i];

			# Sysinfo record type item
			$result .= "start = ".quote($start)."\n";
			$result .= "stop = ".quote($stop)."\n";
			$result .= "duration = ".quote($duration)."\n";
			if (defined($user) && $user ne "") {
				$result .= "user = ".quote($user)."\n";
			}
		} elsif ($type == $_SI_TYPE_REF) {
			my $check_id = $si_ref_check_id_list->[$i];
			my $si_id = $si_ref_si_id_list->[$i];

			# Sysinfo reference type item
			$result .= "ref = ".
				   quote("$check_id.$si_id")."\n";
		} elsif ($type == $_SI_TYPE_EXT) {
			# Sysinfo external type item
			$result .= "external\n";
		}
	}

	return $result;
}

#
# _get_check_definitions_file(data)
#
# Return contents of check definitions file according to dialog data.
#
sub _get_check_definitions_file($)
{
	my ($data) = @_;
	my $result = "";
	my $author;
	my $component;
	my $repeat;
	my $multihost;
	my $multitime;
	my $state;
	my $file_list;
	my $file;
	my $ex_id_list;
	my $ex_sev_list;
	my $param_id_list;
	my $param_def_list;
	my $i;

	# author =
	$author = quote($data->[$_DATA_AUTHOR]);
	# component =
	$component = quote($data->[$_DATA_COMPONENT]);
	# repeat =
	if ($data->[$_DATA_RUN_REGULARLY] eq "y") {
		$repeat = quote($data->[$_DATA_RUN_REPEAT_INTERVAL]);
	}
	# multihost =
	if ($data->[$_DATA_MULTIHOST] eq "y") {
		$multihost = 1;
	} else {
		$multihost = 0;
	}
	# multitime =
	if ($data->[$_DATA_MULTITIME] eq "y") {
		$multitime = 1;
	} else {
		$multitime = 0;
	}
	# state =
	if ($data->[$_DATA_WORKS_NOCONFIG] eq "y" &&
	    $data->[$_DATA_WORKS_DEFAULT_SOFT] eq "y") {
		$state = "active";
	} else {
		$state = "inactive";
	}
	# [check]
	$result .= <<EOF;
[check]
author = $author
component = $component
EOF
	if ($multihost) {
		$result .= <<EOF;
multihost = $multihost
EOF
	}
	if ($multitime) {
		$result .= <<EOF;
multitime = $multitime
EOF
	}
	if ($state ne "active") {
		$result .= <<EOF;
state = $state
EOF
	}
	if (defined($repeat)) {
		$result .= <<EOF;
repeat = $repeat
EOF
	}

	# List of extra files
	$file_list = $data->[$_DATA_EXTRA_FILES];
	foreach $file (@$file_list) {
		my $quoted_file = quote($file);
		$result .= <<EOF;
extrafile = $quoted_file
EOF
	}

	# [param <id>]
	$param_id_list = $data->[$_DATA_PARAM_ID];
	$param_def_list = $data->[$_DATA_PARAM_DEFAULT];
	for ($i = 0; $i < scalar(@$param_id_list); $i++) {
		my $param_id = $param_id_list->[$i];
		my $param_def = quote($param_def_list->[$i]);

		$result .= <<EOF;

[param $param_id]
default = $param_def
EOF
	}

	# [sysinfo <id>]
	$result .= "\n"._get_check_definitions_sysinfo($data);

	# [exception <id>]
	$ex_id_list = $data->[$_DATA_EX_ID];
	$ex_sev_list = $data->[$_DATA_EX_SEVERITY];
	for ($i = 0; $i < scalar(@$ex_id_list); $i++) {
		my $ex_id = $ex_id_list->[$i];
		my $ex_sev = lc($_SEVERITIES[$ex_sev_list->[$i] - 1]);

		# Add new exception section
		$result .= <<EOF;

[exception $ex_id]
severity = $ex_sev
EOF
	}

	return $result;
}

#
# _get_check_descriptions_file(data)
#
# Return contents of check descriptions file according to dialog data.
#
sub _get_check_descriptions_file($)
{
	my ($data) = @_;
	my $result = "";
	my $param_id;

	$result .= <<EOF;
[title]
TODO: Enter a single-line description this health check.

[description]
TODO: Enter a more detailed description of the purpose of this health check.
EOF

	# [param <id>]
	foreach $param_id (@{$data->[$_DATA_PARAM_ID]}) {
		$result .= <<EOF;

[param $param_id]
TODO: Add a short description for parameter '$param_id'.
EOF
	}

	return $result;
}

#
# _get_check_exceptions_file(data)
#
# Return contents of check exceptions file according to dialog data.
#
sub _get_check_exceptions_file($)
{
	my ($data) = @_;
	my $result = "";
	my $ex_id;

	foreach $ex_id (@{$data->[$_DATA_EX_ID]}) {
		if ($result ne "") {
			$result .= "\n";
		}
		$result .= <<EOF;
[summary $ex_id]
TODO: Write a short summary of the problem which includes all relevant
information needed by advanced users to implement a solution.

[explanation $ex_id]
TODO: Write a detailed text containing answers to the following questions:
 - What is the problem?
 - What is the impact on the checked component?
 - What are the steps to manually verify that the problem exists?

[solution $ex_id]
TODO: Write a detailed text describing how the problem can be solved.

[reference $ex_id]
TODO: List references to documentation which can help in understanding and
solving the problem.
EOF
	}

	return $result;
}

#
# _create_check(data, check_dir, check_id)
#
# Create check from dialog data. CHECK_DIR specifies the target directory
# for the new check. CHECK_ID is the ID.
#
sub _create_check($$$)
{
	my ($data, $dir, $check_id) = @_;
	my $program;
	my $definitions;
	my $descriptions;
	my $exceptions;
	my $filename;
	my $lang = $data->[$_DATA_LANGUAGE];

	# Normalize directory
	$dir = catfile(dirname($dir), basename($dir));

	print("Creating check in directory '$dir'.\n");

	# Create check directory
	mkdir($dir) or
		die("could not create directory '$dir': $!\n");

	# Get file contents
	$program	= _get_check_program_file($check_id, $data);
	$definitions	= _get_check_definitions_file($data);
	$descriptions	= _get_check_descriptions_file($data);
	$exceptions	= _get_check_exceptions_file($data);

	# Write files
	foreach $filename (keys(%{$program})) {
		my $content = $program->{$filename};

		write_file(catfile($dir, $filename), $content, "+0700");
	}
	write_file(catfile($dir, $CHECK_DEF_FILENAME), $definitions, "+0600");
	write_file(catfile($dir, $CHECK_DESC_FILENAME), $descriptions, "+0600");
	write_file(catfile($dir, $CHECK_EX_FILENAME), $exceptions, "+0600");

	# Create extra files
	foreach $filename (@{$data->[$_DATA_EXTRA_FILES]}) {
		write_file(catfile($dir, $filename), "", 0600);
	}

	print("Check was successfully created.\n");
	if ($lang == $_LANG_C) {
		print("Use 'make' in the check directory to compile the ".
		      "check.\n");
	} elsif ($lang == $_LANG_OTHER_COMP) {
		print("TODO: implement a build mechanism which creates an ".
		      "executable named 'check'.\n");
	} elsif ($lang == $_LANG_OTHER_SCRIPT) {
		print("TODO: write an executable script named 'check'.\n");
	}
	print("Use '$main::tool_inv run $dir' to run this check.\n");
	print("Please see each file for specific TODOs.\n");
}

#
# _get_parent_data(data_index)
#
# If the array at DATA_INDEX is associated with another dialog data item,
# return the index of that item. Otherwise return undef.
#
sub _get_parent_index($)
{
	my ($data_index) = @_;
	my $parent_index;

	foreach $parent_index (keys(%_DATA_ASSOC)) {
		my $child_list = $_DATA_ASSOC{$parent_index};
		my $child_index;

		foreach $child_index (@$child_list) {
			if ($child_index == $data_index) {
				return $parent_index;
			}
		}
	}

	return undef;
}

#
# _get_new_index(data, state)
#
# Return the index of a new entry in the array associated with the state. This
# can be an index from an array with which this array is associated.
#
sub _get_new_index($$)
{
	my ($data, $state) = @_;
	my $data_index = $_DATA_INDEX{$state};
	my $parent_index = _get_parent_index($data_index);

	if (defined($parent_index)) {
		$data_index = $parent_index;
	}

	return scalar(@{$data->[$data_index]});
}

#
# _do_add_data(_data, start_state, end_state)
#
# Add an entry to a list of entries. Return zero if operation was successful,
# non-zero otherwise.
#
sub _do_add_data($$$)
{
	my ($data, $start_state, $end_state) = @_;
	my $data_index = $_DATA_INDEX{$start_state};
	my $index;

	if (!$_DATA_CAN_ADD{$data_index}) {
		print("Error: cannot add to this entry!\n");
		return 1;
	}

	$index = _get_new_index($data, $start_state);
	_dialog($data, $start_state, $end_state, $_DIA_OP_ADD, $index);

	return 0;
}

#
# _do_edit_data(data, start_state, end_state, index)
#
# Perform an edit operation. Return zero if operation was successful, non-zero
# otherwise.
#
sub _do_edit_data($$$$)
{
	my ($data, $start_state, $end_state, $index) = @_;
	my $data_index = $_DATA_INDEX{$start_state};

	if ($_DATA_IS_ARRAY{$data_index} &&
	    scalar(@{$data->[$data_index]}) == 0) {
		# Edit on empty array not possible, perform add operation
		# instead
		return _do_add_data($data, $start_state, $end_state);
	}

	_dialog($data, $start_state, $end_state, $_DIA_OP_EDIT, $index);

	return 0;
}

#
# check_dialog(check_dir)
#
# Query user for health check parameters and create a health check skeleton
# based on user input.
#
sub check_dialog($)
{
	my ($check_dir) = @_;
	my $check_id;
	my $data;
	my $op;
	my $reprint = 1;

	# Validate check ID
	if (-e $check_dir) {
		die("'$check_dir' already exists\n");
	}

	# Ensure that ID is valid
	$check_id = basename($check_dir);
	validate_id("check name", $check_id);

	# Install handler that will save dialog data on interruption (CTRL-C)
	$SIG{'INT'} = \&_interrupt;

	_print_intro();

	# Initialize dialog data
	$_data = _get_empty_data();

	# Check for saved dialog data
	$data = _read_saved_data();
	if ($data) {
		print(<<EOF);
A previous dialog was interrupted. Below is the data that was entered for that
dialog:

EOF
		_print_data(_get_data_list($data));
		if (_ask_reuse()) {
			print("Reusing dialog data.\n\n");
			$_data = $data;
		} else {
			print("Discarding dialog data.\n\n");
		}
		_delete_saved_data();
	}

	# Start dialog
	_dialog($_data);

	# Allow user to edit answers
	do {
		my $start_state;
		my $end_state;
		my $index;
		my @data_list = _get_data_list($_data);

		if ($reprint) {
			_print_finalize();
			_print_data(@data_list);
			print("\n");
		} else {
			$reprint = 1;
		}

		($op, $start_state, $end_state, $index) = _ask_edit(\@data_list,
								    $_data);

		if ($op == $_FIN_OP_EDIT) {
			# Work on a copy to allow roll-back in case of an
			# interrupt
			$data = _get_data_copy($_data);
			if (_do_edit_data($data, $start_state, $end_state,
					  $index)) {
				$reprint = 0;
			}
			$_data = $data;
		} elsif ($op == $_FIN_OP_ADD) {
			$data = _get_data_copy($_data);
			if (_do_add_data($data, $start_state, $end_state)) {
				$reprint = 0;
			}
			$_data = $data;
			print("\n");
		} elsif ($op == $_FIN_OP_DEL) {
			if (_delete_data($_data, $start_state,
					$index)) {
				$reprint = 0;
			}
			print("\n");
		}
	} while ($op != $_FIN_OP_END);

	# Create check from dialog data
	_create_check($_data, $check_dir, $check_id);
}


#
# Code entry
#

# Indicate successful module initialization
1;
