#
# LNXHC::LNXHCRC.pm
#   Linux Health Checker configuration file handling
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

package LNXHC::LNXHCRC;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catfile rootdir);


#
# Local imports
#
use LNXHC::Consts qw($LNXHCRC_ID_T_DB_CACHING $LNXHCRC_ID_T_DB_PATH);
use LNXHC::Misc qw(info3 unquote_nodie);
use LNXHC::UData qw(udata_get_path);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&lnxhcrc_get);


#
# Constants
#

my $_RC_FILENAME		= "lnxhcrc";

# lnxhcrc item data
# Enumeration of data fields for struct lnxhcrc_item_t
my $_ITEM_T_ID			= 0;
my $_ITEM_T_REPEATS		= 1;
my $_ITEM_T_DEFAULT		= 2;

# Definition of contents of lnxhcrc file
my %_DEF = (
	"db_path" =>
		[
			$LNXHCRC_ID_T_DB_PATH,
			1,
			\@main::default_db_dirs,
		],
	"db_caching" =>
		[
			$LNXHCRC_ID_T_DB_CACHING,
			0,
			1,
		],
);


#
# Global variables
#

my $_lnxhcrc;


#
# Sub-routines
#

#
# _add_defaults()
#
# Set default values for configuration file items which have not yet been
# set.
#
sub _add_defaults()
{
	foreach my $item (values(%_DEF)) {
		my $id = $item->[$_ITEM_T_ID];
		my $default = $item->[$_ITEM_T_DEFAULT];

		# Skip already defined items
		next if (defined($_lnxhcrc->{$id}));

		# Set default value
		$_lnxhcrc->{$id} = $default;
	}
}

#
# _read_lnxhcrc()
#
# Read contents of lnxhc configuration file. Search order:
# - user data directory (either default or specified by --user-data)
# - /etc
#
sub _read_lnxhcrc()
{
	my $filename;
	my $handle;
	my $err;

	$_lnxhcrc = {};

	# Determine location of configuration file
	$filename = udata_get_path($_RC_FILENAME);
	if (!-e $filename) {
		$filename = catfile(rootdir(), "etc", $_RC_FILENAME);
		if (!-e $filename) {
			goto out;
		}
	}
	info3("Using configuration file '$filename'\n");

	# Parse configuration file
	open($handle, "<", $filename) or
		die("Could not read configuration file '$filename': $!\n");
	foreach my $line (<$handle>) {
		my ($key, $value);
		my $item;
		my ($id, $repeats);

		# Skip empty lines
		next if ($line =~ /^\s*$/);
		# Skip comments lines
		next if ($line =~ /^\s*#/);

		# Check format
		if ($line !~ /^\s*(\w+)\s*=(.*)$/) {
			$err = "unrecognized line format";
			goto err;
		}
		# Check keyword
		($key, $value) = ($1, $2);
		if (!exists($_DEF{$key})) {
			$err = "unknown keyword '$key'";
			goto err;
		}
		# Remove quoting from value
		($err, $value ) = unquote_nodie($value);
		if (defined($err)) {
			goto err;
		}
		# Add to hash
		$item = $_DEF{$key};
		($id, $repeats) = @$item;
		if ($repeats) {
			push(@{$_lnxhcrc->{$id}}, $value);
		} else {
			if (exists($_lnxhcrc->{$id})) {
				warn("Configuration keyword '$key' redefined ".
				     "in $filename:$.\n");
			}
			$_lnxhcrc->{$id} = $value;
		}
	}
	close($handle);

out:
	_add_defaults();
	return;

err:
	die("Configuration file error in $filename:$.: $err!\n");
}

#
# lnxhcrc_get(item_id)
#
# Return value for lnxhcrc item with specified ITEM_ID.
#
sub lnxhcrc_get($)
{
	my ($item_id) = @_;

	# Lazy configuration file reading
	_read_lnxhcrc() if (!defined($_lnxhcrc));

	return $_lnxhcrc->{$item_id};
}


#
# Code entry
#

# Indicate successful module initialization
1;
