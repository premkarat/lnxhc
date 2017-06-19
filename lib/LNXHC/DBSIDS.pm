#
# LNXHC::DBSIDS.pm
#   Linux Health Checker database for system information data.
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

package LNXHC::DBSIDS;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#
use LNXHC::Consts qw($SIDS_HOST_T_ID $SIDS_HOST_T_ITEMS $SIDS_INST_T_HOSTS
		     $SIDS_INST_T_ID $SIDS_ITEM_T_DATA_ID $SIDS_STORED_FILENAME
		     $SIDS_T_INSTS);
use LNXHC::Misc qw(debug quiet_retrieve quiet_store);
use LNXHC::UData qw(udata_get_path);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&db_sids_clear &db_sids_disable_writeback &db_sids_get
		    &db_sids_get_modified &db_sids_host_add &db_sids_host_delete
		    &db_sids_host_exists &db_sids_host_get
		    &db_sids_host_get_nums &db_sids_host_id_to_num
		    &db_sids_inst_add &db_sids_inst_delete &db_sids_inst_exists
		    &db_sids_inst_get &db_sids_inst_get_nums
		    &db_sids_inst_id_to_num &db_sids_is_empty &db_sids_item_add
		    &db_sids_item_delete &db_sids_item_exists &db_sids_item_get
		    &db_sids_item_get_nums &db_sids_item_id_to_num &db_sids_set
		    &db_sids_set_modified);


#
# Constants
#


#
# Global variables
#

# Current sysinfo data set
my $_current_sids;

# Flag indicating whether current data set has been modified
my $_modified_current_sids;

# Flag indicating whether writeback of current sysinfo data set is enabled
my $_writeback_enabled = 1;


#
# Sub-routines
#

#
# db_sids_clear()
#
# Clear sids database.
#
sub db_sids_clear()
{
	# Create empty data set
	$_current_sids = [ [] ];

	# Set modified marker
	$_modified_current_sids = 1;
}

#
# _init_current_sids()
#
# Initialize current sids data set from saved data. If no saved data exists,
# create an empty data set.
#
sub _init_current_sids()
{
	my $filename = udata_get_path($SIDS_STORED_FILENAME);

	if (-e $filename) {
		# Read data file
		debug("Initializing system information database\n");
		$_current_sids = quiet_retrieve($filename);
	} else {
		db_sids_clear();
	}
}

#
# _write_current_sids()
#
# Write current sids data set.
#
sub _write_current_sids()
{
	my $filename = udata_get_path($SIDS_STORED_FILENAME);

	quiet_store($_current_sids, $filename) or
		warn("Could not write current sysinfo data set file ".
		     "'$filename'\n");
}

#
# db_sids_disable_writeback()
#
# Instruct database not to write back changes to the current sids at
# program termination.
#
sub db_sids_disable_writeback()
{
	$_writeback_enabled = 0;
}

#
# db_sids_set_modified(modified)
#
# Set marker indicating if current sysinfo data set has been modified and
# needs to be written.
#
sub db_sids_set_modified($)
{
	my ($modified) = @_;

	$_modified_current_sids = $modified;
}

#
# db_sids_get_modified()
#
# Return marker indicating if current sysinfo data set has been modified and
# needs to be written.
#
sub db_sids_get_modified()
{
	return $_modified_current_sids;
}

#
# db_sids_get()
#
# Return current sids data.
#
sub db_sids_get()
{
	# Lazy current sysinfo data set initialization
	_init_current_sids() if (!defined($_current_sids));

	return $_current_sids;
}

#
# db_sids_set(sids)
#
# Replace current sids data with SIDS.
#
sub db_sids_set($)
{
	my ($sids) = @_;

	$_current_sids = $sids;

	# Set modified marker
	$_modified_current_sids = 1;
}

#
# _sids_get_insts()
#
# Return instance data list.
#
sub _sids_get_insts()
{
	# Lazy current sysinfo data set initialization
	_init_current_sids() if (!defined($_current_sids));

	return $_current_sids->[$SIDS_T_INSTS];
}

#
# db_sids_is_empty()
#
# Return non-zero if current sysinfo data set is empty.
#
sub db_sids_is_empty()
{
	my $insts = _sids_get_insts();

	if (!@$insts) {
		return 1;
	}

	return 0;
}

#
# db_sids_inst_exists(inst_num)
#
# Return non-zero of sids instance with specified INST_NUM exists.
#
sub db_sids_inst_exists($)
{
	my ($inst_num) = @_;
	my $insts = _sids_get_insts();

	if (defined($insts->[$inst_num])) {
		return 1;
	}

	return 0;
}

#
# db_sids_inst_get(inst_num)
#
# Return sids instance with specified INST_NUM.
#
sub db_sids_inst_get($)
{
	my ($inst_num) = @_;
	my $insts = _sids_get_insts();

	return $insts->[$inst_num];
}

#
# db_sids_inst_id_to_num(inst_id)
#
# Return instance number of sids instance with specified INST_ID. Return
# undefined value if no instance data was found.
#
sub db_sids_inst_id_to_num($)
{
	my ($inst_id) = @_;
	my $insts = _sids_get_insts();
	my $inst;
	my $inst_num = 0;

	foreach $inst (@$insts) {
		if ($inst->[$SIDS_INST_T_ID] eq $inst_id) {
			return $inst_num;
		}
		$inst_num++;
	}

	return undef;
}

#
# db_sids_inst_get_nums()
#
# Return list of sids instance numbers.
#
sub db_sids_inst_get_nums()
{
	my $insts = _sids_get_insts();

	return (0..(scalar(@$insts) - 1));
}

#
# db_sids_inst_add(inst)
#
# Add sids instance INST to the database.
#
sub db_sids_inst_add($)
{
	my ($inst) = @_;
	my $inst_id = $inst->[$SIDS_INST_T_ID];
	my $insts = _sids_get_insts();
	my $inst_num;
	my $replaced = 0;

	# Replace if instance with same ID already exists
	for ($inst_num = 0; $inst_num < scalar(@$insts); $inst_num++) {
		if ($insts->[$inst_num]->[$SIDS_INST_T_ID] eq $inst_id) {
			$insts->[$inst_num] = $inst;
			$replaced = 1;
			last;
		}
	}

	# Add if instance doesn't exist yet
	if (!$replaced) {
		push(@{$_current_sids->[$SIDS_T_INSTS]}, $inst);
	}

	# Set modified marker
	$_modified_current_sids = 1;
}

#
# db_sids_inst_delete(inst_num)
#
# Remove sids instance INST_NUM from the database.
#
sub db_sids_inst_delete($)
{
	my ($inst_num) = @_;
	my $insts = _sids_get_insts();

	splice(@$insts, $inst_num, 1);

	# Set modified marker
	$_modified_current_sids = 1;
}

#
# _sids_get_hosts(inst_num)
#
# Return host data list for specified INST_NUM.
#
sub _sids_get_hosts($)
{
	my ($inst_num) = @_;
	my $insts = _sids_get_insts();
	my $inst = $insts->[$inst_num];

	return $inst->[$SIDS_INST_T_HOSTS];
}

#
# db_sids_host_exists(inst_num, host_num)
#
# Return non-zero if host data with specified INST_NUM and HOST_NUM exists.
#
sub db_sids_host_exists($$)
{
	my ($inst_num, $host_num) = @_;
	my $hosts = _sids_get_hosts($inst_num);

	if (defined($hosts->[$host_num])) {
		return 1;
	}

	return 0;
}

#
# db_sids_host_get(inst_num, host_num)
#
# Return sids host data specified by INST_NUM and HOST_NUM.
#
sub db_sids_host_get($$)
{
	my ($inst_num, $host_num) = @_;
	my $hosts = _sids_get_hosts($inst_num);

	return $hosts->[$host_num];
}

#
# db_sids_host_id_to_num(inst_num, host_id)
#
# Return host number of sids host data with specified HOST_ID for instance
# INST_NUM. Return undefined value if no host data was found.
#
sub db_sids_host_id_to_num($$)
{
	my ($inst_num, $host_id) = @_;
	my $hosts = _sids_get_hosts($inst_num);
	my $host;
	my $host_num = 0;

	foreach $host (@$hosts) {
		if ($host->[$SIDS_HOST_T_ID] eq $host_id) {
			return $host_num;
		}
		$host_num++;
	}

	return undef;
}

#
# db_sids_host_get_nums(inst_num)
#
# Return list of host numbers for instance INST_NUM.
#
sub db_sids_host_get_nums($)
{
	my ($inst_num) = @_;
	my $hosts = _sids_get_hosts($inst_num);

	return (0..(scalar(@$hosts) - 1));
}

#
# db_sids_host_add(inst_num, host)
#
# Add host data HOST for instance INST_NUM to the database.
#
sub db_sids_host_add($$)
{
	my ($inst_num, $host) = @_;
	my $host_id = $host->[$SIDS_HOST_T_ID];
	my $inst = db_sids_inst_get($inst_num);
	my $hosts = $inst->[$SIDS_INST_T_HOSTS];
	my $host_num;
	my $replaced = 0;

	if (!defined($inst)) {
		die("Unknown sysinfo instance number '$inst_num'!\n");
	}

	# Replace if host data with same ID already exists
	for ($host_num = 0; $host_num < scalar(@$hosts); $host_num++) {
		if ($hosts->[$host_num]->[$SIDS_HOST_T_ID] eq $host_id) {
			$hosts->[$host_num] = $host;
			$replaced = 1;
			last;
		}
	}

	# Add if host data doesn't exist yet
	if (!$replaced) {
		push(@{$inst->[$SIDS_INST_T_HOSTS]}, $host);
	}

	# Set modified marker
	$_modified_current_sids = 1;
}

#
# db_sids_host_delete(inst_num, host_num)
#
# Remove host data HOST_NUM from instance INST_NUM.
#
sub db_sids_host_delete($$)
{
	my ($inst_num, $host_num) = @_;
	my $insts = _sids_get_insts();
	my $inst = $insts->[$inst_num];

	if (!defined($inst)) {
		die("Unknown sysinfo instance data: instance $inst_num!\n");
	}

	splice(@{$inst->[$SIDS_INST_T_HOSTS]}, $host_num, 1);

	# Set modified marker
	$_modified_current_sids = 1;
}

#
# _sids_get_items(inst_num, host_num)
#
# Return data item list for INST_NUM and HOST_NUM.
#
sub _sids_get_items($$)
{
	my ($inst_num, $host_num) = @_;
	my $hosts = _sids_get_hosts($inst_num);
	my $host = $hosts->[$host_num];

	return $host->[$SIDS_HOST_T_ITEMS];
}

#
# db_sids_item_exists(inst_num, host_num, item_num)
#
# Return non-zero if data item with specified INST_NUM, HOST_NUM and ITEM_NUM
# exists.
#
sub db_sids_item_exists($$$)
{
	my ($inst_num, $host_num, $item_num) = @_;
	my $items = _sids_get_items($inst_num, $host_num);

	if (defined($items->[$item_num])) {
		return 1;
	}

	return 0;
}

#
# db_sids_item_get(inst_num, host_num, item_num)
#
# Return sids data item for INST_NUM, HOST_NUM and ITEM_NUM.
#
sub db_sids_item_get($$$)
{
	my ($inst_num, $host_num, $item_num) = @_;
	my $items = _sids_get_items($inst_num, $host_num);

	return $items->[$item_num];
}

#
# db_sids_item_id_to_num(inst_num, host_num, data_id)
#
# Return item number of sids data item with specified DATA_ID for HOST_NUM
# and INST_NUM. Return undefined value if no data item was found.
#
sub db_sids_item_id_to_num($$$)
{
	my ($inst_num, $host_num, $data_id) = @_;
	my $items = _sids_get_items($inst_num, $host_num);
	my $item;
	my $item_num = 0;

	foreach $item (@$items) {
		if ($item->[$SIDS_ITEM_T_DATA_ID] eq $data_id) {
			return $item_num;
		}
		$item_num++;
	}

	return undef;
}

#
# db_sids_item_get_nums(inst_num, host_num)
#
# Return list of data item numbers for INST_NUM and HOST_NUM.
#
sub db_sids_item_get_nums($$)
{
	my ($inst_num, $host_num) = @_;
	my $items = _sids_get_items($inst_num, $host_num);

	return (0..(scalar(@$items) - 1));
}

#
# db_sids_item_add(inst_num, host_num, item)
#
# Add data item ITEM for INST_NUM and HOST_NUM to the database.
#
sub db_sids_item_add($$$)
{
	my ($inst_num, $host_num, $item) = @_;
	my $data_id = $item->[$SIDS_ITEM_T_DATA_ID];
	my $host = db_sids_host_get($inst_num, $host_num);
	my $items = $host->[$SIDS_HOST_T_ITEMS];
	my $item_num;
	my $replaced = 0;

	if (!defined($host)) {
		die("Unknown sysinfo host data: instance $inst_num host ".
		    "$host_num'!\n");
	}

	# Replace if data item with same ID already exists
	for ($item_num = 0; $item_num < scalar(@$items); $item_num++) {
		if ($items->[$item_num]->[$SIDS_ITEM_T_DATA_ID] eq $data_id) {
			$items->[$item_num] = $item;
			$replaced = 1;
			last;
		}
	}

	# Add if host data doesn't exist yet
	if (!$replaced) {
		push(@{$host->[$SIDS_HOST_T_ITEMS]}, $item);
	}

	# Set modified marker
	$_modified_current_sids = 1;
}

#
# db_sids_item_delete(inst_num, host_num, item_num)
#
# Remove data item ITEM_NUM from host HOST_NUM and instance INST_NUM.
#
sub db_sids_item_delete($$$)
{
	my ($inst_num, $host_num, $item_num) = @_;
	my $hosts = _sids_get_hosts($inst_num);
	my $host = $hosts->[$host_num];

	if (!defined($host)) {
		die("Unknown sysinfo host number '$host_num'!\n");
	}

	splice(@{$host->[$SIDS_HOST_T_ITEMS]}, $item_num, 1);

	# Set modified marker
	$_modified_current_sids = 1;
}


#
# Code entry
#

# Ensure that current sysinfo data set is written at program termination
END {
	if ($_modified_current_sids && $_writeback_enabled) {
		_write_current_sids();
		$_modified_current_sids = undef;
	}
};

# Indicate successful module initialization
1;
