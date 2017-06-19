#
# LNXHC::DBCheck.pm
#   Linux Health Checker database for checks
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

package LNXHC::DBCheck;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catfile catdir);
use File::Basename qw(dirname);


#
# Local imports
#
use LNXHC::CheckParse qw(check_parse_from_dir);
use LNXHC::Consts qw($CHECK_DEF_FILENAME $CHECK_DESC_FILENAME $CHECK_EX_FILENAME
		     $CHECK_PROG_FILENAME $CHECK_T_DIR $CHECK_T_EXTRAFILES
		     $CHECK_T_EX_DB $CHECK_T_ID $CHECK_T_PARAM_DB
		     $CHECK_T_REPEAT $CHECK_T_SI_DB $CHECK_T_STATE
		     $CHECK_T_SYSTEM $DB_CHECK_CACHE_FILENAME $DB_CHECK_DIR
		     $DB_INSTALL_PERM_DIR $EXCEPTION_T_SEVERITY
		     $EXCEPTION_T_STATE $PARAM_T_VALUE
		     $SI_PROG_DATA_T_EXTRAFILES $SI_REC_DATA_T_DURATION
		     $SI_REC_DATA_T_EXTRAFILES $SI_TYPE_T_PROG $SI_TYPE_T_REC
		     $SYSINFO_T_DATA $SYSINFO_T_TYPE);
use LNXHC::DB qw(db_get_dirs db_get_install_dir db_init db_invalidate_cache);
use LNXHC::Misc qw($opt_system copy_files create_path get_db_scope info3 rm_rf
		   unique);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&db_check_ex_exists &db_check_exists &db_check_get
		    &db_check_get_ex_ids &db_check_get_ex_severity
		    &db_check_get_ex_state &db_check_get_exception
		    &db_check_get_ids &db_check_get_param
		    &db_check_get_param_ids &db_check_get_repeat
		    &db_check_get_si &db_check_get_si_ids
		    &db_check_get_si_rec_duration &db_check_get_si_type
		    &db_check_get_state &db_check_get_sysinfo &db_check_install
		    &db_check_is_empty &db_check_load &db_check_param_exists
		    &db_check_si_exists &db_check_uninstall);


#
# Constants
#


#
# Global variables
#

# Database of installed checks
my $_check_db;

# Version of check database. When checks are added or removed from the
# corresponding directory, this version changes.
my $_check_db_version;


#
# Sub-routines
#

#
# _read_check_db()
#
# Read checks from database.
#
sub _read_check_db()
{
	my $check_dirs = db_get_dirs($DB_CHECK_DIR);
	my %check_db;

	foreach my $dir (@$check_dirs) {
		my ($path, $system) = @$dir;
		my $handle;

		info3("Reading checks from '$path'\n");
		if (!opendir($handle, $path)) {
			info3("Skipping check database at '$path': $!\n");
			next;
		}
		foreach my $subdir (readdir($handle)) {
			my $check;
			my $check_id;

			# Skip . and ..
			if (($subdir eq ".") || ($subdir eq "..")) {
				next;
			}
			info3("  $subdir\n");
			$check = check_parse_from_dir(catdir($path, $subdir));
			$check->[$CHECK_T_SYSTEM] = $system;
			$check_id = $check->[$CHECK_T_ID];
			if (exists($check_db{$check_id})) {
				my $old_check = $check_db{$check_id};

				if ($old_check->[$CHECK_T_DIR] eq
				    $check->[$CHECK_T_DIR]) {
					# A DB path has been specified multiple
					# times
					next;
				}

				warn(<<EOF);
Duplicate definition of check '$check_id' (keeping second one):
  $old_check->[$CHECK_T_DIR] and
  $check->[$CHECK_T_DIR]
EOF
			}
			$check_db{$check_id} = $check;
		}
		closedir($handle);
	}

	return \%check_db;
}

#
# _init_check_db()
#
# Initialize check database.
#
sub _init_check_db()
{
	($_check_db, $_check_db_version) =
		db_init($DB_CHECK_DIR, $DB_CHECK_CACHE_FILENAME,
			 \&_read_check_db);
}

#
# db_check_get(check_id)
#
# Search database for check with given CHECK_ID. Return the check if found,
# undef otherwise.
#
sub db_check_get($)
{
	my ($check_id) = @_;

	# Lazy check database initialization
	_init_check_db() if (!defined($_check_db));

	return $_check_db->{$check_id};
}

#
# db_check_get_state(check_id)
#
# Return default activation state for check CHECK_ID.
#
sub db_check_get_state($)
{
	my ($check_id) = @_;
	my $check = db_check_get($check_id);

	if (!defined($check)) {
		return undef;
	}

	return $check->[$CHECK_T_STATE];
}

#
# db_check_get_repeat(check_id)
#
# Return default repeat setting for check CHECK_ID.
#
sub db_check_get_repeat($)
{
	my ($check_id) = @_;
	my $check = db_check_get($check_id);

	if (!defined($check)) {
		return undef;
	}

	return $check->[$CHECK_T_REPEAT];
}

#
# db_check_get_param(check_id, param_id)
#
# Return default parameter setting for check CHECK_ID and parameter PARAM_ID.
#
sub db_check_get_param($$)
{
	my ($check_id, $param_id) = @_;
	my $check = db_check_get($check_id);
	my $param_db;
	my $param;

	if (!defined($check)) {
		return undef;
	}
	$param_db = $check->[$CHECK_T_PARAM_DB];
	$param = $param_db->{$param_id};
	if (!defined($param)) {
		return undef;
	}

	return $param->[$PARAM_T_VALUE];
}

#
# db_check_get_exception(check_id, ex_id)
#
# Return exception data structure for CHECK_ID and EX_ID.
#
sub db_check_get_exception($$)
{
	my ($check_id, $ex_id) = @_;
	my $check = db_check_get($check_id);
	my $ex_db;

	if (!defined($check)) {
		return undef;
	}
	$ex_db = $check->[$CHECK_T_EX_DB];

	return $ex_db->{$ex_id};
}

#
# db_check_get_ex_severity(check_id, ex_id)
#
# Return default exception severity for check CHECK_ID and exception EX_ID.
#
sub db_check_get_ex_severity($$)
{
	my ($check_id, $ex_id) = @_;
	my $ex = db_check_get_exception($check_id, $ex_id);

	return $ex->[$EXCEPTION_T_SEVERITY];
}

#
# db_check_get_ex_state(check_id, ex_id)
#
# Return default exception state for check CHECK_ID and exception EX_ID.
#
sub db_check_get_ex_state($$)
{
	my ($check_id, $ex_id) = @_;
	my $ex = db_check_get_exception($check_id, $ex_id);

	return $ex->[$EXCEPTION_T_STATE];
}

#
# db_check_get_sysinfo(check_id, si_id)
#
# Return sysinfo data structure for CHECK_ID and SI_ID.
#
sub db_check_get_sysinfo($$)
{
	my ($check_id, $si_id) = @_;
	my $check = db_check_get($check_id);
	my $si_db;

	if (!defined($check)) {
		return undef;
	}
	$si_db = $check->[$CHECK_T_SI_DB];

	return $si_db->{$si_id};
}

#
# db_check_get_si_rec_duration(check_id, si_id)
#
# Return default record duration for check CHECK_ID and sysinfo item SI_ID.
#
sub db_check_get_si_rec_duration($$)
{
	my ($check_id, $si_id) = @_;
	my $si = db_check_get_sysinfo($check_id, $si_id);
	my $data;

	if (!defined($si)) {
		return undef;
	}
	if ($si->[$SYSINFO_T_TYPE] != $SI_TYPE_T_REC) {
		return undef;
	}
	$data = $si->[$SYSINFO_T_DATA];

	return $data->[$SI_REC_DATA_T_DURATION];
}

#
# db_check_get_si_type(check_id, si_id)
#
# Return type of sysinfo item SI_ID of check CHECK_ID.
#
sub db_check_get_si_type($$)
{
	my ($check_id, $si_id) = @_;
	my $si = db_check_get_sysinfo($check_id, $si_id);

	return $si->[$SYSINFO_T_TYPE];
}

#
# db_check_exists(check_id)
#
# Search database for check with given CHECK_ID. Return 1 if found, 0 otherwise.
#
sub db_check_exists($)
{
	my ($check_id) = @_;

	# Lazy check database initialization
	_init_check_db() if (!defined($_check_db));

	# Check if check exists
	if (defined($_check_db->{$check_id})) {
		return 1;
	}

	return 0;
}

#
# db_check_get_ids()
#
# Return list of IDs of checks in database.
#
sub db_check_get_ids()
{
	# Lazy check database initialization
	_init_check_db() if (!defined($_check_db));

	return keys(%{$_check_db});
}

#
# db_check_is_empty()
#
# Return non-zero if there is no check in the database, zero otherwise.
#
sub db_check_is_empty()
{
	# Lazy check database initialization
	_init_check_db() if (!defined($_check_db));

	return !%{$_check_db};
}

#
# db_check_load(directory)
#
# Load check located in DIRECTORY and add it temporarily to database. Return
# the new check on success.
#
sub db_check_load($)
{
	my ($directory) = @_;
	my $check;
	my $check_id;

	# Lazy check database initialization
	_init_check_db() if (!defined($_check_db));

	$check = check_parse_from_dir($directory);
	$check_id = $check->[$CHECK_T_ID];
	if (defined($_check_db->{$check_id})) {
		my $sys = $_check_db->{$check_id}->[$CHECK_T_SYSTEM];
		my $source = "";

		if (defined($sys)) {
			$source = " in ".get_db_scope($sys)." database";
		}

		die("Check '$check_id' already exists$source!\n");
	}

	$_check_db->{$check_id} = $check;

	return $check;
}

#
# _get_check_extrafiles(check)
#
# Return list of all extrafiles specified by CHECK.
#
sub _get_check_extrafiles($)
{
	my ($check) = @_;
	my $si_db = $check->[$CHECK_T_SI_DB];
	my $si_id;
	my $extrafiles;
	my @result;

	# Add extrafiles specified by check section
	$extrafiles = $check->[$CHECK_T_EXTRAFILES];
	push(@result, @$extrafiles);

	# Add extrafiles specified by sysinfo sections
	foreach $si_id (keys(%{$si_db})) {
		my $sysinfo = $si_db->{$si_id};
		my $type = $sysinfo->[$SYSINFO_T_TYPE];
		my $data = $sysinfo->[$SYSINFO_T_DATA];

		$extrafiles = undef;
		if ($type == $SI_TYPE_T_PROG) {
			$extrafiles = $data->[$SI_PROG_DATA_T_EXTRAFILES];
		} elsif ($type == $SI_TYPE_T_REC) {
			$extrafiles = $data->[$SI_REC_DATA_T_EXTRAFILES];
		}
		if (defined($extrafiles)) {
			push(@result, @$extrafiles);
		}
	}

	return unique(@result);
}

#
# _get_check_text_files(check_dir)
#
# Return list of text files found in CHECK_DIR
#
sub _get_check_text_files($)
{
	my ($check_dir) = @_;
	my $dir;
	my @result;
	my $dir_handle;

	# Add text files in top-level directory
	push(@result, $CHECK_DESC_FILENAME, $CHECK_EX_FILENAME);
	opendir($dir_handle, $check_dir) or
		die("Could not read directory '$check_dir'!\n");
	foreach $dir (readdir($dir_handle)) {
		my $rel_file;

		# Skip . and ..
		if ($dir eq "." || $dir eq "..") {
			next;
		}
		# Skip non-directories
		if (!-d catdir($check_dir, $dir)) {
			next;
		}
		# Add localized descriptions file if available
		$rel_file = catfile($dir, $CHECK_DESC_FILENAME);
		if (-e catfile($check_dir, $rel_file)) {
			push(@result, $rel_file);
		}
		# Add localized exceptions file if available
		$rel_file = catfile($dir, $CHECK_EX_FILENAME);
		if (-e catfile($check_dir, $rel_file)) {
			push(@result, $rel_file);
		}
	}
	closedir($dir_handle);

	return @result;
}

#
# _get_check_files(check)
#
# Return list of files associated with CHECK. Filenames are relative to
# check directory.
#
sub _get_check_files($)
{
	my ($check) = @_;
	my $check_dir = $check->[$CHECK_T_DIR];
	my @files;

	# Add check and definitions files
	push(@files, $CHECK_PROG_FILENAME, $CHECK_DEF_FILENAME);

	# Add user-defined files
	push(@files, _get_check_extrafiles($check));

	# Determine list of text files
	push(@files, _get_check_text_files($check_dir));

	return @files;
}

#
# db_check_install(directory)
#
# Add check located in DIRECTORY to database. Return resulting check.
#
sub db_check_install($)
{
	my ($directory) = @_;
	my $install_dir = db_get_install_dir($DB_CHECK_DIR);
	my $check;
	my @files;
	my $check_id;
	my $check_dir;
	my $target;

	# Check if directory exists
	if (!-d $install_dir) {
		create_path($install_dir, $DB_INSTALL_PERM_DIR);
	}
	# Check for write access to check directory
	if (!-w $install_dir) {
		die("Insufficient write permissions for directory ".
		    "'$install_dir'\n");
	}

	# Validate check's correctness
	$check = db_check_load($directory);
	$check_id = $check->[$CHECK_T_ID];
	$check_dir = $check->[$CHECK_T_DIR];

	# Get file list
	@files = _get_check_files($check);

	# Copy files to target
	$target = catfile($install_dir, $check_id);
	copy_files($check_dir, $target, @files);

	# Adjust check attributes
	$check->[$CHECK_T_DIR] = $target;
	$check->[$CHECK_T_SYSTEM] = $opt_system ? 1 : 0;

	# Mark check DB cache as out-of-date
	db_invalidate_cache($DB_CHECK_CACHE_FILENAME);

	return $check;
}

#
# db_check_uninstall(check_id)
#
# Persistently remove check CHECK_ID from database.
#
sub db_check_uninstall($)
{
	my ($check_id) = @_;
	my $check;
	my $check_dir;
	my $system;

	# Check for existence of check
	$check = db_check_get($check_id);
	if (!defined($check)) {
		die("Check '$check_id' not installed!\n");
	}
	$system = $check->[$CHECK_T_SYSTEM];

	# Check for proper database
	if ($system && !$opt_system) {
		die("Cannot remove check '$check_id' from system-wide ".
		    "database without --system!\n");
	} elsif (!$system && $opt_system) {
		die("Cannot remove check '$check_id' from user database with ".
		    "--system!\n");
	}

	# Check for write access to check directory
	$check_dir = $check->[$CHECK_T_DIR];
	if (!-w dirname($check_dir)) {
		die("Insufficient write permissions for directory ".
		    "'".dirname($check_dir)."'\n");
	}

	# Remove files
	rm_rf($check_dir);

	# Remove from database
	delete($_check_db->{$check_id});

	# Make sure check DB cache is reread
	db_invalidate_cache($DB_CHECK_CACHE_FILENAME);
}

#
# db_check_get_param_ids(check_id)
#
# Return list of parameter IDs defined for the check with the specified
# CHECK_ID.
#
sub db_check_get_param_ids($)
{
	my ($check_id) = @_;
	my $check = db_check_get($check_id);
	my $param_db;

	if (!defined($check)) {
		return ();
	}
	$param_db = $check->[$CHECK_T_PARAM_DB];

	return keys(%{$param_db});
}

#
# db_check_param_exists(check_id, param_id)
#
# Return 1 if parameter PARAM_ID exists for check CHECK_ID. Zero otherwise.
#
sub db_check_param_exists($$)
{
	my ($check_id, $param_id) = @_;
	my $check = db_check_get($check_id);
	my $param_db;

	if (!defined($check)) {
		return 0;
	}
	$param_db = $check->[$CHECK_T_PARAM_DB];
	if (!defined($param_db->{$param_id})) {
		return 0;
	}

	return 1;
}

#
# db_check_get_si(check_id, si_id)
#
# Return sysinfo item for the specified CHECK_ID and SI_ID combination.
#
sub db_check_get_si($$)
{
	my ($check_id, $si_id) = @_;
	my $check = db_check_get($check_id);
	my $si_db;

	if (!defined($check)) {
		return undef;
	}
	$si_db = $check->[$CHECK_T_SI_DB];
	if (exists($si_db->{$si_id})) {
		return $si_db->{$si_id};
	}
	return undef;
}

#
# db_check_get_si_ids(check_id)
#
# Return list of sysinfo IDs defined for the check with the specified
# CHECK_ID.
#
sub db_check_get_si_ids($)
{
	my ($check_id) = @_;
	my $check = db_check_get($check_id);
	my $si_db;

	if (!defined($check)) {
		return ();
	}
	$si_db = $check->[$CHECK_T_SI_DB];

	return keys(%{$si_db});
}

#
# db_check_si_exists(check_id, si_id)
#
# Return non-zero if sysinfo SI_ID exists for check CHECK_ID.
#
sub db_check_si_exists($$)
{
	my ($check_id, $si_id) = @_;
	my $check = db_check_get($check_id);
	my $si_db;

	if (!defined($check)) {
		return 0;
	}
	$si_db = $check->[$CHECK_T_SI_DB];
	if (!defined($si_db->{$si_id})) {
		return 0;
	}

	return 1;
}

#
# db_check_get_ex_ids(check_id)
#
# Return list of exception IDs defined for the check with the specified
# CHECK_ID.
#
sub db_check_get_ex_ids($)
{
	my ($check_id) = @_;
	my $check = db_check_get($check_id);
	my $ex_db;

	if (!defined($check)) {
		return ();
	}
	$ex_db = $check->[$CHECK_T_EX_DB];

	return keys(%{$ex_db});
}

#
# db_check_ex_exists(check_id, ex_id)
#
# Return non-zero if exception EX_ID exists for check CHECK_ID.
#
sub db_check_ex_exists($$)
{
	my ($check_id, $ex_id) = @_;
	my $check = db_check_get($check_id);
	my $ex_db;

	if (!defined($check)) {
		return 0;
	}
	$ex_db = $check->[$CHECK_T_EX_DB];
	if (!defined($ex_db->{$ex_id})) {
		return 0;
	}

	return 1;
}


#
# Code entry
#

# Indicate successful module initialization
1;
