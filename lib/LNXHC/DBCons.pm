#
# LNXHC::DBCons.pm
#   Linux Health Checker database for consumers
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

package LNXHC::DBCons;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catfile catdir);
use File::Basename qw(dirname);


#
# Local imports
#
use LNXHC::ConsParse qw(cons_parse_from_dir);
use LNXHC::Consts qw($CONS_DEF_FILENAME $CONS_DESC_FILENAME $CONS_PROG_FILENAME
		     $CONS_T_DIR $CONS_T_EXTRAFILES $CONS_T_ID $CONS_T_PARAM_DB
		     $CONS_T_STATE $CONS_T_SYSTEM $CONS_T_TYPE
		     $DB_CONSUMER_CACHE_FILENAME $DB_CONSUMER_DIR
		     $DB_INSTALL_PERM_DIR $PARAM_T_VALUE);
use LNXHC::DB qw(db_get_dirs db_get_install_dir db_init db_invalidate_cache);
use LNXHC::Misc qw($opt_system copy_files create_path get_db_scope info3 rm_rf);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&db_cons_exists &db_cons_get &db_cons_get_ids
		    &db_cons_get_param &db_cons_get_param_ids &db_cons_get_state
		    &db_cons_get_type &db_cons_install &db_cons_is_empty
		    &db_cons_load &db_cons_param_exists &db_cons_uninstall);


#
# Constants
#


#
# Global variables
#

# Database of installed consumers
my $_cons_db;

# Version of consumer database. When consumers are added or removed from the
# corresponding directory, this version changes.
my $_cons_db_version;


#
# Sub-routines
#

#
# _read_cons_db()
#
# Read consumers from database.
#
sub _read_cons_db()
{
	my $cons_dirs = db_get_dirs($DB_CONSUMER_DIR);
	my %cons_db;

	foreach my $dir (@$cons_dirs) {
		my ($path, $system) = @$dir;
		my $handle;

		info3("Reading consumers from '$path'\n");
		if (!opendir($handle, $path)) {
			info3("Skipping consumer database at '$path': $!\n");
			next;
		}
		foreach my $subdir (readdir($handle)) {
			my $cons;
			my $cons_id;

			# Skip . and ..
			if ($subdir eq "." || $subdir eq "..") {
				next;
			}
			info3("  $subdir\n");
			$cons = cons_parse_from_dir(catdir($path, $subdir));
			$cons->[$CONS_T_SYSTEM] = $system;
			$cons_id = $cons->[$CONS_T_ID];
			if (exists($cons_db{$cons_id})) {
				my $old_cons = $cons_db{$cons_id};

				if ($old_cons->[$CONS_T_DIR] eq
				    $cons->[$CONS_T_DIR]) {
					# A DB path has been specified multiple
					# times
					next;
				}

				warn(<<EOF);
Duplicate definition of consumer '$cons_id' (keeping second one):
  $old_cons->[$CONS_T_DIR] and
  $cons->[$CONS_T_DIR]
EOF
			}
			$cons_db{$cons_id} = $cons;
		}
		closedir($handle);
	}

	return \%cons_db;
}

#
# _init_cons_db()
#
# Init consumer database.
#
sub _init_cons_db()
{
	($_cons_db, $_cons_db_version) =
		db_init($DB_CONSUMER_DIR, $DB_CONSUMER_CACHE_FILENAME,
			 \&_read_cons_db);
}

#
# db_cons_get(cons_id)
#
# Search database for consumer with given CONS_ID. Return the consumer if found,
# undef otherwise.
#
sub db_cons_get($)
{
	my ($cons_id) = @_;

	# Lazy consumer database initialization
	_init_cons_db() if (!defined($_cons_db));

	return $_cons_db->{$cons_id};
}

#
# db_cons_get_type(cons_id)
#
# Return type of consumer CONS_ID.
#
sub db_cons_get_type($)
{
	my ($cons_id) = @_;
	my $cons = db_cons_get($cons_id);

	return $cons->[$CONS_T_TYPE];
}

#
# db_cons_get_state(cons_id)
#
# Return default activation state for consumer CONS_ID.
#
sub db_cons_get_state($)
{
	my ($cons_id) = @_;
	my $cons = db_cons_get($cons_id);

	return $cons->[$CONS_T_STATE];
}

#
# db_cons_get_param(cons_id, param_id)
#
# Return default parameter setting for consumer CONS_ID and parameter PARAM_ID.
#
sub db_cons_get_param($$)
{
	my ($cons_id, $param_id) = @_;
	my $cons = db_cons_get($cons_id);
	my $param_db;
	my $param;

	if (!defined($cons)) {
		return undef;
	}
	$param_db = $cons->[$CONS_T_PARAM_DB];
	$param = $param_db->{$param_id};
	if (!defined($param)) {
		return undef;
	}

	return $param->[$PARAM_T_VALUE];
}

#
# db_cons_exists(cons_id)
#
# Search database for consumer with given CONS_ID. Return 1 if found, 0
# otherwise.
#
sub db_cons_exists($)
{
	my ($cons_id) = @_;

	# Lazy consumer database initialization
	_init_cons_db() if (!defined($_cons_db));

	# Check if consumer exists
	if (defined($_cons_db->{$cons_id})) {
		return 1;
	}
	return 0;
}

# db_cons_get_ids()
#
# Return list of IDs of consumers in database.
#
sub db_cons_get_ids()
{
	# Lazy consumer database initialization
	_init_cons_db() if (!defined($_cons_db));

	return keys(%{$_cons_db});
}

#
# db_cons_is_empty()
#
# Return non-zero if there is no consumer in the database, zero otherwise.
#
sub db_cons_is_empty()
{
	# Lazy cons database initialization
	_init_cons_db() if (!defined($_cons_db));

	return !%{$_cons_db};
}

#
# db_cons_load(directory)
#
# Load consumer located in DIRECTORY and add it temporarily to database. Return
# the new consumer on success.
#
sub db_cons_load($)
{
	my ($directory) = @_;
	my $cons;
	my $cons_id;

	# Lazy consumer database initialization
	_init_cons_db() if (!defined($_cons_db));

	$cons = cons_parse_from_dir($directory);
	$cons_id = $cons->[$CONS_T_ID];
	if (defined($_cons_db->{$cons_id})) {
		my $sys= $_cons_db->{$cons_id}->[$CONS_T_SYSTEM];
		my $source = "";

		if (defined($sys)) {
			$source = " in ".get_db_scope($sys)." database";
		}
		die("Consumer '$cons_id' already exists$source!\n");
	}

	$_cons_db->{$cons_id} = $cons;

	return $cons;
}

#
# _get_cons_text_files(cons_dir)
#
# Return list of text files found in CONS_DIR
#
sub _get_cons_text_files($)
{
	my ($cons_dir) = @_;
	my $dir;
	my @result;
	my $dir_handle;

	# Add text files in top-level directory
	push(@result, $CONS_DESC_FILENAME);
	opendir($dir_handle, $cons_dir) or
		die("Could not read directory '$cons_dir'!\n");
	# Look for localized text files
	foreach $dir (readdir($dir_handle)) {
		my $rel_file;

		# Skip . and ..
		if ($dir eq "." || $dir eq "..") {
			next;
		}
		# Skip non-directories
		if (!-d catdir($cons_dir, $dir)) {
			next;
		}
		# Add localized descriptions file if available
		$rel_file = catfile($dir, $CONS_DESC_FILENAME);
		if (-e catfile($cons_dir, $rel_file)) {
			push(@result, $rel_file);
		}
	}
	closedir($dir_handle);

	return @result;
}

#
# _get_cons_files(cons)
#
# Return list of files associated with consumer CONS. Filenames are relative to
# consumer directory.
#
sub _get_cons_files($)
{
	my ($cons) = @_;
	my $cons_dir = $cons->[$CONS_T_DIR];
	my @files;

	# Add cons and definitions files
	push(@files, $CONS_PROG_FILENAME, $CONS_DEF_FILENAME);

	# Add user-defined files
	push(@files, @{$cons->[$CONS_T_EXTRAFILES]});

	# Determine list of text files
	push(@files, _get_cons_text_files($cons_dir));

	return @files;
}

#
# db_cons_install(directory)
#
# Add consumer located in DIRECTORY to database.
#
sub db_cons_install($)
{
	my ($directory) = @_;
	my $install_dir = db_get_install_dir($DB_CONSUMER_DIR);
	my $cons;
	my @files;
	my $cons_id;
	my $cons_dir;
	my $target;

	# Check if directory exists
	if (!-d $install_dir) {
		create_path($install_dir, $DB_INSTALL_PERM_DIR);
	}
	# Check for write access to consumer directory
	if (!-w $install_dir) {
		die("Insufficient write permissions for directory ".
		    "'$install_dir'\n");
	}

	# Validate consumer's correctness
	$cons = db_cons_load($directory);
	$cons_id = $cons->[$CONS_T_ID];
	$cons_dir = $cons->[$CONS_T_DIR];

	# Get file list
	@files = _get_cons_files($cons);

	# Copy files to target
	$target = catfile($install_dir, $cons_id);
	copy_files($cons_dir, $target, @files);

	# Adjust consumer attributes
	$cons->[$CONS_T_DIR] = $target;
	$cons->[$CONS_T_SYSTEM] = $opt_system ? 1 : 0;

	# Mark consumer DB cache as out-of-date
	db_invalidate_cache($DB_CONSUMER_CACHE_FILENAME);
}

#
# db_cons_uninstall(cons_id)
#
# Persistently remove consumer CONS_ID from database.
#
sub db_cons_uninstall($)
{
	my ($cons_id) = @_;
	my $cons;
	my $cons_dir;
	my $system;

	# Check for existence of consumer
	$cons = db_cons_get($cons_id);
	if (!defined($cons)) {
		die("Consumer '$cons_id' not installed!\n");
	}
	$system = $cons->[$CONS_T_SYSTEM];

	# Check for proper database
	if ($system && !$opt_system) {
		die("Cannot remove consumer '$cons_id' from system-wide ".
		    "database without --system!\n");
	} elsif (!$system && $opt_system) {
		die("Cannot remove consumer '$cons_id' from user database ".
		    "with --system!\n");
	}

	# Check for write access to consumer directory
	$cons_dir = $cons->[$CONS_T_DIR];
	if (!-w dirname($cons_dir)) {
		die("Insufficient write permissions for directory ".
		    "'".dirname($cons_dir)."'\n");
	}

	# Remove files
	rm_rf($cons_dir);

	# Remove from database
	delete($_cons_db->{$cons_id});

	# Make sure consumer DB cache is reread
	db_invalidate_cache($DB_CONSUMER_CACHE_FILENAME);
}

#
# db_cons_get_param_ids(cons_id)
#
# Return list of parameter IDs defined for the consumer with the specified
# CONS_ID.
#
sub db_cons_get_param_ids($)
{
	my ($cons_id) = @_;
	my $cons = db_cons_get($cons_id);
	my $param_db;

	if (!defined($cons)) {
		return ();
	}
	$param_db = $cons->[$CONS_T_PARAM_DB];

	return keys(%{$param_db});
}

#
# db_cons_param_exists(cons_id, param_id)
#
# Return 1 if parameter PARAM_ID exists for consumer CONS_ID. Zero otherwise.
#
sub db_cons_param_exists($$)
{
	my ($cons_id, $param_id) = @_;
	my $cons = db_cons_get($cons_id);
	my $param_db;

	if (!defined($cons)) {
		return 0;
	}
	$param_db = $cons->[$CONS_T_PARAM_DB];
	if (!defined($param_db->{$param_id})) {
		return 0;
	}

	return 1;
}


#
# Code entry
#

# Indicate successful module initialization
1;
