#
# LNXHC::Consts.pm
#   Linux Health Checker constants definitions
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

package LNXHC::Consts;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw($CAT_TOOL $CHECK_CONF_T_EX_CONF_DB $CHECK_CONF_T_ID
		    $CHECK_CONF_T_PARAM_CONF_DB $CHECK_CONF_T_REPEAT
		    $CHECK_CONF_T_SI_CONF_DB $CHECK_CONF_T_STATE
		    $CHECK_DEFAULT_REPEAT $CHECK_DEFAULT_STATE $CHECK_DEF_CHECK
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
		    $CHECK_DESC_PARAM $CHECK_DESC_TITLE $CHECK_DIALOG_FILENAME
		    $CHECK_DIALOG_TEMPL_BASH_CHECK $CHECK_DIALOG_TEMPL_C_CHECK
		    $CHECK_DIALOG_TEMPL_PYTHON_CHECK
		    $CHECK_DIALOG_TEMPL_C_MAKEFILE
		    $CHECK_DIALOG_TEMPL_PERL_CHECK $CHECK_DIR_VAR
		    $CHECK_EX_EXPLANATION $CHECK_EX_FILENAME $CHECK_EX_FORMAT
		    $CHECK_EX_REFERENCE $CHECK_EX_SOLUTION $CHECK_EX_SUMMARY
		    $CHECK_PROG_FAILED_DEP_CODE $CHECK_PROG_FILENAME
		    $CHECK_PROG_PARAM_ERROR_CODE
		    $CHECK_STATS_T_EX_HIGH $CHECK_STATS_T_EX_LOW
		    $CHECK_STATS_T_EX_MEDIUM $CHECK_STATS_T_EX_TOTAL
		    $CHECK_STATS_T_RUN_EXCEPTIONS
		    $CHECK_STATS_T_RUN_FAILED_CHKPROG
		    $CHECK_STATS_T_RUN_PARAM_ERROR
		    $CHECK_STATS_T_RUN_FAILED_SYSINFO
		    $CHECK_STATS_T_RUN_NOT_APPLICABLE $CHECK_STATS_T_RUN_SUCCESS
		    $CHECK_STATS_T_RUN_TOTAL $CHECK_STATS_T_TIME_AVG
		    $CHECK_STATS_T_TIME_MAX $CHECK_STATS_T_TIME_MIN
		    $CHECK_T_AUTHORS $CHECK_T_COMPONENT $CHECK_T_DEPS
		    $CHECK_T_DESC $CHECK_T_DIR $CHECK_T_EXTRAFILES
		    $CHECK_T_EX_DB $CHECK_T_ID $CHECK_T_MULTIHOST
		    $CHECK_T_MULTITIME $CHECK_T_PARAM_DB $CHECK_T_REPEAT
		    $CHECK_T_SI_DB $CHECK_T_STATE $CHECK_T_SYSTEM $CHECK_T_TAGS
		    $CHECK_T_TITLE $COLUMNS $CONS_CONF_T_ID
		    $CONS_CONF_T_PARAM_CONF_DB $CONS_CONF_T_STATE
		    $CONS_DEFAULT_STATE $CONS_DEF_CONS $CONS_DEF_CONS_AUTHOR
		    $CONS_DEF_CONS_EVENT $CONS_DEF_CONS_EXTRAFILE
		    $CONS_DEF_CONS_FORMAT $CONS_DEF_CONS_FREQ
		    $CONS_DEF_CONS_KEYWORDS $CONS_DEF_CONS_STATE
		    $CONS_DEF_CONS_TYPE $CONS_DEF_FILENAME $CONS_DEF_FORMAT
		    $CONS_DEF_PARAM $CONS_DEF_PARAM_DEFAULT
		    $CONS_DEF_PARAM_KEYWORDS $CONS_DESC_DESC $CONS_DESC_FILENAME
		    $CONS_DESC_FORMAT $CONS_DESC_PARAM $CONS_DESC_TITLE
		    $CONS_EVENT_T_ANY $CONS_EVENT_T_EX $CONS_FMT_T_ENV
		    $CONS_FMT_T_XML $CONS_FREQ_T_BOTH $CONS_FREQ_T_FOREACH
		    $CONS_FREQ_T_ONCE $CONS_PROG_FILENAME $CONS_TYPE_T_HANDLER
		    $CONS_TYPE_T_REPORT $CONS_T_AUTHORS $CONS_T_DESC $CONS_T_DIR
		    $CONS_T_EVENT $CONS_T_EXTRAFILES $CONS_T_FORMAT $CONS_T_FREQ
		    $CONS_T_ID $CONS_T_PARAM_DB $CONS_T_STATE $CONS_T_SYSTEM
		    $CONS_T_TITLE $CONS_T_TYPE $CRDS_DEP_T_RESULT
		    $CRDS_DEP_T_STATEMENT $CRDS_EX_T_EXPLANATION $CRDS_EX_T_ID
		    $CRDS_EX_T_REFERENCE $CRDS_EX_T_SEVERITY $CRDS_EX_T_SOLUTION
		    $CRDS_EX_T_SUMMARY $CRDS_RUN_T_CHECK_ID $CRDS_RUN_T_DEPS
		    $CRDS_RUN_T_END $CRDS_RUN_T_EXCEPTIONS $CRDS_RUN_T_HOST_IDS
		    $CRDS_RUN_T_INACTIVE_EX_IDS $CRDS_RUN_T_INST_IDS
		    $CRDS_RUN_T_MULTIHOST $CRDS_RUN_T_MULTITIME
		    $CRDS_RUN_T_PROG_ERR $CRDS_RUN_T_PROG_EXIT_CODE
		    $CRDS_RUN_T_PROG_INFO $CRDS_RUN_T_RC $CRDS_RUN_T_RUN_ID
		    $CRDS_RUN_T_RUN_ID_MAX $CRDS_RUN_T_SOURCE $CRDS_RUN_T_START
		    $CRDS_STORED_FILENAME $CRDS_SUMMARY_T_EXCEPTIONS
		    $CRDS_SUMMARY_T_FAILED_CHKPROG
		    $CRDS_SUMMARY_T_PARAM_ERROR
		    $CRDS_SUMMARY_T_FAILED_SYSINFO
		    $CRDS_SUMMARY_T_NOT_APPLICABLE $CRDS_SUMMARY_T_SUCCESS
		    $CRDS_T_END $CRDS_T_NUM_EX_HIGH $CRDS_T_NUM_EX_INACTIVE
		    $CRDS_T_NUM_EX_LOW $CRDS_T_NUM_EX_MEDIUM
		    $CRDS_T_NUM_EX_REPORTED $CRDS_T_NUM_HOSTS $CRDS_T_NUM_INSTS
		    $CRDS_T_NUM_RUNS_EXCEPTIONS $CRDS_T_NUM_RUNS_FAILED_CHKPROG
		    $CRDS_T_NUM_RUNS_FAILED_SYSINFO
		    $CRDS_T_NUM_RUNS_PARAM_ERROR
		    $CRDS_T_NUM_RUNS_NOT_APPLICABLE $CRDS_T_NUM_RUNS_SCHEDULED
		    $CRDS_T_NUM_RUNS_SUCCESS $CRDS_T_RUNS $CRDS_T_START
		    $DB_ACTIVE_PROFILE_FILENAME $DB_CHECK_CACHE_FILENAME
		    $DB_CHECK_DIR $DB_CONSUMER_CACHE_FILENAME $DB_CONSUMER_DIR
		    $DB_INSTALL_PERM_DIR $DB_INSTALL_PERM_EXEC
		    $DB_INSTALL_PERM_NON_EXEC $DB_PROFILE_CACHE_FILENAME
		    $DB_PROFILE_DIR $DEFAULT_PROFILE_DESC $DEFAULT_PROFILE_ID
		    $DEP_T_DEP $DEP_T_EXPR $EXCEPTION_T_EXPLANATION
		    $EXCEPTION_T_ID $EXCEPTION_T_REFERENCE $EXCEPTION_T_SEVERITY
		    $EXCEPTION_T_SOLUTION $EXCEPTION_T_STATE
		    $EXCEPTION_T_SUMMARY $EXCEPTION_T_VARIABLES $EX_CONF_T_ID
		    $EX_CONF_T_SEVERITY $EX_CONF_T_STATE $INI_ASSIGN_KEY
		    $INI_ASSIGN_LINE $INI_ASSIGN_VALUE $INI_BOOL_EXPR
		    $INI_BOOL_LINE $INI_FILENAME $INI_SECTIONS $INI_SEC_CONTENT
		    $INI_SEC_LINE $INI_SEC_TYPE $INI_TEXT_LINE $INI_TEXT_TEXT
		    $INI_TYPE_ASSIGNMENT $INI_TYPE_BOOLEAN $INI_TYPE_TEXT
		    $LNXHCRC_ID_T_DB_CACHING $LNXHCRC_ID_T_DB_PATH $MATCH_ID
		    $MATCH_ID_CHAR $MATCH_ID_WILDCARD $PARAM_CONF_T_ID
		    $PARAM_CONF_T_VALUE $PARAM_T_DESC $PARAM_T_ID $PARAM_T_VALUE
		    $PROFILE_DB_T_ACTIVE_ID $PROFILE_DB_T_DB
		    $PROFILE_T_CHECK_CONF_DB $PROFILE_T_CONS_CONF_DB
		    $PROFILE_T_DESC $PROFILE_T_FILENAME $PROFILE_T_HOSTS
		    $PROFILE_T_ID $PROFILE_T_MODIFIED $PROFILE_T_SYSTEM
		    $PROP_EXP_ALWAYS $PROP_EXP_NEVER $PROP_EXP_NO_PRIO
		    $PROP_EXP_PRIO $PROP_NS_T_FN_GET_IDS
		    $PROP_NS_T_FN_GET_IDS_SELECTED $PROP_NS_T_FN_ID_IS_VALID
		    $PROP_NS_T_REGEXP $PROP_NS_T_TYPE $RC_T_FAILED $RC_T_OK
		    $SEVERITY_T_HIGH $SEVERITY_T_LOW $SEVERITY_T_MEDIUM
		    $SIDS_HOST_T_ID $SIDS_HOST_T_ITEMS $SIDS_HOST_T_SYSVAR_DB
		    $SIDS_INST_T_HOSTS $SIDS_INST_T_ID $SIDS_ITEM_T_DATA
		    $SIDS_ITEM_T_DATA_ID $SIDS_ITEM_T_END_TIME
		    $SIDS_ITEM_T_ERR_DATA $SIDS_ITEM_T_EXIT_CODE
		    $SIDS_ITEM_T_START_TIME $SIDS_STORED_FILENAME $SIDS_T_INSTS
		    $SI_CONF_T_DATA $SI_CONF_T_ID $SI_CONF_T_TYPE
		    $SI_FILE_DATA_T_FILENAME $SI_FILE_DATA_T_USER
		    $SI_PROG_DATA_T_CMDLINE $SI_PROG_DATA_T_EXTRAFILES
		    $SI_PROG_DATA_T_IGNORERC $SI_PROG_DATA_T_USER
		    $SI_REC_CONF_T_DURATION $SI_REC_DATA_T_DURATION
		    $SI_REC_DATA_T_EXTRAFILES $SI_REC_DATA_T_START
		    $SI_REC_DATA_T_STOP $SI_REC_DATA_T_USER $SI_REF_DATA_T_CHECK
		    $SI_REF_DATA_T_SYSINFO $SI_TYPE_T_EXT $SI_TYPE_T_FILE
		    $SI_TYPE_T_PROG $SI_TYPE_T_REC $SI_TYPE_T_REF $SPEC_T_ID
		    $SPEC_T_KEY $SPEC_T_UNKNOWN $SPEC_T_WILDCARD $STATE_T_ACTIVE
		    $STATE_T_INACTIVE $STATS_STORED_FILENAME
		    $STAT_T_CHECK_STATS_DB $SYSINFO_T_DATA $SYSINFO_T_ID
		    $SYSINFO_T_TYPE $SYSVAR_DIRECTORY $UDATA_DIRECTORY
		    $UDATA_ENV);


#
# Misc constants
#

# Character range for matching a single identifier char
our $MATCH_ID_CHAR 		= "a-z0-9_";

# Regexp for matching identifiers
our $MATCH_ID 			= "[$MATCH_ID_CHAR]+";

# Regexpt for matching identifier wildcards
our $MATCH_ID_WILDCARD 		= "[$MATCH_ID_CHAR\\?\\*]+";

# Path to the cat tool
our $CAT_TOOL			= "/bin/cat";

# Name of environment variable which lnxhc passes to checks and which contains
# the path to the check directory
our $CHECK_DIR_VAR		= 'LNXHC_CHECK_DIR';

# Enumeration of result codes

# Failed
our $RC_T_FAILED		= 0;
# Ok
our $RC_T_OK			= 1;


# Activation states
# Enumeration enum state_t

# Entity is not active
our $STATE_T_INACTIVE		= 0;
# Entity is active
our $STATE_T_ACTIVE		= 1;


# Severity levels
# Enumeration enum severity_t

# Low severity
our $SEVERITY_T_LOW		= 0;
# Medium severity
our $SEVERITY_T_MEDIUM		= 1;
# High severity
our $SEVERITY_T_HIGH		= 2;


# Actual number of characters in one output line
our $COLUMNS;

# ID specification types

# Unknown ID specification
our $SPEC_T_UNKNOWN		= 0;
# Specification as an ID
our $SPEC_T_ID			= 1;
# Specification is an ID wildcard pattern
our $SPEC_T_WILDCARD		= 2;
# Specification is a KEY=/!=VALUE statement
our $SPEC_T_KEY			= 3;



#
# Ini constants
#

# Enumeration of section types
our $INI_TYPE_ASSIGNMENT	= 0;
our $INI_TYPE_BOOLEAN		= 1;
our $INI_TYPE_TEXT		= 2;

# Enumeration of section data fields
our $INI_SEC_LINE		= 0;
our $INI_SEC_TYPE		= 1;
our $INI_SEC_CONTENT		= 2;

# Enumeration of section content data fields for sections containing
# keyword-value assignments
our $INI_ASSIGN_LINE		= 0;
our $INI_ASSIGN_KEY		= 1;
our $INI_ASSIGN_VALUE		= 2;

# Enumeration of section content data fields for sections containing
# boolean expressions
our $INI_BOOL_LINE		= 0;
our $INI_BOOL_EXPR		= 1;

# Enumeration of section content data fields for sections containing text
our $INI_TEXT_LINE		= 0;
our $INI_TEXT_TEXT		= 1;

# Enumeration of ini format data fields
our $INI_FILENAME		= 0;
our $INI_SECTIONS		= 1;



#
# Check constants
#

# Check parameter data
# Enumeration of data fields for struct param_t

# Parameter ID
our $PARAM_T_ID			= 0;	# string
# Parameter description
our $PARAM_T_DESC		= 1;	# string
# Default parameter value
our $PARAM_T_VALUE		= 2;	# string


# Dependency data
# Enumeration of data fields for struct dep_t

# Dependency expression in human-readable form
our $DEP_T_DEP			= 0;	# string
# Dependency expression in internal representation
our $DEP_T_EXPR			= 1;	# struct expr_t


# Exception data
# Enumeration of data fields for struct exception_t

# Exception ID
our $EXCEPTION_T_ID		= 0;	# string
# Exception message summary
our $EXCEPTION_T_SUMMARY	= 1;	# string
# Exception message explanation
our $EXCEPTION_T_EXPLANATION	= 2;	# string
# Exception message solution
our $EXCEPTION_T_SOLUTION	= 3;	# string
# Exception message reference
our $EXCEPTION_T_REFERENCE	= 4;	# string
# Default severity
our $EXCEPTION_T_SEVERITY	= 5;	# enum severity_t
# Default activation state
our $EXCEPTION_T_STATE		= 6;	# enum state_t
# Referenced exception variables
our $EXCEPTION_T_VARIABLES	= 7;	# string[]


# Data for sysinfo item type "file"
# Enumeration of data fields for struct si_file_data_t

# Path to file
our $SI_FILE_DATA_T_FILENAME	= 0;	# string
# User ID to use for file access
our $SI_FILE_DATA_T_USER	= 1;	# string


# Data for sysinfo item type "program"
# Enumeration of data fields for struct si_prog_data_t

# Program command and parameters
our $SI_PROG_DATA_T_CMDLINE	= 0;	# string
# User ID to use for program execution
our $SI_PROG_DATA_T_USER	= 1;	# string
# Flag indicating if a non-zero exit code should be ignored
our $SI_PROG_DATA_T_IGNORERC	= 2;	# bool
# Extra files
our $SI_PROG_DATA_T_EXTRAFILES	= 3;	# string[]


# Data for sysinfo item type "record"
# Enumeration of data fields for struct si_rec_data_t

# Start program command and parameters
our $SI_REC_DATA_T_START	= 0;	# string
# Stop program command and parameters
our $SI_REC_DATA_T_STOP		= 1;	# string
# Default record duration
our $SI_REC_DATA_T_DURATION	= 2;	# string
# User ID to use for program execution
our $SI_REC_DATA_T_USER		= 3;	# string
# Extra files
our $SI_REC_DATA_T_EXTRAFILES	= 4;	# string[]


# Data for sysinfo item type "reference"
# Enumeration of data fields for struct si_ref_data_t

# Check ID which provides the referenced sysinfo item
our $SI_REF_DATA_T_CHECK	= 0;	# string
# Sysinfo ID of the referenced item
our $SI_REF_DATA_T_SYSINFO	= 1;	# string


# Type-dependent sysinfo data
# Sysinfo data types
# Enumeration enum si_type_t
# Sysinfo item type file
our $SI_TYPE_T_FILE		= 0;
# Sysinfo item type program
our $SI_TYPE_T_PROG		= 1;
# Sysinfo item type record
our $SI_TYPE_T_REC		= 2;
# Sysinfo item type reference
our $SI_TYPE_T_REF		= 3;
# Sysinfo item type external
our $SI_TYPE_T_EXT		= 4;


# Sysinfo data
# Enumeration of data fields for struct sysinfo_t

# Sysinfo ID
our $SYSINFO_T_ID		= 0;	# string
# Sysinfo item type
our $SYSINFO_T_TYPE		= 1;	# enum si_type_t
# Type-dependent data
our $SYSINFO_T_DATA		= 2;	# one of: struct si_file_data_t
					#	  struct si_prog_data_t
					#	  struct si_rec_data_t
					#	  struct si_ref_data_t


# Check data
# Enumeration of data fields for struct check_t

# Check ID
our $CHECK_T_ID			= 0;	# string
# Check title
our $CHECK_T_TITLE		= 1;	# string
# Check description
our $CHECK_T_DESC		= 2;	# string
# E-mail address of the check author(s)
our $CHECK_T_AUTHORS		= 3;	# string[]
# Tags describing this check
our $CHECK_T_TAGS		= 4;	# string[]
# Default activation state
our $CHECK_T_STATE		= 5;	# enum state_t
# Default repeat interval
our $CHECK_T_REPEAT		= 6;	# string
# Dependencies
our $CHECK_T_DEPS		= 7;	# struct dep_t[]
# Parameters
our $CHECK_T_PARAM_DB		= 8;	# string -> struct param_t
# Exceptions
our $CHECK_T_EX_DB		= 9;	# string -> struct exception_t
# Sysinfo items
our $CHECK_T_SI_DB		= 10;	# string -> struct sysinfo_t
# Multihost flag
our $CHECK_T_MULTIHOST		= 11;	# bool
# Multitime flag
our $CHECK_T_MULTITIME		= 12;	# bool
# Check directory
our $CHECK_T_DIR		= 13;	# string
# Component being checked
our $CHECK_T_COMPONENT		= 14;	# string
# Extra files
our $CHECK_T_EXTRAFILES		= 15;	# string[]
# Flag indicating if this check was read from a system-wide directory
our $CHECK_T_SYSTEM		= 16;	# bool


# File name for check program file
our $CHECK_PROG_FILENAME	= "check";
# File name for check definitions file
our $CHECK_DEF_FILENAME		= "definitions";
# File name for check descriptions file
our $CHECK_DESC_FILENAME	= "descriptions";
# File name for check exceptions file
our $CHECK_EX_FILENAME		= "exceptions";

# Section names for check definitions file

# Name of ini file section defining check global settings
our $CHECK_DEF_CHECK		= "check";
# Keywords recognized in a check section
our $CHECK_DEF_CHECK_AUTHOR	= "author";
our $CHECK_DEF_CHECK_STATE	= "state";
our $CHECK_DEF_CHECK_REPEAT	= "repeat";
our $CHECK_DEF_CHECK_MULTIHOST	= "multihost";
our $CHECK_DEF_CHECK_MULTITIME	= "multitime";
our $CHECK_DEF_CHECK_TAG	= "tag";
our $CHECK_DEF_CHECK_COMPONENT	= "component";
our $CHECK_DEF_CHECK_EXTRAFILE	= "extrafile";
# Specify if assignment is mandatory
our $CHECK_DEF_CHECK_KEYWORDS = {
	$CHECK_DEF_CHECK_AUTHOR		=> 1,
	$CHECK_DEF_CHECK_STATE		=> 0,
	$CHECK_DEF_CHECK_REPEAT		=> 0,
	$CHECK_DEF_CHECK_MULTIHOST	=> 0,
	$CHECK_DEF_CHECK_MULTITIME	=> 0,
	$CHECK_DEF_CHECK_TAG		=> 0,
	$CHECK_DEF_CHECK_COMPONENT	=> 1,
	$CHECK_DEF_CHECK_EXTRAFILE		=> 0,
};

# Name of ini file section defining check dependencies
our $CHECK_DEF_DEPS		= "deps";

# Name of ini file section defining a check parameter
our $CHECK_DEF_PARAM		= "param";
# Keywords recognized in a parameter section
our $CHECK_DEF_PARAM_DEFAULT	= "default";
# Specify if assignment is mandatory
our $CHECK_DEF_PARAM_KEYWORDS = {
	$CHECK_DEF_PARAM_DEFAULT	=> 0,
};

# Name of ini file section defining a check exception
our $CHECK_DEF_EX		= "exception";
# Keywords recognized in an exception section
our $CHECK_DEF_EX_STATE		= "state";
our $CHECK_DEF_EX_SEVERITY	= "severity";
# Specify if assignment is mandatory
our $CHECK_DEF_EX_KEYWORDS = {
	$CHECK_DEF_EX_STATE		=> 0,
	$CHECK_DEF_EX_SEVERITY		=> 1,
};

# Name of ini file section defining a check sysinfo item
our $CHECK_DEF_SI		= "sysinfo";
# Keywords recognized in a file type sysinfo section
our $CHECK_DEF_SI_FILE_FILE	= "file";
our $CHECK_DEF_SI_FILE_USER	= "user";
# Specify if assignment is mandatory
our $CHECK_DEF_SI_FILE_KEYWORDS = {
	$CHECK_DEF_SI_FILE_FILE		=> 1,
	$CHECK_DEF_SI_FILE_USER		=> 0,
};

# Keywords recognized in a program type sysinfo section
our $CHECK_DEF_SI_PROG_PROGRAM		= "program";
our $CHECK_DEF_SI_PROG_USER		= "user";
our $CHECK_DEF_SI_PROG_IGNORERC		= "ignorerc";
our $CHECK_DEF_SI_PROG_EXTRAFILE	= "extrafile";
# Specify if assignment is mandatory
our $CHECK_DEF_SI_PROG_KEYWORDS = {
	$CHECK_DEF_SI_PROG_PROGRAM	=> 1,
	$CHECK_DEF_SI_PROG_USER		=> 0,
	$CHECK_DEF_SI_PROG_IGNORERC	=> 0,
	$CHECK_DEF_SI_PROG_EXTRAFILE	=> 0,
};

# Keywords recognized in a record type sysinfo section
our $CHECK_DEF_SI_REC_START	= "start";
our $CHECK_DEF_SI_REC_STOP	= "stop";
our $CHECK_DEF_SI_REC_DURATION	= "duration";
our $CHECK_DEF_SI_REC_USER	= "user";
our $CHECK_DEF_SI_REC_EXTRAFILE	= "extrafile";
# Specify if assignment is mandatory
our $CHECK_DEF_SI_REC_KEYWORDS = {
	$CHECK_DEF_SI_REC_START		=> 1,
	$CHECK_DEF_SI_REC_STOP		=> 1,
	$CHECK_DEF_SI_REC_DURATION	=> 1,
	$CHECK_DEF_SI_REC_USER		=> 0,
	$CHECK_DEF_SI_REC_EXTRAFILE	=> 0,
};

# Keywords recognized in a reference type sysinfo section
our $CHECK_DEF_SI_REF_REF	= "ref";
# Specify if assignment is mandatory
our $CHECK_DEF_SI_REF_KEYWORDS = {
	$CHECK_DEF_SI_REF_REF		=> 1,
};

# Keywords recognized in an external type sysinfo section
our $CHECK_DEF_SI_EXT_EXTERNAL	= "external";
# Specify if assignment is mandatory
our $CHECK_DEF_SI_EXT_KEYWORDS = {
	$CHECK_DEF_SI_EXT_EXTERNAL	=> 1,
};

# File format for check definitions file
our $CHECK_DEF_FORMAT = [
	# Type definitions
	{
		$CHECK_DEF_CHECK	=> $INI_TYPE_ASSIGNMENT,
		$CHECK_DEF_DEPS		=> $INI_TYPE_BOOLEAN,
		$CHECK_DEF_PARAM	=> $INI_TYPE_ASSIGNMENT,
		$CHECK_DEF_EX		=> $INI_TYPE_ASSIGNMENT,
		$CHECK_DEF_SI		=> $INI_TYPE_ASSIGNMENT,
	},
	# Mandatory sections
	{
		$CHECK_DEF_CHECK	=> 1,
	},
	# Strict flag
	1,
];

# Section names for check description file

# Name of ini file section containing the check title
our $CHECK_DESC_TITLE		= "title";
# Name of ini file section containing the check description
our $CHECK_DESC_DESC		= "description";
# Name of ini file section containing a check parameter description
our $CHECK_DESC_PARAM		= "param";

# File format for check description file
our $CHECK_DESC_FORMAT = [
	# Type definitions
	{
		$CHECK_DESC_TITLE	=> $INI_TYPE_TEXT,
		$CHECK_DESC_DESC	=> $INI_TYPE_TEXT,
		$CHECK_DESC_PARAM	=> $INI_TYPE_TEXT,
	},
	# Mandatory sections
	{
		$CHECK_DESC_TITLE	=> 1,
		$CHECK_DESC_DESC	=> 1,
	},
	# Strict flag
	1,
];

# Section names for exceptions file

# Name of ini file section containing the exception summary
our $CHECK_EX_SUMMARY		= "summary";
# Name of ini file section containing the exception explanation
our $CHECK_EX_EXPLANATION	= "explanation";
# Name of ini file section containing the exception solution
our $CHECK_EX_SOLUTION		= "solution";
# Name of ini file section containing the exception reference
our $CHECK_EX_REFERENCE		= "reference";

# File format for exceptions file
our $CHECK_EX_FORMAT = [
	# Type definitions
	{
		$CHECK_EX_SUMMARY	=>  $INI_TYPE_TEXT,
		$CHECK_EX_EXPLANATION	=>  $INI_TYPE_TEXT,
		$CHECK_EX_SOLUTION	=>  $INI_TYPE_TEXT,
		$CHECK_EX_REFERENCE	=>  $INI_TYPE_TEXT,
	},
	# Mandatory sections
	{
	},
	# Strict flag
	1,
];

# Default check activation state
our $CHECK_DEFAULT_STATE		= $STATE_T_ACTIVE;

# Default check repeat interval
our $CHECK_DEFAULT_REPEAT		= "";

# Check program exit code interpreted as FAILED DEPENDENCY
our $CHECK_PROG_FAILED_DEP_CODE		= 64;

# Check program exit code interpreted as FAILED/INVALID PARAMETER VALUE
our $CHECK_PROG_PARAM_ERROR_CODE	= 65;



#
# Consumer constants
#

# Format in which input data is passed to the consumer program
# Enumeration (enum cons_fmt_t)

# Data is in XML format passed through standard input stream
our $CONS_FMT_T_XML		= 0;
# Data is passed in environment variables
our $CONS_FMT_T_ENV		= 1;


# Frequency at which the consumer program should be called
# Enumeration (enum cons_freq_t)

# Call for each check that finished
our $CONS_FREQ_T_FOREACH	= 0;
# Call once after all checks finished
our $CONS_FREQ_T_ONCE		= 1;
# Call for each check and again after all checks finished
our $CONS_FREQ_T_BOTH		= 2;


# Events after which the consumer program should be called
# Enumeration (enum cons_event_t)

# Call only after a check ID identified exceptions
our $CONS_EVENT_T_EX		= 0;
# Call anytime a check finished
our $CONS_EVENT_T_ANY		= 1;


# Type implemented by the consumer program
# Enumeration (enum cons_type_t)

# Consumer implements arbitrary processing
our $CONS_TYPE_T_HANDLER	= 0;
# Consumer generates report on standard output stream
our $CONS_TYPE_T_REPORT		= 1;


# Consumer data
# Enumeration of data fields for struct cons_t

# Consumer ID
our $CONS_T_ID			= 0;	# string
# Consumer title
our $CONS_T_TITLE		= 1;	# string
# Consumer description
our $CONS_T_DESC		= 2;	# string
# E-mail address of the consumer author
our $CONS_T_AUTHORS		= 3;	# string[]
# Format in which input data is passed to the consumer program
our $CONS_T_FORMAT		= 4;	# enum cons_fmt_t
# Frequency at which the consumer program should be called
our $CONS_T_FREQ		= 5;	# enum cons_freq_t
# Events after which the consumer program should be called
our $CONS_T_EVENT		= 6;	# enum cons_event_t
# Type implemented by the consumer program
our $CONS_T_TYPE		= 7;	# enum cons_type_t
# Parameter definitions
our $CONS_T_PARAM_DB		= 8;	# string -> struct param_t
# Consumer directory
our $CONS_T_DIR			= 9;	# string
# Default activation state
our $CONS_T_STATE		= 10;	# enum state_t
# Extra files
our $CONS_T_EXTRAFILES		= 11;	# string[]
# Flag indicating if this consumer was read from a system-wide directory
our $CONS_T_SYSTEM		= 12;	# bool

# File name for consumer program file
our $CONS_PROG_FILENAME		= "consumer";
# File name for consumer definitions file
our $CONS_DEF_FILENAME		= "definitions";
# File name for consumer descriptions file
our $CONS_DESC_FILENAME		= "descriptions";

# Section names for consumer definitions file

# Name of ini file section defining consumer global settings
our $CONS_DEF_CONS		= "consumer";
# Keywords recognized in consumer section
our $CONS_DEF_CONS_AUTHOR	= "author";
our $CONS_DEF_CONS_FORMAT	= "format";
our $CONS_DEF_CONS_FREQ		= "frequency";
our $CONS_DEF_CONS_EVENT	= "event";
our $CONS_DEF_CONS_TYPE		= "type";
our $CONS_DEF_CONS_STATE	= "state";
our $CONS_DEF_CONS_EXTRAFILE	= "extrafile";
# Specify if assignment is mandatory
our $CONS_DEF_CONS_KEYWORDS = {
	$CONS_DEF_CONS_AUTHOR		=> 1,
	$CONS_DEF_CONS_FORMAT		=> 1,
	$CONS_DEF_CONS_FREQ		=> 1,
	$CONS_DEF_CONS_EVENT		=> 1,
	$CONS_DEF_CONS_TYPE		=> 1,
	$CONS_DEF_CONS_STATE		=> 0,
	$CONS_DEF_CONS_EXTRAFILE	=> 0,
};

# Name of ini file section defining a consumer parameter
our $CONS_DEF_PARAM		= "param";
# Keywords recognized in a parameter section
our $CONS_DEF_PARAM_DEFAULT	= "default";
# Specify if assignment is mandatory
our $CONS_DEF_PARAM_KEYWORDS = {
	$CONS_DEF_PARAM_DEFAULT		=> 0,
};

# File format for consumer definitions file
our $CONS_DEF_FORMAT = [
	# Type definitions
	{
		$CONS_DEF_CONS		=> $INI_TYPE_ASSIGNMENT,
		$CONS_DEF_PARAM		=> $INI_TYPE_ASSIGNMENT,
	},
	# Mandatory sections
	{
		$CONS_DEF_CONS		=> 1,
	},
	# Strict flag
	1,
];

# Section names for consumer description file

# Name of ini file section containing the consumer title
our $CONS_DESC_TITLE		= "title";
# Name of ini file section containing the consumer description
our $CONS_DESC_DESC		= "description";
# Name of ini file section containing a consumer parameter description
our $CONS_DESC_PARAM		= "param";

# File format for consumer description file
our $CONS_DESC_FORMAT = [
	# Type definitions
	{
		$CONS_DESC_TITLE	=> $INI_TYPE_TEXT,
		$CONS_DESC_DESC		=> $INI_TYPE_TEXT,
		$CONS_DESC_PARAM	=> $INI_TYPE_TEXT,
	},
	# Mandatory sections
	{
		$CHECK_DESC_TITLE	=> 1,
		$CHECK_DESC_DESC	=> 1,
	},
	# Strict flag
	1,
];

# Default consumer activation state
our $CONS_DEFAULT_STATE		= $STATE_T_INACTIVE;



#
# Config constants
#

# Parameter configuration
# Enumeration of data fields for struct param_conf_t

# Parameter ID
our $PARAM_CONF_T_ID		= 0;	# string
# Parameter value
our $PARAM_CONF_T_VALUE		= 1;	# string


# Exception configuration
# Enumeration of data fields for struct ex_conf_t

# Exception ID
our $EX_CONF_T_ID		= 0;	# string
# Exception severity
our $EX_CONF_T_SEVERITY		= 1;	# severity_t
# Exception activation state
our $EX_CONF_T_STATE		= 2;	# state_t


# Sysinfo record type configuration
# Enumeration of data fields for struct si_rec_conf_t

# Record duration
our $SI_REC_CONF_T_DURATION     = 0;    # string


# Sysinfo configuration
# Enumeration of data fields for struct si_conf_t

# Sysinfo ID
our $SI_CONF_T_ID               = 0;    # string
# Sysinfo item type
our $SI_CONF_T_TYPE             = 1;    # si_type_t
# Sysinfo type dependent configuration
our $SI_CONF_T_DATA             = 2;    # one of: struct si_rec_conf_t


# Check configuration data
# Enumeration of data fields for struct check_conf_t

# Check ID
our $CHECK_CONF_T_ID		= 0;	# string
# Check activation state
our $CHECK_CONF_T_STATE		= 1;	# state_t
# Check repeat interval
our $CHECK_CONF_T_REPEAT	= 2;	# string
# Parameter configuration
our $CHECK_CONF_T_PARAM_CONF_DB	= 3;	# string -> struct param_conf_t
# Exception configuration
our $CHECK_CONF_T_EX_CONF_DB	= 4;	# string -> struct ex_conf_t
# Sysinfo configuration
our $CHECK_CONF_T_SI_CONF_DB	= 5;	# string -> struct si_conf_t


# Consumer configuration data
# Enumeration of data fields for struct cons_conf_t

# Consumer ID
our $CONS_CONF_T_ID		= 0;	# string
# Consumer activation state
our $CONS_CONF_T_STATE		= 1;	# state_t
# Parameter configuration
our $CONS_CONF_T_PARAM_CONF_DB	= 2;	# string -> struct param_conf_t


# Profile data
# Enumeration of data fields for struct profile_t

# Profile ID
our $PROFILE_T_ID		= 0;	# string
# Profile description
our $PROFILE_T_DESC		= 1;	# string
# Host list
our $PROFILE_T_HOSTS		= 2;	# string[]
# Check configuration data
our $PROFILE_T_CHECK_CONF_DB	= 3;	# string -> struct check_conf_t
# Consumer configuration data
our $PROFILE_T_CONS_CONF_DB	= 4;	# string -> struct cons_conf_t
# Profile filename
our $PROFILE_T_FILENAME		= 5;	# string
# Flag indicating if this profile was read from a system-wide directory
our $PROFILE_T_SYSTEM		= 6;	# bool
# Flag indicating if this profile was modified
our $PROFILE_T_MODIFIED		= 7;	# bool

# Profile DB data
# Enumeration of data fields for struct profile_db_t

# Profile DB
our $PROFILE_DB_T_DB		= 0;	# string -> struct profile_t
# Active profile ID
our $PROFILE_DB_T_ACTIVE_ID	= 1;	# string


# Profile ID of the default profile
our $DEFAULT_PROFILE_ID		= "default";
# Profile description of the default profile
our $DEFAULT_PROFILE_DESC	= "Default configuration profile";



#
# CheckRun constants
#

# Name for stored check result data set
our $CRDS_STORED_FILENAME		= "results.dat";


# Summary check run result types
# Enumeration (enum crds_summary_t)

# Check ran successfully without exceptions
our $CRDS_SUMMARY_T_SUCCESS		= 0;
# Check ran successfully with exceptions
our $CRDS_SUMMARY_T_EXCEPTIONS		= 1;
# Check failed to run because it is not applicable
our $CRDS_SUMMARY_T_NOT_APPLICABLE	= 2;
# Check failed to run because of missing system information
our $CRDS_SUMMARY_T_FAILED_SYSINFO	= 3;
# Check failed to run because of check program errors
our $CRDS_SUMMARY_T_FAILED_CHKPROG	= 4;
# Check failed to run because of check parameter errors
our $CRDS_SUMMARY_T_PARAM_ERROR		= 5;


# Dependency result
# Enumeration of data fields for struct crds_dep_t

# Statement for this dependency
our $CRDS_DEP_T_STATEMENT		= 0;	# string
# Result for this dependency
our $CRDS_DEP_T_RESULT			= 1;	# bool


# Exception result
# Enumeration of data fields for struct crds_ex_t

# Exception ID
our $CRDS_EX_T_ID			= 0;	# string
# Reported severity
our $CRDS_EX_T_SEVERITY			= 1;	# enum severity_t
# Exception message summary
our $CRDS_EX_T_SUMMARY			= 2;	# string
# Exception message explanation
our $CRDS_EX_T_EXPLANATION		= 3;	# string
# Exception message solution
our $CRDS_EX_T_SOLUTION			= 4;	# string
# Exception message reference
our $CRDS_EX_T_REFERENCE		= 5;	# string


# Result data for one check run
# Enumeration of data fields for struct crds_run_t

# Sequence number of this run
our $CRDS_RUN_T_RUN_ID			= 0;	# unsigned int
# Maximum sequence number in this result data set
our $CRDS_RUN_T_RUN_ID_MAX		= 1;	# unsigned int
# Check ID
our $CRDS_RUN_T_CHECK_ID		= 2;	# string
# Instance ID source list
our $CRDS_RUN_T_INST_IDS		= 3;	# inst_id[]
# Host ID source list
our $CRDS_RUN_T_HOST_IDS		= 4;	# host_id[]
# Boolean matrix which contains a true value for every combination of
# inst_ids index and host_ids index that was used as input for this
# check run
our $CRDS_RUN_T_SOURCE			= 5;	# bool[][]
# Summary check run result
our $CRDS_RUN_T_RC			= 6;	# enum crds_summary_t
# List of dependency results per inst_num and host_num
our $CRDS_RUN_T_DEPS			= 7;	# struct crds_dep_t[][][]
# Check multihost setting
our $CRDS_RUN_T_MULTIHOST		= 8;	# bool
# Check multitime setting
our $CRDS_RUN_T_MULTITIME		= 9;	# bool
# Check program start time
our $CRDS_RUN_T_START			= 10;	# timestamp_t
# Check program end time
our $CRDS_RUN_T_END			= 11;	# timestamp_t
# Check program exit code
our $CRDS_RUN_T_PROG_EXIT_CODE		= 12;	# unsigned int
# Check program informational output
our $CRDS_RUN_T_PROG_INFO		= 13;	# string
# Check program error output
our $CRDS_RUN_T_PROG_ERR		= 14;	# string
# List of IDs of identified inactive exceptions
our $CRDS_RUN_T_INACTIVE_EX_IDS		= 15;	# ex_id_t[]
# Reported exceptions
our $CRDS_RUN_T_EXCEPTIONS		= 16;	# struct crds_ex_t[]


# Check result data set
# Enumeration of data fields for struct crds_t

# Overall check run start time
our $CRDS_T_START			= 0;	# timestamp_t
# Overall check run end time
our $CRDS_T_END				= 1;	# timestamp_t
# Total number of unique instances used for input data
our $CRDS_T_NUM_INSTS			= 2;	# unsigned int
# Total number of unique hosts used for input data
our $CRDS_T_NUM_HOSTS			= 3;	# unsigned int
# Number of scheduled check runs
our $CRDS_T_NUM_RUNS_SCHEDULED		= 4;	# unsigned int
# Number of check runs which completed successfully without exceptions
our $CRDS_T_NUM_RUNS_SUCCESS		= 5;	# unsigned int
# Number of check runs which completed successfully with exceptions
our $CRDS_T_NUM_RUNS_EXCEPTIONS		= 6;	# unsigned int
# Number of check runs which failed because the check was not applicable
our $CRDS_T_NUM_RUNS_NOT_APPLICABLE	= 7;	# unsigned int
# Number of check runs which failed because system information was missing
our $CRDS_T_NUM_RUNS_FAILED_SYSINFO	= 8;	# unsigned int
# Number of check runs which failed because of check program run-time errors
our $CRDS_T_NUM_RUNS_FAILED_CHKPROG	= 9;	# unsigned int
# Number of check runs which failed because of check parameter errors
our $CRDS_T_NUM_RUNS_PARAM_ERROR	= 10,	# unsigned int
# Total number of reported exceptions
our $CRDS_T_NUM_EX_REPORTED		= 11;	# unsigned int
# Number of reported exceptions with low severity
our $CRDS_T_NUM_EX_LOW			= 12;	# unsigned int
# Number of reported exceptions with medium severity
our $CRDS_T_NUM_EX_MEDIUM		= 13;	# unsigned int
# Number of reported exceptions with high severity
our $CRDS_T_NUM_EX_HIGH			= 14;	# unsigned int
# Number of ID identified inactive exceptions
our $CRDS_T_NUM_EX_INACTIVE		= 15;	# unsigned int
# Result data list
our $CRDS_T_RUNS			= 16;	# struct crds_run_t[]



#
# SIDS constants
#

# Name for stored sysinfo data set
our $SIDS_STORED_FILENAME	= "sysinfo.dat";


# Sysinfo data item for a single sysinfo item
# Enumeration of data fields for struct sids_item_t

# Sysinfo data ID
our $SIDS_ITEM_T_DATA_ID	= 0;	# string
# Time of start of sysinfo collection for this item
our $SIDS_ITEM_T_START_TIME	= 1;	# timestamp_t
# Time of end of sysinfo collection for this item
our $SIDS_ITEM_T_END_TIME	= 2;	# timestamp_t
# Summary result code
our $SIDS_ITEM_T_EXIT_CODE	= 3;	# unsigned int
# Sysinfo data
our $SIDS_ITEM_T_DATA		= 4;	# binary_t
# Sysinfo error data
our $SIDS_ITEM_T_ERR_DATA	= 5;	# binary_t


# Sysinfo data for one host
# Enumeration of data fields for struct sids_host_t

# Host on which this data was collected
our $SIDS_HOST_T_ID		= 0;	# string
# System variables
our $SIDS_HOST_T_SYSVAR_DB	= 1;	# string[string]
# Sysinfo item data list
our $SIDS_HOST_T_ITEMS		= 2;	# struct sids_item_t[]


# Sysinfo data for one point in time
# Enumeration of data fields for struct sids_inst_t

# Identifier for this point in time
our $SIDS_INST_T_ID		= 0;	# string
# Sysinfo host data list
our $SIDS_INST_T_HOSTS		= 1;	# struct sids_host_t[]


# Sysinfo data set
# Enumeration of data fields for struct sids_t

# Sysinfo instance data list
our $SIDS_T_INSTS		= 0;	# struct sids_inst_t[]



#
# UData constants
#

# User data directory name
our $UDATA_DIRECTORY		= ".lnxhc";

# Environment variable for specifying the user data directory
our $UDATA_ENV			= "LNXHC_USER_DIR";



#
# CheckDialog constants
#

# Name for stored dialog data
our $CHECK_DIALOG_FILENAME		= "dialog.dat";

# Name of Perl health check program template file
our $CHECK_DIALOG_TEMPL_PERL_CHECK	= "template_perl_check";

# Name of bash health check program template file
our $CHECK_DIALOG_TEMPL_BASH_CHECK	= "template_bash_check";

# Name of python health check program template file
our $CHECK_DIALOG_TEMPL_PYTHON_CHECK	= "template_python_check";

# Name of C health check program template file
our $CHECK_DIALOG_TEMPL_C_CHECK		= "template_c_check";

# Name of C health check Makefile template file
our $CHECK_DIALOG_TEMPL_C_MAKEFILE	= "template_c_makefile";



#
# Stats constants
#

# Name for stored run-time statistics data
our $STATS_STORED_FILENAME		= "stats.dat";

# Per check run-time statistics
# Enumeration of data fields for struct check_stats_t

# Number of times check ran successfully with not exceptions
our $CHECK_STATS_T_RUN_SUCCESS		= 0;	# int
# Number of times check ran successfully and reported exceptions
our $CHECK_STATS_T_RUN_EXCEPTIONS	= 1;	# int
# Number of times dependencies were not met
our $CHECK_STATS_T_RUN_NOT_APPLICABLE	= 2;	# int
# Number of times sysinfo could not be collected
our $CHECK_STATS_T_RUN_FAILED_SYSINFO	= 3;	# int
# Number of times check program run-time error occurred
our $CHECK_STATS_T_RUN_FAILED_CHKPROG	= 4;	# int
# Number of times check parameter error occurred
our $CHECK_STATS_T_RUN_PARAM_ERROR	= 5;    # unsigned int
# Total number of check invocations
our $CHECK_STATS_T_RUN_TOTAL		= 6;	# int

# Number of high-severity exceptions reported
our $CHECK_STATS_T_EX_HIGH		= 7;	# int
# Number of medium-severity exceptions reported
our $CHECK_STATS_T_EX_MEDIUM		= 8;	# int
# Number of low-severity exceptions reported
our $CHECK_STATS_T_EX_LOW		= 9;	# int
# Total number of exceptions reported
our $CHECK_STATS_T_EX_TOTAL		= 10;	# int

# Minimum check run-time
our $CHECK_STATS_T_TIME_MIN		= 11;	# string
# Maximum check run-time
our $CHECK_STATS_T_TIME_MAX		= 12;	# string
# Average check run-time
our $CHECK_STATS_T_TIME_AVG		= 13;	# string


# Statistics data set
# Enumeration of data fields for struct stat_t

# Statistics data per check
our $STAT_T_CHECK_STATS_DB		= 0;	# string -> struct check_stats_t



#
# DB Constants
#

# File permissions for installing executables
our $DB_INSTALL_PERM_EXEC	= 0755;

# File permissions for installing non-executables
our $DB_INSTALL_PERM_NON_EXEC	= 0644;

# File permissions for installing directories
our $DB_INSTALL_PERM_DIR	= 0755;

# Name of directory containing checks
our $DB_CHECK_DIR		= "checks";

# Name of directory containing consumers
our $DB_CONSUMER_DIR		= "consumers";

# Name of directory containing profiles
our $DB_PROFILE_DIR		= "profiles";

# Name of file containing ID of active profile
our $DB_ACTIVE_PROFILE_FILENAME	= ".active";

# Name of file containing cached checks database
our $DB_CHECK_CACHE_FILENAME	= "checks.cache";

# Name of file containing cached consumer database
our $DB_CONSUMER_CACHE_FILENAME	= "consumers.cache";

# Name of file containing cached profile database
our $DB_PROFILE_CACHE_FILENAME	= "profiles.cache";



#
# Prop Constants
#

# Namespace definition
# Textual type of the IDs governed by this namespace
our $PROP_NS_T_TYPE			= 0;
# Regular expression for matching an ID of this namespace
our $PROP_NS_T_REGEXP			= 1;
# Function to get all IDs of this namespace
# fn_get_ids(subkeys, level, create)
# returns: list of IDs
our $PROP_NS_T_FN_GET_IDS		= 2;
# Optional function to get all selected IDs of this namespace
# fn_get_ids_selected(subkeys, level, create)
# returns: list of IDs
our $PROP_NS_T_FN_GET_IDS_SELECTED	= 3;
# Function to check if a specified ID is valid in this namespace
# fn_id_is_valid(subkeys, level, create)
# returns: 1 if ID is valid
our $PROP_NS_T_FN_ID_IS_VALID		= 4;

# Values for the expand parameter of function prop_parse_key
# Never expand incomplete keys
our $PROP_EXP_NEVER			= 0;
# Always expand incomplete keys to all possible sub-key
our $PROP_EXP_ALWAYS			= 1;
# Expansion has priority over literal nodes: if there is a choice between
# expanding a key and using a literal node, choose the expansion only
our $PROP_EXP_PRIO			= 2;
# Expansion has no priority over literal nodes: if there is a choice between
# expanding a key and using a literal node, choose the literal node only
our $PROP_EXP_NO_PRIO			= 3;


#
# LNXHCRC Constants
#

# lnxhcrc item IDs

# Database path list
our $LNXHCRC_ID_T_DB_PATH		= 0;
# Database caching flag
our $LNXHCRC_ID_T_DB_CACHING		= 1;



#
# SysVar Constants
#

# Name of directory containing programs which retrieve system variables
our $SYSVAR_DIRECTORY			= "sysvar";



#
# Global variables
#



#
# Sub-routines
#

#
# _init_columns()
#
# Retrieve number of columns per row of the current terminal.
#
sub _init_columns()
{
	my $winsize = "";
	my $col;
	my $row;
	my $tty;

	# Check bash/user presets
	if (defined($ENV{"COLUMNS"})) {
		$COLUMNS = $ENV{"COLUMNS"};
		return;
	}

	# Query terminal size
	eval {
		local $SIG{__DIE__};
		require 'sys/ioctl.ph';
	};

	if (!defined(&TIOCGWINSZ)) {
		goto out;
	}

	if (!open($tty, "+</dev/tty")) {
		goto out;
	}

	if (!ioctl($tty, &TIOCGWINSZ, $winsize)) {
		close($tty);
		goto out;
	}
	close($tty);

	($row, $col) = unpack('S4', $winsize);

out:
	# Define fallback
	if (!defined($col) || $col == 0) {
		$col = 80;
	}
	$COLUMNS = $col;
	$ENV{"COLUMNS"} = $col;
}



#
# Code entry
#

BEGIN {
	_init_columns();
}

# Indicate successful module initialization
1;
