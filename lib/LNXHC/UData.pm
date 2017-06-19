#
# LNXHC::UData.pm
#   Linux Health Checker user data management
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

package LNXHC::UData;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catfile catdir file_name_is_absolute);
use Cwd qw(abs_path);


#
# Local imports
#
use LNXHC::Consts qw($DB_INSTALL_PERM_DIR $UDATA_DIRECTORY $UDATA_ENV);
use LNXHC::Misc qw($opt_user_dir create_path get_home_dir info);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&udata_get_path);


#
# Constants
#


#
# Global variables
#

# Cached directory name
my $_dir;


#
# Sub-routines
#

#
# udata_get_path(filename)
#
# Return full path to user data file FILENAME. Abort if user data directory
# could not be determined.
#
sub _get_dir()
{
	my $dir;
	my $source;

	if (defined($opt_user_dir)) {
		$source = "command line";
		$dir = $opt_user_dir;
	} elsif (exists($ENV{$UDATA_ENV})) {
		$source = "environment variable";
		$dir = $ENV{$UDATA_ENV};
	} else {
		my $home = get_home_dir();

		if (!defined($home)) {
			die("Could not determine home directory!\n");
		}
		$dir = catdir($home, $UDATA_DIRECTORY);
	}
	if (defined($source)) {
		info("Using user directory '$dir' (from $source)\n");
		if ($dir eq "") {
			die("User directory path cannot be empty!\n");
		}
	}
	if (!file_name_is_absolute($dir)) {
		die("User directory path cannot be a relative!\n");
	}
	if (!-d $dir) {
		info("Creating user directory '$dir'\n");
		create_path($dir, $DB_INSTALL_PERM_DIR);
	}

	return abs_path($dir);
}

#
# udata_get_path(filename)
#
# Return full path to user data file FILENAME. Abort if user data directory
# could not be determined.
#
sub udata_get_path($)
{
	my ($filename) = @_;

	if (!defined($_dir)) {
		$_dir = _get_dir();
	}

	return catfile($_dir, $filename);
}


#
# Code entry
#

# Indicate successful module initialization
1;
