#
# LNXHC::DBProfile.pm
#   Linux Health Checker database for configuration profiles
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

package LNXHC::DBProfile;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catfile);
use File::Basename qw(dirname);
use Storable qw(dclone);
use Cwd qw(abs_path);


#
# Local imports
#
use LNXHC::Consts qw($CHECK_CONF_T_EX_CONF_DB $CHECK_CONF_T_PARAM_CONF_DB
		     $CHECK_CONF_T_REPEAT $CHECK_CONF_T_SI_CONF_DB
		     $CHECK_CONF_T_STATE $CONS_CONF_T_PARAM_CONF_DB
		     $CONS_CONF_T_STATE $DB_ACTIVE_PROFILE_FILENAME
		     $DB_INSTALL_PERM_DIR $DB_INSTALL_PERM_NON_EXEC
		     $DB_PROFILE_CACHE_FILENAME $DB_PROFILE_DIR
		     $DEFAULT_PROFILE_DESC $DEFAULT_PROFILE_ID
		     $EX_CONF_T_SEVERITY $EX_CONF_T_STATE
		     $LNXHCRC_ID_T_DB_CACHING $MATCH_ID $PARAM_CONF_T_VALUE
		     $PROFILE_T_CHECK_CONF_DB $PROFILE_T_CONS_CONF_DB
		     $PROFILE_T_FILENAME $PROFILE_T_HOSTS $PROFILE_T_ID
		     $PROFILE_T_MODIFIED $PROFILE_T_SYSTEM $SI_CONF_T_DATA
		     $SI_CONF_T_TYPE $SI_REC_CONF_T_DURATION $SI_TYPE_T_REC);
use LNXHC::DB qw(db_generate_version db_get_dirs db_get_install_dir db_init
		 db_invalidate_cache db_write_cache);
use LNXHC::LNXHCRC qw(lnxhcrc_get);
use LNXHC::Misc qw($opt_system create_path info3 quote read_file unique
		   unquote_nodie validate_duration_nodie validate_id
		   validate_severity validate_state write_file);
use LNXHC::UData qw(udata_get_path);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&db_profile_check_modify &db_profile_copy
		    &db_profile_disable_writeback &db_profile_exists
		    &db_profile_export &db_profile_get &db_profile_get_active_id
		    &db_profile_get_ids &db_profile_import &db_profile_install
		    &db_profile_is_empty &db_profile_merge &db_profile_new
		    &db_profile_rename &db_profile_set_active_id
		    &db_profile_set_modified &db_profile_uninstall);


#
# Constants
#


#
# Global variables
#

# Configuration profile database
my $_profile_db;

# Version of profile database. When profiles are added or removed from the
# corresponding directory, this version changes.
my $_profile_db_version;

# ID of the active configuration profile
my $_active_profile_id;

# Flag indicating whether configuration data has been modified
my $_modified_profile_db;

# Flag indicating whether writeback of profile database is enabled
my $_writeback_enabled = 1;


#
# Sub-routines
#

#
# _write_check_conf(handle, check_conf)
#
# Write check configuration CHECK_CONF to HANDLE.
#
sub _write_check_conf($$)
{
	my ($handle, $check_conf) = @_;
	my ($check_id, $state, $repeat, $param_conf_db, $ex_conf_db,
	    $si_conf_db) = @$check_conf;
	my $prefix = "check.$check_id.";

	if (defined($state)) {
		print($handle $prefix."state=".quote($state)."\n");
	}
	if (defined($repeat) && $repeat ne "") {
		print($handle $prefix."repeat=".quote($repeat)."\n");
	}
	if (defined($param_conf_db)) {
		foreach my $param_id (sort(keys(%{$param_conf_db}))) {
			my $param_conf = $param_conf_db->{$param_id};
			my $value = $param_conf->[$PARAM_CONF_T_VALUE];

			print($handle $prefix."param.$param_id.value=".
			      quote($value)."\n");
		}
	}
	if (defined($ex_conf_db)) {
		foreach my $ex_id (sort(keys(%{$ex_conf_db}))) {
			my $ex_conf = $ex_conf_db->{$ex_id};
			my $sev = $ex_conf->[$EX_CONF_T_SEVERITY];
			my $ex_state = $ex_conf->[$EX_CONF_T_STATE];

			if (defined($sev)) {
				print($handle $prefix."ex.$ex_id.sev=".
				      quote($sev)."\n");
			}
			if (defined($ex_state)) {
				print($handle $prefix."ex.$ex_id.state=".
				      quote($ex_state)."\n");
			}
		}
	}
	if (defined($si_conf_db)) {
		foreach my $si_id (sort(keys(%{$si_conf_db}))) {
			my $si_conf = $si_conf_db->{$si_id};
			my $type = $si_conf->[$SI_CONF_T_TYPE];
			my $data = $si_conf->[$SI_CONF_T_DATA];

			if ($type == $SI_TYPE_T_REC) {
				my $rec_duration =
					$data->[$SI_REC_CONF_T_DURATION];

				if (defined($rec_duration)) {
					print($handle $prefix."si.$si_id.".
					      "rec_duration=".
					      quote($rec_duration)."\n");
				}
			}
		}
	}
}

#
# _write_cons_conf(handle, cons_conf)
#
# Write consumer configuration CONS_CONF to HANDLE.
#
sub _write_cons_conf($$)
{
	my ($handle, $cons_conf) = @_;
	my ($cons_id, $state, $param_conf_db) = @$cons_conf;
	my $prefix = "cons.$cons_id.";

	if (defined($state)) {
		print($handle $prefix."state=".quote($state)."\n");
	}
	if (defined($param_conf_db)) {
		foreach my $param_id (sort(keys(%{$param_conf_db}))) {
			my $param_conf = $param_conf_db->{$param_id};
			my $value = $param_conf->[$PARAM_CONF_T_VALUE];

			print($handle $prefix."param.$param_id.value=".
			      quote($value)."\n");
		}
	}
}

#
# _write_profile(profile, filename)
#
# Write profile PROFILE to file FILENAME.
#
sub _write_profile($$)
{
	my ($profile, $filename) = @_;
	my ($profile_id, $desc, $hosts, $check_conf_db, $cons_conf_db) =
		@$profile;
	my $handle;

	if ($filename eq "-") {
		$handle = *STDOUT;
	} else {
		open($handle, ">", $filename)
			or die("Could not write profile to '$filename': $!\n");
	}
	print($handle "id=".quote($profile_id)."\n");
	print($handle "desc=".quote($desc)."\n");
	if (defined($hosts)) {
		my $num = 0;

		foreach my $host_id (@$hosts) {
			print($handle "host.".$num++."=".quote($host_id)."\n");
		}
	}
	if (defined($check_conf_db)) {
		foreach my $check_id (sort(keys(%{$check_conf_db}))) {
			_write_check_conf($handle, $check_conf_db->{$check_id});
		}
	}
	if (defined($cons_conf_db)) {
		foreach my $cons_id (sort(keys(%{$cons_conf_db}))) {
			_write_cons_conf($handle, $cons_conf_db->{$cons_id});
		}
	}
	if ($filename ne "-") {
		close($handle);
	}
}

#
# _get_check_conf(check_conf_db, check_id)
#
# Return check configuration data set for check CHECK_ID from CHECK_CONF_DB.
# Create it if it doesn't exist yet.
#
sub _get_check_conf($$)
{
	my ($check_conf_db, $check_id) = @_;
	my $check_conf = $check_conf_db->{$check_id};

	if (!defined($check_conf)) {
		# Create check_conf_t
		$check_conf = [ $check_id, undef, undef, {}, {}, {} ];
		$check_conf_db->{$check_id} = $check_conf;
	}

	return $check_conf;
}

#
# _get_check_param_conf(check_conf_db, check_id, param_id)
#
# Return check parameter configuration data set for check CHECK_ID and PARAM_ID
# from CHECK_CONF_DB. Create it if it doesn't exist yet.
#
sub _get_check_param_conf($$$)
{
	my ($check_conf_db, $check_id, $param_id) = @_;
	my $check_conf = _get_check_conf($check_conf_db, $check_id);
	my $param_conf_db = $check_conf->[$CHECK_CONF_T_PARAM_CONF_DB];
	my $param_conf = $param_conf_db->{$param_id};

	if (!defined($param_conf)) {
		# Create param_conf_t
		$param_conf = [ $param_id, undef ];
		$param_conf_db->{$param_id} = $param_conf;
	}

	return $param_conf;
}

#
# _get_si_conf(check_conf_db, check_id, si_id)
#
# Return sysinfo configuration data set for check CHECK_ID and SI_ID
# from CHECK_CONF_DB. Create it if it doesn't exist yet.
#
sub _get_si_conf($$$)
{
	my ($check_conf_db, $check_id, $si_id) = @_;
	my $check_conf = _get_check_conf($check_conf_db, $check_id);
	my $si_conf_db = $check_conf->[$CHECK_CONF_T_SI_CONF_DB];
	my $si_conf = $si_conf_db->{$si_id};

	if (!defined($si_conf)) {
		# Create si_conf_t
		$si_conf = [ $si_id, undef, undef ];
		$si_conf_db->{$si_id} = $si_conf;
	}

	return $si_conf;
}

#
# _get_ex_conf(check_conf_db, check_id, ex_id)
#
# Return exception configuration data set for check CHECK_ID and EX_ID
# from CHECK_CONF_DB. Create it if it doesn't exist yet.
#
sub _get_ex_conf($$$)
{
	my ($check_conf_db, $check_id, $ex_id) = @_;
	my $check_conf = _get_check_conf($check_conf_db, $check_id);
	my $ex_conf_db = $check_conf->[$CHECK_CONF_T_EX_CONF_DB];
	my $ex_conf = $ex_conf_db->{$ex_id};

	if (!defined($ex_conf)) {
		# Create ex_conf_t
		$ex_conf = [ $ex_id, undef, undef ];
		$ex_conf_db->{$ex_id} = $ex_conf;
	}

	return $ex_conf;
}

#
# _get_cons_conf(cons_conf_db, cons_id)
#
# Return consumer configuration data set for check CONS_ID from CONS_CONF_DB.
# Create it if it doesn't exist yet.
#
sub _get_cons_conf($$)
{
	my ($cons_conf_db, $cons_id) = @_;
	my $cons_conf = $cons_conf_db->{$cons_id};

	if (!defined($cons_conf)) {
		# Create cons_conf_t
		$cons_conf = [ $cons_id, undef, {} ];
		$cons_conf_db->{$cons_id} = $cons_conf;
	}

	return $cons_conf;
}

#
# _get_cons_param_conf(cons_conf_db, cons_id, param_id)
#
# Return consumer parameter configuration data set for check CONS_ID and
# PARAM_ID from CONS_CONF_DB. Create it if it doesn't exist yet.
#
sub _get_cons_param_conf($$$)
{
	my ($cons_conf_db, $cons_id, $param_id) = @_;
	my $cons_conf = _get_cons_conf($cons_conf_db, $cons_id);
	my $param_conf_db = $cons_conf->[$CONS_CONF_T_PARAM_CONF_DB];
	my $param_conf = $param_conf_db->{$param_id};

	if (!defined($param_conf)) {
		# Create param_conf_t
		$param_conf = [ $param_id, undef ];
		$param_conf_db->{$param_id} = $param_conf;
	}
}

#
# _read_profile(filename)
#
# Read profile from FILENAME and return resulting profile.
#
sub _read_profile($)
{
	my ($filename) = @_;
	my $profile_id;
	my $desc;
	my @hosts;
	my %check_conf_db;
	my %cons_conf_db;
	my $handle;
	my $err;

	if ($filename eq "-") {
		$handle = *STDIN;
	} else {
		my $abs_file = abs_path($filename);

		if (!defined($abs_file)) {
			die("File '$filename' does not exist!\n");
		}
		if (!-f $abs_file) {
			die("Could not read '$filename': not a regular ".
			    "file!\n");
		}
		$filename = $abs_file;
		open($handle, "<", $filename) or
			die("Could not open '$filename': $!\n");
	}
	while (<$handle>) {
		my $key;
		my $value;

		chomp();
		s/^\s*//g;
		if ($_ eq "") {
			# Empty line
			next;
		} elsif (/^#/) {
			# Comment line
			next;
		} elsif (!/^([^=]+)\s*=(.*)$/) {
			$err = "unknown line format";
			goto err;
		}
		# Key=value line
		$key = $1;
		($err, $value) = unquote_nodie($2);
		goto err if (defined($err));
		# Interpret key
		if ($key eq "id") {
			# Profile ID
			$err = validate_id("profile name", $value, 1);
			goto err if (defined($err));
			$profile_id = $value;
		} elsif ($key eq "desc") {
			# Profile description
			$desc = $value;
			$desc =~ s/\n/ /g;
		} elsif ($key =~ /^host\.(d+)$/) {
			# Host ID
			$hosts[$1] = $value;
		} elsif ($key =~ /^check\.($MATCH_ID)\.state$/) {
			# Check activation state
			my $check_conf = _get_check_conf(\%check_conf_db, $1);

			$err = validate_state($value);
			goto err if (defined($err));
			$check_conf->[$CHECK_CONF_T_STATE] = $value;
		} elsif ($key =~ /^check\.($MATCH_ID)\.repeat$/) {
			# Check repeat interval
			my $check_conf = _get_check_conf(\%check_conf_db, $1);

			$err = validate_duration_nodie($value, 1);
			goto err if (defined($err));
			$check_conf->[$CHECK_CONF_T_REPEAT] = $value;
		} elsif ($key =~ /^check\.($MATCH_ID)\.param.($MATCH_ID)\.value$/) {
			# Check parameter value
			my $param_conf = _get_check_param_conf(\%check_conf_db,
							       $1, $2);

			$param_conf->[$PARAM_CONF_T_VALUE] = $value;
		} elsif ($key =~ /^check\.($MATCH_ID)\.si\.($MATCH_ID)\.rec_duration$/) {
			# Check sysinfo item record duration
			my $si_conf = _get_si_conf(\%check_conf_db, $1, $2);

			$err = validate_duration_nodie($value);
			goto err if (defined($err));
			$si_conf->[$SI_CONF_T_TYPE] = $SI_TYPE_T_REC;
			$si_conf->[$SI_CONF_T_DATA] = [ $value ];
		} elsif ($key =~ /^check\.($MATCH_ID)\.ex\.($MATCH_ID)\.sev$/) {
			# Check exception severity
			my $ex_conf = _get_ex_conf(\%check_conf_db, $1, $2);

			$err = validate_severity($value);
			goto err if (defined($err));
			$ex_conf->[$EX_CONF_T_SEVERITY] = $value;
		} elsif ($key =~ /^check\.($MATCH_ID)\.ex\.($MATCH_ID)\.state$/) {
			# Check exception state
			my $ex_conf = _get_ex_conf(\%check_conf_db, $1, $2);

			$err = validate_state($value);
			goto err if (defined($err));
			$ex_conf->[$EX_CONF_T_STATE] = $value;
		} elsif ($key =~ /^cons\.($MATCH_ID)\.state$/) {
			# Consumer activation state
			my $cons_conf = _get_cons_conf(\%cons_conf_db, $1);

			$err = validate_state($value);
			goto err if (defined($err));
			$cons_conf->[$CONS_CONF_T_STATE] = $value;
		} elsif ($key =~ /^cons\.($MATCH_ID)\.param\.($MATCH_ID)\.value$/) {
			# Consumer parameter value
			my $param_conf = _get_cons_param_conf(\%cons_conf_db,
							      $1, $2);

			$param_conf->[$PARAM_CONF_T_VALUE] = $value;
		} else {
			$err = "unknown key '$key'";
			goto err;
		}
	}
	if ($filename ne "-"){
		close($handle);
	}

	# Ensure minimum content
	if (!defined($profile_id)) {
		$err = "missing profile ID";
		goto err;
	}
	if (!defined($desc)) {
		$err = "missing description";
		goto err;
	}

	# Compress host array
	@hosts = grep { defined($_) } @hosts;

	return [ $profile_id, $desc, \@hosts, \%check_conf_db, \%cons_conf_db,
		 $filename ];
err:
	if ($filename eq "-") {
		die ("Error in profile read from standard input, line $.: ".
		     "$err!\n");
	} else {
		die("Error in profile '$filename', line $.: $err!\n");
	}
}

#
# _create_empty_profile(profile_id, desc[, system])
#
# Create and return an empty profile with the specified PROFILE_ID and
# DESC.
#
sub _create_empty_profile($$;$)
{
	my ($profile_id, $desc, $system) = @_;
	my $install_dir = udata_get_path($DB_PROFILE_DIR);
	my $filename = catfile($install_dir, $profile_id);

	if (!defined($system)) {
		$system = $opt_system ? 1 : 0;
	}
	return [ $profile_id, $desc, [ ], {}, {}, $filename, $system, 1 ];
}

#
# _create_initial_profile_db()
#
# Create and an initial profile database containing a single empty
# profile. Return (profile_db, active_id).
#
sub _create_initial_profile_db()
{
	my %profile_db;
	my $active_profile = _create_empty_profile($DEFAULT_PROFILE_ID,
						   $DEFAULT_PROFILE_DESC, 0);
	my $active_id = $active_profile->[$PROFILE_T_ID];

	# Set database
	$profile_db{$active_id} = $active_profile;

	return (\%profile_db, $active_id);
}

#
# db_profile_set_modified([profile_id])
#
# Mark profile DB as modified. If PROFILE_ID is specified, mark this profile
# as modified as well.
#
sub db_profile_set_modified(;$)
{
	my ($profile_id) = @_;

	if (defined($profile_id)) {
		my $profile = $_profile_db->{$profile_id};

		if (defined($profile)) {
			$profile->[$PROFILE_T_MODIFIED] = 1;
		}
	}

	# Set modified marker
	$_modified_profile_db = 1;

	# Mark profile DB cache as out-of-date
	db_invalidate_cache($DB_PROFILE_CACHE_FILENAME);
}

#
# _read_profile_db()
#
# Read profiles from database.
#
sub _read_profile_db()
{
	my $profile_dirs = db_get_dirs($DB_PROFILE_DIR);
	my %profile_db;
	my $active_id;

	foreach my $dir (@$profile_dirs) {
		my ($path, $system) = @$dir;
		my $handle;

		info3("Reading profiles from '$path'\n");
		if (!opendir($handle, $path)) {
			info3("Skipping profile database at '$path': $!\n");
			next;
		}
		foreach my $entry (readdir($handle)) {
			my $profile;
			my $profile_id;
			my $filename = catfile($path, $entry);

			# Skip directories
			next if (!-f $filename);

			if ($entry eq $DB_ACTIVE_PROFILE_FILENAME) {
				$active_id = read_file($filename);
				chomp($active_id);
				next;
			} elsif ($entry !~ /^$MATCH_ID$/) {
				next;
			}

			info3("  $entry\n");
			$profile = _read_profile($filename);
			$profile->[$PROFILE_T_SYSTEM] = $system;
			$profile_id = $profile->[$PROFILE_T_ID];
			if (exists($profile_db{$profile_id})) {
				my $old_profile = $profile_db{$profile_id};

				if ($old_profile->[$PROFILE_T_FILENAME] eq
				    $profile->[$PROFILE_T_FILENAME]) {
					# A DB path has been specified multiple
					# times
					next;
				}

				warn(<<EOF);
Duplicate definition of profile '$profile_id' (keeping second one):
  $old_profile->[$PROFILE_T_FILENAME] and
  $profile->[$PROFILE_T_FILENAME]
EOF
			}
			$profile_db{$profile_id} = $profile;
		}
		closedir($handle);
	}

	return [ \%profile_db, $active_id ];
}

#
# _init_profile_db()
#
# Initialize profile database.
#
sub _init_profile_db()
{
	my $data;

	# Get data from cache or database
	($data, $_profile_db_version) =
		db_init($DB_PROFILE_DIR, $DB_PROFILE_CACHE_FILENAME,
			\&_read_profile_db);

	# Decode data if we got any
	if (defined($data)) {
		($_profile_db, $_active_profile_id) = @$data;
	}

	# Check if profile DB is available
	if (!defined($_profile_db) || !%{$_profile_db}) {
		# Create default profile DB
		($_profile_db, $_active_profile_id) =
			_create_initial_profile_db();

		db_profile_set_modified($_active_profile_id);
	}

	# Check if active ID is available
	if (!defined($_active_profile_id) || !exists($_profile_db->{$_active_profile_id})) {
		my $old_active_profile_id = $_active_profile_id;

		# Check for a default entry
		if (exists($_profile_db->{$DEFAULT_PROFILE_ID})) {
			$_active_profile_id = $DEFAULT_PROFILE_ID;
		} else {
			# Use first in alphabetical order
			my @profile_ids = sort(keys(%{$_profile_db}));

			$_active_profile_id = $profile_ids[0];
		}

		if (defined($old_active_profile_id)) {
			warn("Previous active profile '$old_active_profile_id' no ".
			     "longer exists - using '$_active_profile_id' instead\n");
		}

		db_profile_set_modified();
	}
}

#
# _write_profile_db()
#
# Write profile database.
#
sub _write_profile_db()
{
	my $install_dir = db_get_install_dir($DB_PROFILE_DIR);
	my $user_install_dir = udata_get_path($DB_PROFILE_DIR);
	my $caching = lnxhcrc_get($LNXHCRC_ID_T_DB_CACHING);
	my $dirname;

	info3("Writing profile database to '$install_dir'\n");
	# Check if install directory exists
	if (!-d $install_dir) {
		create_path($install_dir, $DB_INSTALL_PERM_DIR);
	}

	# Write modified profiles
	foreach my $profile_id (keys(%{$_profile_db})) {
		my $profile = $_profile_db->{$profile_id};
		my $filename = $profile->[$PROFILE_T_FILENAME];

		# Ignore unchanged profiles
		next if (!$profile->[$PROFILE_T_MODIFIED]);
		# Define filename if necessary
		if (!defined($filename)) {
			$filename = catfile($install_dir, $profile_id);
			$profile->[$PROFILE_T_FILENAME] = $filename;
		}
		info3("  $filename\n");
		# Write profile
		$dirname = dirname($filename);
		if (! -d $dirname) {
			create_path($dirname, $DB_INSTALL_PERM_DIR);
		}
		_write_profile($profile, $filename);
	}

	# Write active profile ID.
	if (!-d $user_install_dir) {
		create_path($user_install_dir, $DB_INSTALL_PERM_DIR);
	}
	write_file(catfile($user_install_dir, $DB_ACTIVE_PROFILE_FILENAME),
		   $_active_profile_id."\n", $DB_INSTALL_PERM_NON_EXEC);

	if ($caching) {
		# Update DB cache file
		db_write_cache($DB_PROFILE_CACHE_FILENAME,
			       [ $_profile_db, $_active_profile_id ],
			       db_generate_version($DB_PROFILE_DIR));
	}
}

#
# db_profile_exists(profile_id)
#
# Return non-zero if profile with specified PROFILE_ID exists.
#
sub db_profile_exists($)
{
	my ($profile_id) = @_;

	# Lazy profile database initialization
	_init_profile_db() if (!defined($_profile_db));

	if (defined($_profile_db->{$profile_id})) {
		return 1;
	}

	return 0;
}

#
# db_profile_get(profile_id[, nodie])
#
# Return profile with specified PROFILE_ID. Die if profile does not exist.
#
sub db_profile_get($;$)
{
	my ($profile_id, $nodie) = @_;
	my $profile;

	# Lazy profile database initialization
	_init_profile_db() if (!defined($_profile_db));

	$profile = $_profile_db->{$profile_id};
	if (!defined($profile)) {
		if ($nodie) {
			return undef;
		}
		die("Profile '$profile_id' does not exist!\n");
	}

	return $profile;
}

#
# db_profile_is_empty()
#
# Return non-zero if profile database is empty.
#
sub db_profile_is_empty()
{
	# Lazy profile database initialization
	_init_profile_db() if (!defined($_profile_db));

	if (!%{$_profile_db}) {
		return 1;
	}

	return 0;
}

#
# db_profile_get_ids()
#
# Return list of all profile IDs.
#
sub db_profile_get_ids()
{
	# Lazy profile database initialization
	_init_profile_db() if (!defined($_profile_db));

	return sort(keys(%{$_profile_db}));
}

#
# db_profile_install(profile)
#
# Add profile PROFILE to database.
#
sub db_profile_install($)
{
	my ($profile) = @_;
	my $profile_id = $profile->[$PROFILE_T_ID];
	my $install_dir = db_get_install_dir($DB_PROFILE_DIR);

	# Lazy profile database initialization
	_init_profile_db() if (!defined($_profile_db));

	if (exists($_profile_db->{$profile_id})) {
		die("Profile '$profile_id' already exists!\n");
	}
	# Check if install directory exists
	if (!-d $install_dir) {
		create_path($install_dir, $DB_INSTALL_PERM_DIR);
	}
	# Check for write access to install directory
	if (!-w $install_dir) {
		die("Insufficient write permissions for directory ".
		    "'$install_dir'\n");
	}

	$profile->[$PROFILE_T_FILENAME] = catfile($install_dir, $profile_id);
	$profile->[$PROFILE_T_SYSTEM] = $opt_system ? 1 : 0;

	# Add to database and mark for writeback
	$_profile_db->{$profile_id} = $profile;
	db_profile_set_modified($profile_id);
}

#
# db_profile_check_modify(profile_id)
#
# Check if profile PROFILE_ID can be modified. Die if it can't.
#
sub db_profile_check_modify($)
{
	my ($profile_id) = @_;
	my $profile;
	my $system;
	my $filename;
	my $directory;

	# Lazy profile database initialization
	_init_profile_db() if (!defined($_profile_db));

	# Check if profile exists
	if (!exists($_profile_db->{$profile_id})) {
		return;
	}
	$profile = $_profile_db->{$profile_id};
	$system = $profile->[$PROFILE_T_SYSTEM];
	if ($system && !$opt_system) {
		die("Cannot modify system-wide profile '$profile_id' without ".
		    "--system!\n");
	} elsif (!$system && $opt_system) {
		die("Cannot modify user profile '$profile_id' with ".
		    "--system!\n");
	}

	# Check for write access to profile directory
	$filename = $profile->[$PROFILE_T_FILENAME];
	$directory = dirname($filename);
	if (-e $directory && !-w $directory) {
		die("Cannot modify profile '$profile_id': insufficient write ".
		    "permissions for directory '$directory'!\n");
	}
	if (-e $filename && !-w $filename) {
		die("Cannot modify profile '$profile_id': insufficient write ".
		    "permissions for file '$filename'!\n");
	}
}

#
# db_profile_uninstall(profile_id)
#
# Persistently remove profile PROFILE_ID from database.
#
sub db_profile_uninstall($)
{
	my ($profile_id) = @_;
	my $profile;
	my $filename;

	db_profile_check_modify($profile_id);
	$profile = $_profile_db->{$profile_id};
	$filename = $profile->[$PROFILE_T_FILENAME];

	# Remove file
	unlink($filename) or die("Could not remove '$filename': $!\n");

	# Remove from database
	delete($_profile_db->{$profile_id});

	# Mark profile DB as modified
	db_profile_set_modified();
}

#
# db_profile_disable_writeback()
#
# Instruct database not to write back changes to the profile database at
# program termination.
#
sub db_profile_disable_writeback()
{
	$_writeback_enabled = 0;
}

#
# db_profile_get_active_id()
#
# Return ID of active profile.
#
sub db_profile_get_active_id()
{
	# Lazy profile database initialization
	_init_profile_db() if (!defined($_profile_db));

	return $_active_profile_id;
}

#
# db_profile_set_active_id(profile_id)
#
# Activate profile PROFILE_ID.
#
sub db_profile_set_active_id($)
{
	my ($profile_id) = @_;

	# Lazy profile database initialization
	_init_profile_db() if (!defined($_profile_db));

	if (!exists($_profile_db->{$profile_id})) {
		die("Profile '$profile_id' does not exist!\n");
	}

	$_active_profile_id = $profile_id;

	# Set modified marker
	db_profile_set_modified();
}

#
# db_profile_rename(source_id, target_id)
#
# Change ID of profile SOURCE_ID to TARGET_ID.
#
sub db_profile_rename($$)
{
	my ($source_id, $target_id) = @_;
	my $profile;

	# Lazy profile database initialization
	_init_profile_db() if (!defined($_profile_db));

	if (!exists($_profile_db->{$source_id})) {
		die("Profile '$source_id' does not exist!\n");
	}
	if (exists($_profile_db->{$target_id})) {
		die("Profile '$target_id' already exists!\n");
	}

	$profile = $_profile_db->{$source_id};
	delete($_profile_db->{$source_id});
	$profile->[$PROFILE_T_ID] = $target_id;
	$_profile_db->{$target_id} = $profile;

	if ($_active_profile_id eq $source_id) {
		$_active_profile_id = $target_id;
	}

	# Set modified marker
	db_profile_set_modified();
}

#
# db_profile_copy(source_id, target_id)
#
# Copy profile SOURCE_ID to new profile TARGET_ID.
#
sub db_profile_copy($$)
{
	my ($source_id, $target_id) = @_;
	my $profile = dclone(db_profile_get($source_id));

	$profile->[$PROFILE_T_ID] = $target_id;
	db_profile_install($profile);
}

#
# _merge_profile(source, target)
#
# Add configuration data from profile SOURCE to TARGET.
#
sub _merge_profile($$)
{
	my ($source, $target) = @_;
	my $copy = dclone($source);
	my $src_check_conf_db = $copy->[$PROFILE_T_CHECK_CONF_DB];
	my $src_cons_conf_db = $copy->[$PROFILE_T_CONS_CONF_DB];
	my $tgt_check_conf_db = $target->[$PROFILE_T_CHECK_CONF_DB];
	my $tgt_cons_conf_db = $target->[$PROFILE_T_CONS_CONF_DB];
	my @hosts;

	# Merge host lists
	@hosts = unique(@{$copy->[$PROFILE_T_HOSTS]},
			@{$target->[$PROFILE_T_HOSTS]});
	$target->[$PROFILE_T_HOSTS] = \@hosts;

	# Merge check configuration
	foreach my $check_id (keys(%{$src_check_conf_db})) {
		$tgt_check_conf_db->{$check_id} =
			$src_check_conf_db->{$check_id};
	}

	# Merge consumer configuration
	foreach my $cons_id (keys(%{$src_cons_conf_db})) {
		$tgt_cons_conf_db->{$cons_id} = $src_cons_conf_db->{$cons_id};
	}
}

#
# db_profile_merge(source_id, target_id)
#
# Add configuration data from profile SOURCE_ID to TARGET_ID.
#
sub db_profile_merge($$)
{
	my ($source_id, $target_id) = @_;

	db_profile_check_modify($target_id);
	_merge_profile(db_profile_get($source_id), db_profile_get($target_id));
	db_profile_set_modified($target_id);
}

#
# db_profile_import(filename[, profile_id[, merge]])
#
# Read profile from FILENAME and store it in database. If PROFILE_ID is
# specified, use this as profile ID. If MERGE is non-zero and a profile
# with the specified ID already exists, add data from file to that profile.
# Otherwise abort if the profile already exists.
#
sub db_profile_import($;$$)
{
	my ($filename, $profile_id, $merge) = @_;
	my $profile = _read_profile($filename);

	# Lazy profile database initialization
	_init_profile_db() if (!defined($_profile_db));

	if (defined($profile_id)) {
		# Modify ID of read profile
		$profile->[$PROFILE_T_ID] = $profile_id;
	} else {
		# Get ID of read profile
		$profile_id = $profile->[$PROFILE_T_ID];
	}

	if (exists($_profile_db->{$profile_id})) {
		db_profile_check_modify($profile_id);
		if ($merge) {
			_merge_profile($profile, $_profile_db->{$profile_id});
		} else {
			my $target = $_profile_db->{$profile_id};

			$profile->[$PROFILE_T_FILENAME] =
				$target->[$PROFILE_T_FILENAME];
			$profile->[$PROFILE_T_SYSTEM] =
				$target->[$PROFILE_T_SYSTEM];
			$_profile_db->{$profile_id} = $profile;
		}
		db_profile_set_modified($profile_id);
	} else {
		db_profile_install($profile);
	}
}

#
# db_profile_export(filename, profile_id)
#
# Write profile with specified PROFILE_ID to file FILENAME.
#
sub db_profile_export($$)
{
	my ($filename, $profile_id) = @_;
	my $profile = db_profile_get($profile_id);

	_write_profile($profile, $filename);
}

#
# db_profile_new(profile_id)
#
# Add an empty profile with the specified ID to the database.
#
sub db_profile_new($)
{
	my ($profile_id) = @_;
	my $profile = _create_empty_profile($profile_id, "");

	db_profile_install($profile);
}


#
# Code entry
#

# Ensure that configuration data is written at program termination
END {
	if ($_modified_profile_db && $_writeback_enabled) {
		_write_profile_db();
		$_modified_profile_db = undef;
	}
};

# Indicate successful module initialization
1;
