#
# LNXHC::DB.pm
#   Linux Health Checker database helper functions
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

package LNXHC::DB;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catdir);
use Digest::MD5 qw(md5_hex);


#
# Local imports
#
use LNXHC::Consts qw($LNXHCRC_ID_T_DB_CACHING $LNXHCRC_ID_T_DB_PATH);
use LNXHC::LNXHCRC qw(lnxhcrc_get);
use LNXHC::Locale qw(locale_matches);
use LNXHC::Misc qw($opt_system info3 quiet_retrieve quiet_store);
use LNXHC::UData qw(udata_get_path);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&db_generate_version &db_get_dirs &db_get_install_dir
		    &db_init &db_invalidate_cache &db_read_cache
		    &db_write_cache);


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
# db_get_dirs(subdir)
#
# Determine list of database directories for subdirectory SUBDIR.
# Returns: [ dir1, dir2, ... ]
# dir:     [ path, system ]
# path:    path to a directory
# system:  flag indicating if this is a system-wide or user-specified directory
#
sub db_get_dirs($)
{
	my ($subdir) = @_;
	my $sys_dirs = lnxhcrc_get($LNXHCRC_ID_T_DB_PATH);
	my $user_dir = udata_get_path($subdir);
	my @result;

	foreach my $dir (@$sys_dirs) {
		push(@result, [ catdir($dir, $subdir), 1]);
	}
	if (-e $user_dir) {
		push(@result, [ $user_dir, 0 ]);
	}

	return \@result;
}

#
# db_get_install_dir(subdir)
#
# Determine directory for installing new objects. SUBDIR specifies the
# sub-directory of the db directory.
#
sub db_get_install_dir($)
{
	my ($subdir) = @_;

	if ($opt_system) {
		my $sys_dirs = lnxhcrc_get($LNXHCRC_ID_T_DB_PATH);

		if (!@$sys_dirs) {
			die("Could not determine system-wide database install ".
			    "directory!\n");
		}

		# First entry in the list is the install directory
		return catdir($sys_dirs->[0], $subdir);
	} else {
		return udata_get_path($subdir);
	}
}

#
# db_read_cache(filename)
#
# Read cached database from filename. Return (db, version, locale) on success,
# or (undef, undef, undef) on error.
#
sub db_read_cache($)
{
	my ($filename) = @_;
	my $data;

	$data = quiet_retrieve(udata_get_path($filename));

	if (defined($data)) {
		return @$data;
	}
	return (undef, undef, undef);
}

#
# db_write_cache(filename, db, version)
#
# Write cached database.
#
sub db_write_cache($$$)
{
	my ($filename, $db, $version) = @_;

	$filename = udata_get_path($filename);

	quiet_store([ $db, $version, $ENV{"LC_MESSAGES"} ], $filename) or
		warn("Could not write database cache '$filename'!\n");
}

#
# db_invalidate_cache(filename)
#
# Invalidate cached version of database.
#
sub db_invalidate_cache($)
{
	my ($filename) = @_;

	$filename = udata_get_path($filename);
	return if (!-e $filename);

	unlink($filename) or
		warn("Could not remove DB cache '$filename': $!\n");
}

#
# _path_state(path)
#
# Return a string identifying the content state of a file or directory, based
# on its name and modification time.
#
sub _path_state($)
{
	my ($path) = @_;
	my $mtime = stat($path) ? (stat(_))[9] : "-";

	return $path."\0".$mtime;
}

#
# _dir_state(path)
#
# Return a string identifying the content state of a file or directory, based
# on its name and modification time and, in case of a directory, the names
# and modification times of contained files.
#
sub _dir_state($)
{
	my ($path) = @_;
	my $handle;
	my @filestate;
	my $dirstate;

	$dirstate = _path_state($path)."\0";
	opendir($handle, $path) or goto out;
	@filestate = map { _path_state(catdir($path, $_)) }
			 sort(grep { !/^\.\.?$/ } readdir($handle));
	closedir($handle);

	$dirstate .= join("\0", @filestate);

out:
	return $dirstate;
}

#
# db_generate_version(subdir)
#
# Generate string representing the current "version" of a database.
# Note: this implementation only catches changes in the list of directory
# names and modification times of core check files. We need to go for this
# trade-off since version checking is supposed to be less effort than full
# database parsing.
#
sub db_generate_version($)
{
	my ($subdir) = @_;
	my $dirs = db_get_dirs($subdir);
	my $dbstate = "";

	foreach my $dir (@$dirs) {
		my ($path, $system) = @$dir;
		my $handle;
		my @dbdirstate;

		$dbstate .= _path_state($path)."\0";
		opendir($handle, $path) or next;
		@dbdirstate = map { _dir_state(catdir($path, $_)) }
				  sort(grep { !/^\.\.?$/ } readdir($handle));
		closedir($handle);
		$dbstate .= join("\0", @dbdirstate);
	}

	return md5_hex($dbstate);
}

#
# db_init(subdir, cachefile, read_fn)
#
# Initialize database. SUBDIR specifies the name of the subdirectory in the
# main DB directory. CACHEFILE specifies the name of the database cache file.
# READ_FN specifies the function used to read the database.
#
sub db_init($$$)
{
	my ($subdir, $cachefile, $read_fn) = @_;
	my $caching = lnxhcrc_get($LNXHCRC_ID_T_DB_CACHING);
	my $db;
	my $version;

	if ($caching) {
		my $current_version = db_generate_version($subdir);
		my $locale;

		# Consult cache
		($db, $version, $locale) = db_read_cache($cachefile);
		if (defined($db) && $version eq $current_version &&
		    locale_matches($locale)) {
			# Cache is up-to-date
			info3("Using cached database in '$cachefile'\n");
			goto out;
		}
		$version = $current_version;
	}
	$db = &$read_fn();
	if ($caching) {
		# Store cache
		db_write_cache($cachefile, $db, $version);
	}
out:
	return ($db, $version);
}


#
# Code entry
#

# Indicate successful module initialization
1;
