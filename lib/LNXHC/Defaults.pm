#
# LNXHC::Defaults.pm
#   Linux Health Checker defaults helper functions
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

package LNXHC::Defaults;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#
use LNXHC::Consts qw($CHECK_T_EX_DB $CHECK_T_ID $CHECK_T_PARAM_DB
		     $CHECK_T_REPEAT $CHECK_T_SI_DB $CHECK_T_STATE $CONS_T_ID
		     $CONS_T_PARAM_DB $CONS_T_STATE $EXCEPTION_T_SEVERITY
		     $EXCEPTION_T_STATE $PARAM_T_VALUE $SI_REC_DATA_T_DURATION
		     $SI_TYPE_T_REC $SYSINFO_T_DATA $SYSINFO_T_TYPE);
use LNXHC::DBCheck qw(db_check_get db_check_get_ids);
use LNXHC::DBCons qw(db_cons_get db_cons_get_ids);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&defaults_get_check_conf &defaults_get_check_conf_db
		    &defaults_get_cons_conf &defaults_get_cons_conf_db);


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
# _get_default_param_conf(param_db)
#
# Return the default configuration for parameters in PARAM_DB.
#
sub _get_default_param_conf($)
{
	my ($param_db) = @_;
	my $param_id;
	my %conf_db;

	foreach $param_id (keys(%{$param_db})) {
		my $param = $param_db->{$param_id};
		my $value = $param->[$PARAM_T_VALUE];

		$conf_db{$param_id} = [ $param_id, $value ];
	}

	return \%conf_db;
}

#
# _get_default_ex_conf(ex_db)
#
# Return the default configuration for exceptions in EX_DB.
#
sub _get_default_ex_conf($)
{
	my ($ex_db) = @_;
	my $ex_id;
	my %conf_db;

	foreach $ex_id (keys(%{$ex_db})) {
		my $ex = $ex_db->{$ex_id};
		my $severity = $ex->[$EXCEPTION_T_SEVERITY];
		my $state = $ex->[$EXCEPTION_T_STATE];

		$conf_db{$ex_id} = [ $ex_id, $severity, $state ];
	}

	return \%conf_db;
}

#
# _get_default_si_conf(si_db)
#
# Return the default configuration for exceptions in SI_DB.
#
sub _get_default_si_conf($)
{
	my ($si_db) = @_;
	my $si_id;
	my %conf_db;

	foreach $si_id (keys(%{$si_db})) {
		my $si = $si_db->{$si_id};
		my $type = $si->[$SYSINFO_T_TYPE];
		my $conf;

		if ($type == $SI_TYPE_T_REC) {
			my $data = $si->[$SYSINFO_T_DATA];
			my $duration = $data->[$SI_REC_DATA_T_DURATION];

			$conf = [ $duration ];
		} else {
			next;
		}
		$conf_db{$si_id} = [ $si_id, $type, $conf ];
	}

	return \%conf_db;
}

#
# defaults_get_check_conf(check)
#
# Return the default configuration for CHECK.
#
sub defaults_get_check_conf($)
{
	my ($check) = @_;
	my $check_id = $check->[$CHECK_T_ID];
	my $state = $check->[$CHECK_T_STATE];
	my $repeat = $check->[$CHECK_T_REPEAT];
	my $params = $check->[$CHECK_T_PARAM_DB];
	my $ex = $check->[$CHECK_T_EX_DB];
	my $si = $check->[$CHECK_T_SI_DB];
	my $param_conf;
	my $ex_conf;
	my $si_conf;

	$param_conf	= _get_default_param_conf($params);
	$ex_conf	= _get_default_ex_conf($ex);
	$si_conf	= _get_default_si_conf($si);

	return [$check_id, $state, $repeat, $param_conf, $ex_conf, $si_conf];
}

#
# defaults_get_check_conf_db()
#
# Return the default configuration for all checks.
#
sub defaults_get_check_conf_db()
{
	my @check_ids = db_check_get_ids();
	my %check_conf_db;

	foreach my $check_id (@check_ids) {
		my $check = db_check_get($check_id);

		$check_conf_db{$check_id} = defaults_get_check_conf($check);
	}

	return \%check_conf_db;
}

#
# defaults_get_cons_conf(cons)
#
# Return the default configuration for consumer CONS.
#
sub defaults_get_cons_conf($)
{
	my ($cons) = @_;
	my $cons_id = $cons->[$CONS_T_ID];
	my $state = $cons->[$CONS_T_STATE];
	my $params = $cons->[$CONS_T_PARAM_DB];
	my $param_conf;

	# Get default parameter configuration
	$param_conf = _get_default_param_conf($params);

	return [$cons_id, $state, $param_conf];
}

#
# defaults_get_cons_conf_db()
#
# Return the default configuration for all consumers.
#
sub defaults_get_cons_conf_db()
{
	my @cons_ids = db_cons_get_ids();
	my %cons_conf_db;

	foreach my $cons_id (@cons_ids) {
		my $cons = db_cons_get($cons_id);

		$cons_conf_db{$cons_id} = defaults_get_cons_conf($cons);
	}

	return \%cons_conf_db;
}


#
# Code entry
#

# Indicate successful module initialization
1;
