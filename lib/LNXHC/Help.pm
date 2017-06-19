#
# LNXHC::Help.pm
#   Linux Health Checker support functions for online help
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

package LNXHC::Help;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#
use LNXHC::Misc qw(debug info);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&help_print);


#
# Constants
#

# Enumeration of help text keys
my $_LNXHC_HELP			= 0;
my $_LNXHC_DETAIL_HELP		= 1;
my $_LNXHC_DETAIL_SYSTEM	= 3;
my $_LNXHC_DETAIL_DEBUG		= 4;
my $_RUN_HELP			= 100;
my $_DEVEL_HELP			= 200;
my $_SYSINFO_HELP		= 300;
my $_CHECK_HELP			= 400;
my $_PROFILE_HELP		= 500;
my $_CONS_HELP			= 600;

# Map a help text key to a help text
my %_key_to_text = (
	$_LNXHC_HELP => <<EOF,
Usage: lnxhc SUBCOMMAND [OPTIONS]

Use lnxhc to check a Linux system for potential problems before they impact
availability or cause an outage.

SUBCOMMANDS
  check         Manage checks
  consumer      Manage result consumers
  devel         Access development support functions
  profile       Manage configuration profiles
  run           Run checks
  sysinfo       Manage system information

GLOBAL OPTIONS
  -h, --help           Print usage information. Can be combined with an option.
  -v, --version        Print version information, then exit
  -V, --verbose        Print additional run-time information
  -q, --quiet          Print only warning and error messages
  -U, --user-dir DIR   Use DIR as user data directory (default ~/.lnxhc)
      --system         Select system-wide database for management operations

For more information, see the man page of lnxhc.
EOF
	$_LNXHC_DETAIL_HELP => <<EOF,
Usage: lnxhc [SUBCOMMAND] [OPTIONS]--help

Use -h or --help to obtain information on the usage of lnxhc, a subcommand of
lnxhc or a specific option.

To get general information on lnxhc and the list of available subcommands, use
  lnxhc --help

To get information on a specific subcommand, use
  lnxhc SUBCOMMAND --help

To get information on a specific option, use
  lnxhc OPTION --help
  lnxhc SUBCOMMAND OPTION --help

For more usage information, see the man page of lnxhc.
EOF
	$_LNXHC_DETAIL_SYSTEM => <<EOF,
Usage: lnxhc [SUBCOMMAND] [OPTIONS] --system

Use --system to select the system-wide database as target for check, consumer
or profile related management actions. Default is to use the per-user database.
EOF
	$_LNXHC_DETAIL_DEBUG => <<EOF,
Usage: lnxhc [SUBCOMMAND] [OPTIONS] --debug

Use option --debug to run lnxhc in debugging mode. In this mode, lnxhc prints
additional run-time information which might be useful for analyzing problems in
health check or consumer programs or in lnxhc itself.

To enable debugging for help output, specify --debug twice.
EOF
	$_RUN_HELP => <<EOF,
Usage: lnxhc run [OPTIONS] [SELECTION]

Use LNXHC RUN to run checks. All active checks are run if no check is selected.

SELECTION
  NAME                     Select check by NAME
  DIRECTORY                Select check found in DIRECTORY
  PATTERN                  Select checks with matching name (* and ? accepted)
  KEY=VALUE or KEY!=VALUE  Select checks with matching property value
  --match-all              Select checks matching all criteria (default: any)

CONFIGURATION OPTIONS
  -p, --param KEY=VALUE       Override check parameter for this run
  -P, --cons-param KEY=VALUE  Override consumer parameter for this run
  -d, --defaults              Use default configuration for this run
      --profile NAME          Use configuration of profile NAME for this run

OUTPUT OPTIONS
  -r, --replay             Do not run checks, use result data from previous run
  -R, --report REPORT      Use REPORT as report generator for this run
      --no-report          Do not generate a report
      --no-handler         Do not call check result handlers

INPUT OPTIONS
  -f, --file FILE          Do not collect sysinfo data, use data from FILE
  -c, --current            Do not collect sysinfo data, use current data
      --no-sudo            Do not collect sysinfo data that requires sudo
      --sysvar KEY=VALUE   Set the value of a system variable
      --add-data ID=FILE   Add sysinfo data from FILE
EOF
	$_DEVEL_HELP => <<EOF,
Usage: lnxhc devel ACTION [OPTIONS]

Use LNXHC DEVEL to access support functions for developing new checks and
result consumers.

ACTIONS
  --show-sysvar         Show system variables for the local system
  --create-check DIR    Start dialog for creating a new check in directory DIR
EOF
	$_SYSINFO_HELP => <<EOF,
Usage: lnxhc sysinfo ACTION [OPTIONS]

Use LNXHC SYSINFO to display and manage system information. Actions apply to
the current data set if no file is specified.

DISPLAY ACTIONS
  -l, --list                    List data set contents
  -s, --show                    Show detailed data set information
      --show-property KEY       Show data set property specified by KEY
      --show-sysvar             Show system variables
      --show-data CHECK.SI      Show sysinfo item data

MODIFICATION ACTIONS
  -a, --add-data ID=FILE        Add sysinfo data from FILE
      --sysvar KEY=VALUE        Set system variable KEY to VALUE
      --set KEY=VALUE           Modify data set property
  -r, --remove KEY              Remove data set property
      --clear                   Clear sysinfo data
  -m, --merge FILE              Add contents of FILE to data set

MANAGEMENT ACTIONS
  -c, --collect                 Collect sysinfo data
  -n, --new                     Create an empty data set
  -e, --export FILE             Export data set to file
  -i, --import FILE             Replace data set with contents of FILE

OPTIONS
  -f, --file FILE               Operate on data set found in FILE
  -I, --instance-id INST        Use INST as instance ID for operation
  -H, --host-id HOST            Use HOST as host name for operation
      --no-sudo                 Do not collect sysinfo data that requires sudo
      --profile NAME            Use check configuration of profile NAME
EOF
	$_CHECK_HELP => <<EOF,
Usage: lnxhc check ACTION [OPTIONS] [SELECTION]

Use LNXHC CHECK to display, configure and manage checks. Actions apply to the
selected checks.

SELECTION
  NAME                     Select check by NAME
  DIRECTORY                Select check found in DIRECTORY
  PATTERN                  Select checks with matching NAME (* and ? accepted)
  KEY=VALUE or KEY!=VALUE  Select checks with matching property value
  --match-all              Select checks matching all criteria (default: any)

DISPLAY ACTIONS
  -l, --list                   List checks
  -i, --info                   Show basic check information
  -s, --show                   Show detailed check information
      --show-property KEY      Show check property specified by KEY
      --show-data-id CHECK.SI  Show data ID of specified sysinfo item
      --show-sudoers USER      Show required sudoers file for USER

CONFIGURATION ACTIONS
  -S, --state CHECK=STATE           Set activation state (active, inactive)
  -p, --param CHECK.PARAM=VALUE     Set parameter
  -d, --defaults                    Set check configuration to default values
      --ex-severity CHECK.EX=SEV    Set exception severity (low, medium, high)
      --ex-state CHECK.EX=STATE     Set exception state (active, inactive)
      --rec-duration CHECK.SI=TIME  Set record duration
      --set KEY=VALUE               Set check property specified by KEY

MANAGEMENT ACTIONS
      --install DIR        Add check from directory DIR to the database
      --uninstall          Remove selected checks from database

OPTIONS
      --profile NAME       Select profile NAME for configuration/display actions
      --system             Select system-wide database for management actions
EOF
	$_PROFILE_HELP => <<EOF,
Usage: lnxhc profile ACTION [OPTIONS] [SELECTION]

Use LNXHC PROFILE to display, modify and manage configuration profiles.
Actions apply to the active profile if no profile is selected.

SELECTION
  NAME                     Select profile by NAME
  PATTERN                  Select profiles with matching name (* and ? accepted)
  KEY=VALUE or KEY!=VALUE  Select profiles with matching property value
  --match-all              Select profiles matching all criteria (default: any)

DISPLAY ACTIONS
  -l, --list                List profiles
  -s, --show                Show detailed profile information
      --show-property KEY   Show profile property specified by KEY

MODIFICATION ACTIONS
  -a, --activate NAME       Mark profile NAME as active profile
      --description TEXT    Modify profile description
      --set KEY=VALUE       Modify profile property
  -r, --remove KEY          Remove profile property
      --clear               Clear configuration
  -d, --defaults            Set configuration to default values
  -m, --merge FILE          Add contents of FILE to profile
  -M, --merge-profile NAME  Merge configuration with data from profile NAME

MANAGEMENT ACTIONS
  -e, --export FILE         Export profile to file (- for STDOUT)
  -i, --import FILE         Replace profile with contents of FILE (- for STDIN)
  -n, --new NAME            Create an empty profile
      --copy NAME           Create a profile copy named NAME
      --rename NAME         Rename profile
      --delete              Delete profile

OPTIONS
      --system              Select system-wide database for management actions
EOF
	$_CONS_HELP => <<EOF,
Usage: lnxhc consumer ACTION [OPTIONS] [SELECTION]

Use LNXHC CONSUMER to display, configure and manage check result consumers.
Actions apply to the selected consumers.

SELECTION
  NAME                     Select consumer by NAME
  DIRECTORY                Select consumer found in DIRECTORY
  PATTERN                  Select consumers with matching name(* and ? accepted)
  KEY=VALUE or KEY!=VALUE  Select consumers with matching property value
  --match-all              Select consumers matching all criteria (default: any)

DISPLAY ACTIONS
  -l, --list               Show list of consumers
  -i, --info               Show basic consumer information
  -s, --show               Show detailed consumer information
      --show-property KEY  Show consumer property specified by KEY

CONFIGURATION ACTIONS
  -R, --report CONS             Set active report consumer
  -S, --state CONS=STATE        Set activation state (active, inactive)
  -p, --param CONS.PARAM=VALUE  Set parameter
  -d, --defaults                Set consumer configuration to default values
      --set KEY=VALUE           Set consumer property specified by KEY

MANAGEMENT ACTIONS
      --install DIR        Add consumer from directory DIR to the database
      --uninstall          Remove selected consumers from database

OPTIONS
      --profile NAME       Operate on consumer configuration of profile NAME
      --system             Select system-wide database for management actions
EOF
);

# Map option to help text key for global options
my %_global_opt_to_key = (
	"help"		=> $_LNXHC_DETAIL_HELP,
	"h"		=> $_LNXHC_DETAIL_HELP,
	"system"	=> $_LNXHC_DETAIL_SYSTEM,
	"debug"		=> $_LNXHC_DETAIL_DEBUG,
);

# Map option to help text key for the main program
my %_main_opt_to_key = (
	"" => $_LNXHC_HELP,
);

# Map option to help text key for the run subcommand
my %_run_opt_to_key = (
	"" => $_RUN_HELP,
);

# Map option to help text key for the devel subcommand
my %_devel_opt_to_key = (
	"" => $_DEVEL_HELP,
);

# Map option to help text key for the sysinfo subcommand
my %_sysinfo_opt_to_key = (
	"" => $_SYSINFO_HELP,
);

# Map option to help text key for the check subcommand
my %_check_opt_to_key = (
	"" => $_CHECK_HELP,
);

# Map option to help text key for the profile subcommand
my %_profile_opt_to_key = (
	"" => $_PROFILE_HELP,
);

# Map option to help text key for the consumer subcommand
my %_cons_opt_to_key = (
	"" => $_CONS_HELP,
);

# Map subcommand to option map
my %_cmd_to_hash = (
	""		=> \%_main_opt_to_key,
	"run"		=> \%_run_opt_to_key,
	"devel"		=> \%_devel_opt_to_key,
	"sysinfo"	=> \%_sysinfo_opt_to_key,
	"check"		=> \%_check_opt_to_key,
	"profile"	=> \%_profile_opt_to_key,
	"consumer"	=> \%_cons_opt_to_key,
);


#
# Sub-routines
#

#
# _get_text_key(SUBCOMMAND[,OPTION])
#
# Get help text key for specified SUBCOMMAND and OPTION combination.
#
sub _get_text_key($;$)
{
	my ($subcommand, $option) = @_;
	my $hash;

	# Normalize option value
	if (!defined($option)) {
		$option = "";
	} else {
		# Remove leading - and --
		$option =~ s/^--?//;
	}

	# Check for global options first
	if ($option ne "") {
		my $key = $_global_opt_to_key{$option};

		if (defined($key)) {
			return $key;
		}
	}

	# Get hash for the specified subcommand
	$hash = $_cmd_to_hash{$subcommand};
	if (!defined($hash)) {
		return undef;
	}

	return $hash->{$option};
}

#
# _get_cmdline(subcommand, option)
#
# Return a string containing a subcommand line which represents the specified
# SUBCOMMAND and OPTION strings.
#
sub _get_cmdline($$)
{
	my ($subcommand, $option) = @_;

	if ($subcommand ne "" && defined($option)) {
		$subcommand .= " ";
	}
	if (!defined($option)) {
		$option = "";
	}

	return "lnxhc $subcommand$option";
}

#
# help_print(subcommand, option)
#
# Print help text for combination of SUBCOMMAND and OPTION.
#
sub help_print($;$)
{
	my ($subcommand, $option) = @_;
	my $key;

	# Search for a help text entry
	$key = _get_text_key($subcommand, $option);
	if (!defined($key)) {
		die("No detailed help available for '".
		    _get_cmdline($subcommand, $option)."'\n");
	}

	# Print help text
	print($_key_to_text{$key});
}


#
# Code entry
#

# Indicate successful module initialization
1;
