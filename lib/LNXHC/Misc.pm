#
# LNXHC::Misc.pm
#   Linux Health Checker miscellaneous support functions
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

package LNXHC::Misc;

use strict;
use warnings;

use Exporter qw(import);
use Time::HiRes;
use Sys::Hostname qw(hostname);
use File::Basename qw(dirname);
use File::Temp qw(tempfile);
use File::Spec::Functions qw(splitpath splitdir catpath catdir catfile);
use MIME::Base64 qw(encode_base64 decode_base64);
use Storable qw(lock_store lock_retrieve);
use Term::ANSIColor;

#
# Local imports
#
use LNXHC::Consts qw($CAT_TOOL $COLUMNS $CONS_TYPE_T_HANDLER $CONS_TYPE_T_REPORT
		     $DB_INSTALL_PERM_DIR $DB_INSTALL_PERM_EXEC
		     $DB_INSTALL_PERM_NON_EXEC $MATCH_ID $MATCH_ID_CHAR
		     $MATCH_ID_WILDCARD $SEVERITY_T_HIGH $SEVERITY_T_LOW
		     $SEVERITY_T_MEDIUM $SI_TYPE_T_EXT $SI_TYPE_T_FILE
		     $SI_TYPE_T_PROG $SI_TYPE_T_REC $SI_TYPE_T_REF $SPEC_T_ID
		     $SPEC_T_KEY $SPEC_T_UNKNOWN $SPEC_T_WILDCARD
		     $STATE_T_ACTIVE $STATE_T_INACTIVE);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw($opt_debug $opt_help $opt_quiet $opt_system $opt_user_dir
		    $opt_verbose $opt_version $stdout_used_for_data
		    $opt_color
		    &check_opt_system &cons_type_to_str &copy_file &copy_files
		    &create_path &create_temp_file &debug &debug2
		    &duration_to_sec &filter_ids_by_wildcard &get_db_scope
		    &get_home_dir &get_hostname &get_indented &get_spec_type
		    &get_time &get_timestamp &info &info1 &info2 &info3
		    &match_wildcard &normalize_duration &output_filename
		    &print_indented &print_padded &quiet_retrieve &quiet_store
		    &quote &read_file &read_file_as &read_stdin
		    &resolve_entities &rm_rf &run_cmd &sec_to_duration
		    &sev_to_str &si_type_to_str &state_to_str &str_to_sev
		    &str_to_state &system_to_str &timestamp_to_str &unique
		    &unquote &unquote_nodie &validate_duration
		    &validate_duration_nodie &validate_id &validate_severity
		    &validate_state &write_file &xml_decode_data
		    &xml_decode_predeclared &xml_encode_data
		    &xml_encode_predeclared &yesno_to_str &term_use_color
		    &needs_user_id_change &get_colors);


#
# Constants
#


#
#
# Global variables
#

# Flag indicating whether STDOUT is currently used for data
our $stdout_used_for_data = 0;

# Global options
our $opt_debug = 0;
our $opt_verbose = 0;
our $opt_quiet = 0;
our $opt_help;
our $opt_version;
our $opt_user_dir;
our $opt_system;
our $opt_color;

my $_last_debug;
my $_use_color;


#
# Sub-routines
#

#
# debug(message)
#
# If --debug was specified by the user, print this debugging message.
#
sub debug($)
{
	my ($msg) = @_;
	my $sub;
	my $line_no;
	my $line;
	my $time;
	my $now = get_timestamp();

	# Only print debugging messages if enabled by the user
	if (!$opt_debug) {
		return;
	}

	# Add name of calling sub-routine to message
	$line_no = (caller(0))[2];
	$sub = (caller(1))[3];

	if (defined($_last_debug)) {
		$time = "+".sprintf("%.3fs", $now - $_last_debug);
	} else {
		$time = sprintf("%.3fs", $now);
	}
	$_last_debug = $now;

	foreach $line (split(/\n/, $msg)) {
		print("  $line\n");
	}
}

#
# debug2(message)
#
# If --debug was specified twice by the user, print this internal debugging
# message.
#
sub debug2($)
{
	my ($msg) = @_;

	# Only print debugging messages if enabled by the user
	if ($opt_debug < 2) {
		return;
	}

	debug($msg);
}

#
# info(message)
#
# Print message unless user specified --quiet on the command line.
#
sub info($)
{
	my ($msg) = @_;

	# Only print informational messages if not suppressed by user
	if ($opt_quiet) {
		return;
	}

	# Print to STDERR if STDOUT is currently being used for data
	if ($stdout_used_for_data) {
		print(STDERR $msg);
	} else {
		print($msg);
	}
}

#
# info1(message)
#
# Print message if user specified --verbose at least once on the command line.
#
sub info1($)
{
	my ($msg) = @_;

	# Only print informational messages if requested by the user
	if ($opt_quiet || $opt_verbose < 1) {
		return;
	}

	# Print to STDERR if STDOUT is currently being used for data
	if ($stdout_used_for_data) {
		print(STDERR $msg);
	} else {
		print($msg);
	}
}

#
# info2(message)
#
# Print message if user specified --verbose at least twice on the command line.
#
sub info2($)
{
	my ($msg) = @_;

	# Only print informational messages if requested by the user
	if ($opt_quiet || $opt_verbose < 2) {
		return;
	}

	# Print to STDERR if STDOUT is currently being used for data
	if ($stdout_used_for_data) {
		print(STDERR $msg);
	} else {
		print($msg);
	}
}

#
# info3(message)
#
# Print message if user specified --verbose at least three times on the
# command line.
#
sub info3($)
{
	my ($msg) = @_;

	# Only print informational messages if requested by the user
	if ($opt_quiet || $opt_verbose < 3) {
		return;
	}

	# Print to STDERR if STDOUT is currently being used for data
	if ($stdout_used_for_data) {
		print(STDERR $msg);
	} else {
		print($msg);
	}
}

#
# unique(array)
#
# Return ARRAY without duplicates.
#
sub unique(@)
{
	my (@array) = @_;
	my @result;
	my %items;
	my $item;

	foreach $item (@array) {
		next if (defined($items{$item}));
		push(@result, $item);
		$items{$item} = 1;
	}

	return @result;
}

#
# needs_user_id_change(user)
#
# Return non-zero if a user ID change is required to obtain the access rights
# of the specified USER. Return zero otherwise or if USER is unspecified
# or equals the empty string.
#
sub needs_user_id_change($)
{
	my ($user) = @_;
	my $uid = getpwuid($>);

	return 0 if (!defined($user) || $user eq "");
	return 1 if (!defined($uid));
	return 1 if ($uid ne $user);

	return 0;
}

#
# run_cmd(cmd [,user[, nodie[, input[, env[, no_capture]]]]])
#
# Run command specified by CMD and return the resulting output to the standard
# output and standard error stream as well as the exit code. If specified,
# run the command as USER. If NODIE is non-zero, return if the command could
# not be run. Otherwise abort. If NO_CAPTURE is non-zero, don't capture
# program output - instead the command will have direct access to STDOUT.
#
# On success:
# result: [ undef, exit_code, output ]
# If command could not be started and NODIE=1:
# result: [ error_message, undef, undef ]
#
sub run_cmd($;$$$$$)
{
	my ($cmd, $user, $nodie, $input, $env, $no_capture) = @_;
	my $orig_cmd;
	my $exit_code = 0;
	my $signal = 0;
	my $output;
	my $err;
	my %old_env;
	my $rc;
	my $handle;
	my $input_file;

	# User change
	if (defined($user) && needs_user_id_change($user)) {
		# Add sudo statement
		info("Changing user to '$user' for command '$cmd'\n");
		$cmd = "sudo -u $user -- $cmd";
	}
	$orig_cmd = $cmd;
	# Program input
	if (defined($input)) {
		$input_file = create_temp_file($input);
		$cmd .= " <$input_file";
	}
	# Environment variables
	if (defined($env)) {
		my $var;

		%old_env = %ENV;
		# Set environment variables
		foreach $var (keys(%{$env})) {
			$ENV{$var} = $env->{$var};
		}
	}

	debug("Run command '$cmd'\n");
	if ($no_capture) {
		# Run program
		$rc = system($cmd);
		debug("Run finished (system=$rc \$!='$!' \$?='$?')\n");

		# Reset environment variables
		%ENV = %old_env if (defined($env));

		# Was there an error running the command?
		goto error_open if ($rc == -1);

		# Apparently not, get the exit code and signal number
		$exit_code = $rc >> 8;
		$signal = $rc & 127;
	} else {
		# Run program
		$rc = open($handle, "$cmd 2>&1|");

		# Reset environment variables
		%ENV = %old_env if (defined($env));

		# Was there an error running the command?
		goto error_open if (!$rc);

		# Read all of the command output in one go
		local $/;
		$output = <$handle>;
		$rc = close($handle);
		debug("Run finished (close=$rc \$!='$!' \$?='$?')\n");

		if (!$rc) {
			# Was there an error apart from a non-zero exit code?
			goto error_close if ($!);

			# Apparently not, get the exit code and signal number
			$exit_code = $? >> 8;
			$signal = $rc & 127;
		}
	}

	if (defined($input_file)) {
		unlink($input_file) or
			warn("Could not remove temporary file '$input_file'\n");
	}

	if ($signal == 2) {
		main::int_handler();
	}

	return (undef, $exit_code, $output);

error_open:
	$err = "could not run command '$orig_cmd': $!\n";
	if ($nodie) {
		return ($err, undef, undef);
	}
	die($err);
error_close:
	$err = "error while running command '$orig_cmd': $!\n";
	if ($nodie) {
		return ($err, undef, undef);
	}
	die($err);
}

#
# write_file(filename, contents[, perm, nodie])
#
# Write CONTENTS to file FILENAME. If an error occurs and NODIE is non-zero,
# return the error message. Otherwise abort. Return undef on success.
#
sub write_file($$;$$)
{
	my ($filename, $contents, $perm, $nodie) = @_;
	my $msg;
	my $handle;

	if (!open($handle, ">", $filename)) {
		$msg = "could not write to file '$filename': $!\n";

		goto err;
	}
	print($handle $contents);
	if (!close($handle)) {
		$msg = "could not write to file '$filename': $!\n";

		goto err;
	}

	if (defined($perm)) {
		if ($perm =~ /^\+(.*)$/) {
			# Add permissions
			$perm = ((stat $filename)[2] & 07777) | oct($1);
		} elsif ($perm =~ /^\-(.*=)$/) {
			# Remove permissions
			$perm = ((stat $filename)[2] & 07777) & ~oct($1);
		}
		if (!chmod($perm, $filename)) {
			$msg = "could not change permission of '$filename': ".
			       "$!\n";
			goto err;
		}
	}

	return undef;
err:
	if ($nodie) {
		return $msg;
	}
	die($msg);
}

#
# read_file(filename[, nodie])
#
# Read and return contents of file FILENAME. If NODIE is non-zero, return
# ( error_message, undef ) if the file could not be read. Otherwise abort.
#
sub read_file($;$)
{
	my ($filename, $nodie) = @_;
	my $result;
	my $err;
	my $handle;

	open($handle, "<", $filename) or goto error;
	# Read all of the file in one go
	local $/;
	$result = <$handle>;
	close($handle);

	return (undef, $result);
error:
	$err = "could not open '$filename': $!\n";
	if ($nodie) {
		return ($err, undef);
	}
	die($err);
}

#
# read_stdin()
#
# Read data from STDIN and return resulting data.
#
sub read_stdin()
{
	my $result;

	local $/;
	$result = <STDIN>;

	return $result;
}

#
# read_file_as(filename, user[, nodie]])
#
# Read and return contents of file FILENAME as user USER. If NODIE is non-zero,
# return ( error message, undef ) if the file could not be read. Otherwise
# abort.
#
sub read_file_as($$;$)
{
	my ($filename, $user, $nodie) = @_;
	my $err;
	my $exit_code;
	my $output;

	($err, $exit_code, $output ) = run_cmd("$CAT_TOOL $filename", $user,
					       $nodie);
	if (defined($err)) {
		# Could not run command, provide error message
		return ($err, undef);
	}
	if ($exit_code != 0) {
		# cat or sudo command failed, provide error output as error
		# message
		return ($output, undef);
	}

	return (undef, $output);
}

#
# get_timestamp()
#
# Return the current timestamp.
#
sub get_timestamp()
{
	return Time::HiRes::time();
}

#
# timestamp_to_str(timestamp[, show_ms])
#
# Return string representation of the specified timestamp.
#
sub timestamp_to_str($;$)
{
	my ($timestamp, $show_ms) = @_;
	my ($s, $min, $h, $d, $m, $y) = localtime(int($timestamp));
	my $result;

	# Add milliseconds
	$s += (($timestamp - int($timestamp)) * 1000) / 1000;
	$y += 1900;
	$m++;

	$result = sprintf("%04d-%02d-%02d %02d:%02d:", $y, $m, $d, $h, $min);
	if ($show_ms) {
		$result .= sprintf("%02.3f", $s);
	} else {
		$result .= sprintf("%02d", $s);
	}

	return $result;
}

#
# duration_to_sec(duration[, empty_ok])
#
# Parse DURATION. Return (undef, seconds) if it is a valid duration,
# (err, undef) otherwise. If EMPTY_OK is non-zero, an empty duration is not
# considered an error.
#
sub duration_to_sec($;$)
{
	my ($duration, $empty_ok) = @_;
	my $value = $duration;
	my @comps;
	my $err;
	my $result;
	my %specified;
	my %units = (
		"d" => [ "days",	24 * 60 * 60 ],
		"h" => [ "hours",	60 * 60 ],
		"m" => [ "minutes",	60 ],
		"s" => [ "seconds",	1 ],
	);

	# Check for empty durration
	if ($value =~ /^\s*$/) {
		goto out if ($empty_ok);
		$err = "duration cannot be empty";
		goto err;
	}

	# Split into components
	$value =~ s/(\d+)/\0$1/g;
	@comps = split(/\0/, $value);

	$result = 0;
	foreach my $comp (@comps) {
		my ($number, $unit);
		my ($name, $factor);
		my $in_seconds;

		next if ($comp eq "");

		# Is component valid?
		if ($comp !~ /^\s*(\d+)\s*([dhms]?)\s*$/i) {
			$err = "duration cannot contain '$comp'";
			goto err;
		}
		# Is the value too high?
		($number, $unit) = ($1, lc($2));
		if ($number ne sprintf("%u", $number)) {
			$err = "duration exceeds maximum";
			goto err;
		}
		# Was the unit specified multiple times?
		$unit = "s" if ($unit eq "");
		($name, $factor) = @{$units{$unit}};
		if (exists($specified{$unit})) {
			$err = "number of ".$name." is specified multiple ".
			       "times";
			goto err;
		}
		$specified{$unit} = 1;
		# Is the value too high (cont)?
		$in_seconds = $factor * $number;
		if ($in_seconds ne sprintf("%u", $in_seconds)) {
			$err = "duration exceeds maximum";
			goto err;
		}
		# Is the total value too high?
		$result += $in_seconds;
		if ($result ne sprintf("%u", $result)) {
			$err = "duration exceeds maximum";
			goto err;
		}
	}

out:
	return (undef, $result);

err:
	return ("Unsupported duration '$duration': $err", undef);
}

#
# validate_duration_nodie(duration[, empty_ok])
#
# Check if DURATION is a valid textual representation of a duration.
# Return undef if it is valid, an error message otherwise.
#
sub validate_duration_nodie($;$)
{
	my ($duration, $empty_ok) = @_;
	my ($err) = duration_to_sec($duration, $empty_ok);

	return $err;
}

#
# validate_duration(duration, [empty_ok, source])
#
# Validate that DURATION is a valid textual representation of a duration.
# Die if there is an error in the duration. SOURCE specifies the source of
# the duration value for use in the error message.
#
sub validate_duration($;$$)
{
	my ($duration, $empty_ok, $source) = @_;
	my $err = validate_duration_nodie($duration, $empty_ok);

	return if (!defined($err));

	$err = "$source: $err" if (defined($source));

	die("$err!\n");
}

#
# get_time([offset])
#
# Return current time.
#
sub get_time(;$)
{
	my ($offset) = @_;
	my $sec;
	my $min;
	my $hour;

	if (!defined($offset)) {
		$offset = 0;
	}
	($sec, $min, $hour) = localtime(time() + $offset);

	return sprintf("%02d:%02d:%02d", $hour, $min, $sec);
}

#
# get_indented(msg, indent)
#
# Return MSG formatted for printing with an indentation of INDENT characters.
#
sub get_indented($$)
{
	my ($msg, $indent) = @_;
	my $line;
	my $result = "";

	foreach $line (split(/\n/, $msg)) {
		my $out = " "x$indent;
		my $word;
		my $first = 1;

		foreach $word (split(/\s+/, $line)) {
			if ((length($out) + 1 + length($word)) > $COLUMNS) {
				$result .= $out."\n";
				$out = " "x$indent;
				$first = 1;
			}
			if ($first) {
				$first = 0;
			} else {
				$out .= " ";
			}
			$out .= $word;
		}
		$result .= $out."\n";
	}

	return $result;
}

#
# print_indented(msg, indent)
#
# Print message MSG with an indentation of INDENT characters.
#
sub print_indented($$)
{
	my ($msg, $indent) = @_;

	print(get_indented($msg, $indent));
}

#
# validate_state(state)
#
# Check if STATE is a valid textual representation of an activation state.
# Return undef if it is valid, an error message otherwise.
#
sub validate_state($)
{
	my ($state) = @_;

	$state =~ s/(^\s*)|(\s*$)//g;

	if ($state ne $STATE_T_ACTIVE && $state ne $STATE_T_INACTIVE &&
	    $state ne "active" && $state ne "inactive") {
		return "unknown activation state '$state'";
	}

	return undef;
}

#
# str_to_state(str[, source])
#
# Convert string STR into an activation state. Abort if conversion fails.
#
sub str_to_state($;$)
{
	my ($str, $source) = @_;

	if (($str =~ /^\s*active\s*$/i) || $str eq "$STATE_T_ACTIVE") {
		return $STATE_T_ACTIVE;
	} elsif (($str =~ /^\s*inactive\s*$/i) || $str eq "$STATE_T_INACTIVE") {
		return $STATE_T_INACTIVE;
	}

	if (!defined($source)) {
		$source = "";
	} else {
		$source .= ": ";
	}

	die($source."unrecognized activation state '$str'\n");
}

#
# validate_severity(severity)
#
# Check if SEVERITY is a valid textual representation of a severity level.
# Return undef if it is valid, an error message otherwise.
#
sub validate_severity($)
{
	my ($severity) = @_;

	$severity =~ s/(^\s*)|(\s*$)//g;

	if ($severity ne $SEVERITY_T_LOW && $severity ne $SEVERITY_T_MEDIUM &&
	    $severity ne $SEVERITY_T_HIGH && $severity ne "low" &&
	    $severity ne "medium" && $severity ne "high") {
		return "unknown severity level '$severity'";
	}

	return undef;
}

#
# str_to_sev(str[, source])
#
# Convert string STR into a severity level. Abort if conversion fails.
#
sub str_to_sev($;$)
{
	my ($str, $source) = @_;

	if (($str =~ /^\s*low\s*$/) || ($str eq "$SEVERITY_T_LOW")) {
		return $SEVERITY_T_LOW;
	} elsif (($str =~ /^\s*medium\s*$/) || ($str eq "$SEVERITY_T_MEDIUM")) {
		return $SEVERITY_T_MEDIUM;
	} elsif (($str =~ /^\s*high\s*$/) || ($str eq "$SEVERITY_T_HIGH")) {
		return $SEVERITY_T_HIGH;
	}
	if (!defined($source)) {
		$source = "";
	} else {
		$source .= ": ";
	}

	die($source."unrecognized severity level '$str'\n");
}

#
# state_to_str(state)
#
# Return a string representation of the specified STATE.
#
sub state_to_str($)
{
	my ($state) = @_;

	if ($state == $STATE_T_INACTIVE) {
		return "inactive";
	} elsif ($state == $STATE_T_ACTIVE) {
		return "active";
	}
	return "<unknown>";
}

#
# sev_to_str(severity)
#
# Return a string representation of the specified SEVERITY level.
#
sub sev_to_str($)
{
	my ($severity) = @_;

	if ($severity == $SEVERITY_T_LOW) {
		return "low";
	} elsif ($severity == $SEVERITY_T_MEDIUM) {
		return "medium";
	} elsif ($severity == $SEVERITY_T_HIGH) {
		return "high";
	}
	return "<unknown>";
}

#
# yesno_to_str(yesno)
#
# Return a string representation of the specified boolean value YESNO.
#
sub yesno_to_str($)
{
	my ($yesno) = @_;

	if ($yesno) {
		return "yes";
	} else {
		return "no";
	}
}

#
# si_type_to_str(type)
#
# Return a string representation of the specified sysinfo item type.
#
sub si_type_to_str($)
{
	my ($type) = @_;

	if ($type == $SI_TYPE_T_FILE) {
		return "file";
	} elsif ($type == $SI_TYPE_T_PROG) {
		return "program";
	} elsif ($type == $SI_TYPE_T_REC) {
		return "record";
	} elsif ($type == $SI_TYPE_T_REF) {
		return "reference";
	} elsif ($type == $SI_TYPE_T_EXT) {
		return "external";
	}
	return "";
}

#
# get_hostname()
#
# Return the name of the local host.
#
sub get_hostname()
{
	return hostname();
}

#
# create_temp_file([data])
#
# Create a temporary file and return its name. If DATA is specified, write
# it to the newly created file.
#
sub create_temp_file(;$)
{
	my ($data) = @_;
	my ($fh, $filename) = tempfile(UNLINK => 1);

	if (defined($data)) {
		print($fh $data) or die("could not write to '$filename': $!\n");
	}
	# If we don't close the filehandle here, it will remain open until
	# the process exits
	close($fh);

	return $filename;
}

#
# quote(value)
#
# Return a correctly quoted version of string VALUE.
#
sub quote($)
{
	my ($value) = @_;
	my $quote;

	# Find quotes which are not used in value string, fall back to double
	# quotes
	$quote = "\"";
	if (($value =~ /\"/) && !($value =~ /\'/)) {
		$quote = "'";
	}

	# Escape escape character ("\")
	$value =~ s/\\/\\\\/g;

	# Escape quotes in value string
	$value =~ s/$quote/\\$quote/g;

	# Add quotes
	$value = $quote.$value.$quote;

	return $value;
}

#
# unquote_nodie(text)
#
# Remove quotes. Return resulting string on success. On error, return
# (err, undef), where ERR contains a message with details on the error.
#
sub unquote_nodie($)
{
	my ($text) = @_;
	my $quote;

	# Remove leading and trailing whitespaces
	$text =~ s/^\s*//;
	$text =~ s/\s*$//;

	# Check for quotes
	$quote = '"' if ($text =~ /^"/);
	$quote = "'" if ($text =~ /^'/);

	# Handle quoting
	if ($quote) {
		my $check = $text;

		# Check for terminating quote
		$check =~ s/\\./x/g;
		if (!($check =~ /^$quote.*$quote$/)) {
			return ("unterminated quote in text string '$text'",
				undef);
		}
		# Remove quotes
		$text =~ s/^$quote(.*)$quote$/$1/;
	}

	return (undef, $text);
}

#
# unquote(text, [source])
#
# Return TEXT without quotes. In case of incorrect quoting, abort with an
# error message. If SOURCE is specified, use it in the error message.
#
sub unquote($;$)
{
	my ($text, $source) = @_;
	my $err;

	($err, $text) = unquote_nodie($text);
	# Handle error
	if (defined($err)) {
		if (defined($source)) {
			$err = "$source: $err";
		}
		die("$err!\n");
	}

	return $text;
}

#
# validate_id(type, id[, nodie[, source]])
#
# Validate that ID conforms to the rules for naming an entity of type TYPE.
# If NODIE is non-zero, return the resulting error message or undef if the
# ID is ok. If NODIE is zero, print the resulting error message and exit.
#
sub validate_id($$;$$)
{
	my ($type, $id, $nodie, $source) = @_;
	my $msg;

	if ($id eq "") {
		$msg = "Unsupported $type: cannot be empty\n";
		goto out;
	}
	if (!($id =~ /^$MATCH_ID$/)) {
		my $char = $id;

		if ($id =~ /^$MATCH_ID$/i) {
			$msg = "Unsupported $type '$id': may not contain ".
			       "uppercase letters\n";
			goto out;
		}
		$char =~ s/$MATCH_ID//g;
		$msg = "Unsupported $type '$id': may not contain '$char'\n";
		goto out;
	}
	# Ensure minimum ID length
	if (length($id) < 3) {
		$msg = "Unsupported $type '$id': must be between 3 and 40 ".
		       "characters long\n";
		goto out;
	}
	# Ensure maximum ID length
	if (length($id) > 40) {
		$msg = "Unsupported $type '$id': must be between 3 and 40 ".
		       "characters long\n";
		goto out;
	}
out:
	if (defined($msg) && defined($source)) {
		$msg = "$source: $msg";
	}
	if ($nodie) {
		return $msg;
	}
	if (defined($msg)) {
		die($msg);
	}
}

#
# get_home_dir()
#
# Return a file system path to the user's home directory.
#
sub get_home_dir()
{
	my $home;

	# Try directory from HOME environment variable
	$home = $ENV{"HOME"};
	if (defined($home)) {
		return $home;
	}
	# Try directory from passwd
	$home = (getpwuid($>))[7];

	return $home;
}

#
# resolve_entities(text, entities)
#
# Return TEXT with all entities (&<id>;) resolved. If a value for an entity
# was provided through the hash ENTITIES, that value will be used. Otherwise
# it will be replaced by string "<unresolved>".
#
sub resolve_entities($$)
{
	my ($text, $entities) = @_;

	$text =~ s/\&($MATCH_ID);/
		   (exists $entities->{$1}) ? $entities->{$1}
					    : "<unresolved>"/gex;

	return $text;
}

#
# xml_encode_predeclared(text)
#
# Return a copy of TEXT in which all occurrences of characters for which
# XML pre-declared entities exists have been replaced by the same.
#
sub xml_encode_predeclared($)
{
	my ($text) = @_;

	$text =~ s/&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/"/&quot;/g;
	$text =~ s/'/&apos;/g;

	return $text;
}

#
# xml_decode_predeclared(text)
#
# Return a copy of text in which all occurrences of XML pre-declared entities
# have been replaced with their corresponding characters.
#
sub xml_decode_predeclared($)
{
	my ($text) = @_;

	$text =~ s/&apos;/'/g;
	$text =~ s/&quot;/"/g;
	$text =~ s/&gt;/>/g;
	$text =~ s/&lt;/</g;
	$text =~ s/&amp;/&/g;

	return $text;
}

#
# xml_encode_data(data)
#
# If DATA contains non-printable characters, encode it in BASE64, otherwise
# only encode XML special characters as entities. Return (encoding, data)
# where ENCODING is either "none" or "base64", depending on the resulting
# encoding.
#
sub xml_encode_data($)
{
	my ($data) = @_;

	# Decide if data needs encoding
	if ($data =~ /[^[:print:]\n\t]/) {
		# Non-printable character found
		return ("base64", encode_base64($data));
	} else {
		return ("none", xml_encode_predeclared($data));
	}
}

#
# xml_decode_data(data, encoding)
#
# Decode DATA according to ENCODING. If ENCODING is "base64", perform
# base64 decoding. Otherwise only decode predeclared XML entities.
#
sub xml_decode_data($$)
{
	my ($data, $encoding) = @_;

	if (defined($encoding) && $encoding eq "base64") {
		return decode_base64($data);
	}

	return xml_decode_predeclared($data);
}

#
# print_padded(indent, width, key, value)
#
# Print KEY padded to WIDTH characters with ".", followed by VALUE.
#
sub print_padded($$$$)
{
	my ($indent, $width, $key, $value) = @_;

	print((" "x($indent)).$key.("."x($width - length($key))).": $value\n");
}

#
# create_path(path, perm)
#
# Create PATH and all non-existing parent directories with directory
# permissions PERM.
#
sub create_path($$)
{
	my ($path, $perm) = @_;
	my ($v, $d, $f) = splitpath($path, 1);
	my @dirs = splitdir($d);
	my @tocreate;
	my $dir;

	# Determine list of directories which need creating
	while (@dirs) {
		if ($dirs[$#dirs] eq "") {
			pop(@dirs);
			next;
		}
		$dir = catpath($v, catdir(@dirs), $f);

		# We're done if directory already exists
		if (-d $dir) {
			last;
		}
		push(@tocreate, $dir);
		pop(@dirs);
	}

	# Create directories
	while (@tocreate) {
		$dir = pop(@tocreate);

		mkdir($dir) or die("Could not create directory '$dir': $!\n");
		chmod($perm, $dir) or
			die("Could not set permissions for '$dir': $!\n");
	}
}

#
# copy_file(source, target, perm)
#
# Copy file from SOURCE to TARGET. Set file permissions PERM.
#
sub copy_file($$$)
{
	my ($source, $target, $perm) = @_;
	my $buff_size = 16384;
	my $buff;
	my $n;
	my $from_handle;
	my $to_handle;

	open($from_handle, "<", $source) or
		die("Could not read file '$source': $!!\n");
	binmode($from_handle);
	open($to_handle, ">", $target) or
		die("Could not create file '$target': $!!\n");
	while ($n = read($from_handle, $buff, $buff_size)) {
		print($to_handle $buff) or
			die("Could not write to file '$target': $!\n");;
	}
	if (!defined($n)) {
		die("Could not read file '$source': $!\n");
	}
	close($to_handle);
	close($from_handle);

	# Set file permissions
	chmod($perm, $target) or
		die("Could not set file permissions for '$target': $!\n");
}

#
# get_spec_type(spec)
#
# Return type of ID specification SPEC.
#
sub get_spec_type($)
{
	my ($spec) = @_;

	if ($spec =~ /^$MATCH_ID$/i) {
		return $SPEC_T_ID;
	} elsif ($spec =~ /^$MATCH_ID_WILDCARD$/i) {
		return $SPEC_T_WILDCARD;
	} elsif ($spec =~ /^([$MATCH_ID_CHAR\.\*]+)(=|!=)(.*)$/i) {
		return $SPEC_T_KEY;
	}

	return $SPEC_T_UNKNOWN;
}

#
# match_wildcard(value, wildcard)
#
# Return non-zero if VALUE matches shell wildcard pattern WILDCARD.
#
sub match_wildcard($$)
{
	my ($value, $wildcard) = @_;

	# Convert wildcard pattern to perl regular expression
	$wildcard =~ s/([^A-za-z0-9_])/\\$1/g;
	$wildcard =~ s/\\\?/\.\?/g;
	$wildcard =~ s/\\\*/\.\*/g;

	return ($value =~ /^$wildcard$/);
}

#
# filter_ids_by_wildcard(wildcard, type, ids)
#
# Return list of IDs which match WILDCARD.
#
sub filter_ids_by_wildcard($$@)
{
	my ($wildcard, $type, @ids) = @_;
	my $regexp = $wildcard;
	my @result;
	my $id;

	# Shortcut for "match all" wildcard
	if ($wildcard eq "*") {
		return @ids;
	}

	# Convert wildcard to regexp
	$regexp =~ s/\?/\.\?/g;
	$regexp =~ s/\*/\.\*/g;

	# Get matches
	foreach $id (@ids) {
		if ($id =~ /^$regexp$/) {
			push(@result, $id);
			info1(ucfirst($type)." $id matches '$wildcard'\n");
		}
	}

	return @result;
}

#
# copy_files(source, target, @files)
#
# Copy check FILES to from SOURCE to TARGET. Create sub-directories if
# necessary.
#
sub copy_files($$@)
{
	my ($source, $target, @files) = @_;
	my $file;

	foreach $file (@files) {
		my $full_source = catfile($source, $file);
		my $full_target = catfile($target, $file);
		my $dir = dirname($full_target);
		my $umask;

		if (!-d $dir) {
			create_path($dir, $DB_INSTALL_PERM_DIR);
		}
		if (-x $full_source) {
			$umask = $DB_INSTALL_PERM_EXEC;
		} else {
			$umask = $DB_INSTALL_PERM_NON_EXEC;
		}
		copy_file($full_source, $full_target, $umask);
	}
}

#
# system_to_str(system)
#
# Return string representation of the provided database installation status
# SYSTEM.
#
sub system_to_str($)
{
	my ($system) = @_;

	if (!defined($system)) {
		return "not installed";
	} elsif ($system) {
		return "system-wide database";
	} else {
		return "user database";
	}
}

#
# sec_to_duration(duration)
#
# Return a string representation of DURATION.
#
sub sec_to_duration($)
{
	my ($duration) = @_;
	my ($days, $hours, $mins, $secs);
	my $SEC_PER_MIN = 60;
	my $SEC_PER_HOUR = 60 * $SEC_PER_MIN;
	my $SEC_PER_DAY = 24 * $SEC_PER_HOUR;
	my $result = "";

	$days		= int($duration / $SEC_PER_DAY);
	$duration	= $duration - $days * $SEC_PER_DAY;
	$hours		= int($duration / $SEC_PER_HOUR);
	$duration	= $duration - $hours * $SEC_PER_HOUR;
	$mins		= int($duration / $SEC_PER_MIN);
	$duration	= $duration - $mins * $SEC_PER_MIN;
	$secs		= $duration;

	$result .= $days."d " if ($days > 0);
	$result .= $hours."h " if ($hours > 0);
	$result .= $mins."m " if ($mins > 0);
	if ($secs > 0 || $result eq "") {
		if ($secs == int($secs)) {
			$result .= $secs."s";
		} else {
			$result .= sprintf("%.3fs", $secs);
		}
	}

	return $result;
}

#
# normalize_duration(duration)
#
# Return a normalized version of DURATION.
#
sub normalize_duration($)
{
	my ($duration) = @_;
	my $seconds = duration_to_sec($duration);

	return $duration if (!defined($seconds));
	return sec_to_duration($seconds);
}

#
# quiet_store(ref, filename)
#
# Use store() to write data for REF to file FILENAME. Catch any error that
# may occur and return non-zero on success, 0 otherwise.
#
sub quiet_store($$)
{
	my ($ref, $filename) = @_;

	eval {
		local $SIG{__DIE__};
		lock_store($ref, $filename);
	};
	if ($@) {
		debug($@);
		return 0;
	}

	return 1;
}

#
# quiet_retrieve(filename)
#
# Use retrieve() to read data from FILENAME. Catch any error that
# may occur and return data on success, undef otherwise.
#
sub quiet_retrieve($)
{
	my ($filename) = @_;
	my $result;

	eval {
		local $SIG{__DIE__};
		$result = lock_retrieve($filename);
	};
	if ($@) {
		debug($@);
		return undef;
	}

	return $result;
}

#
# get_db_scope([system])
#
# Return text string describing the scope of SYSTEM or OPT_SYSTEM.
#
sub get_db_scope(;$)
{
	my ($system) = @_;

	$system = $opt_system if (!defined($system));
	if ($system) {
		return "system-wide";
	} else {
		return "user";
	}
}

#
# check_opt_system(obj_system, obj_id[, action])
#
# Check if OBJ_SYSTEM matches opt_system. If not, abort with an error.
# OBJ_ID identifies the object. ACTION specifies the action.
#
sub check_opt_system($$;$)
{
	my ($obj_system, $obj_id, $action) = @_;

	$action = "modify" if (!defined($action));
	if ($opt_system && !$obj_system) {
		die("Cannot $action user $obj_id with --system!\n");
	}
	if (!$opt_system && $obj_system) {
		die("Cannot $action system-wide $obj_id without --system!\n");
	}
}

#
# output_filename(filename)
#
# Return a textual representation of the output filename FILENAME.
#
sub output_filename($)
{
	my ($filename) = @_;

	if ($filename eq "-") {
		return "standard output";
	} else {
		return "file '$filename'";
	}
}

#
# rm_rf(directory)
#
# Recursively remove all files and directories found in DIRECTORY.
#
sub rm_rf($)
{
	my ($directory) = @_;
	my @dirs = ( $directory );

	do {
		my $index = $#dirs;
		my $curr_dir =$dirs[$index];
		my $handle;

		opendir($handle, $curr_dir) or
			die("Could not read directory '$curr_dir': $!\n");
		while (my $entry = readdir($handle)) {
			next if ($entry eq "." || $entry eq "..");

			$entry = catfile($curr_dir, $entry);
			if (-d $entry && ! -l $entry) {
				# Put on list
				push(@dirs, $entry);
			} else {
				# Remove now
				unlink($entry) or
					die("Could not remove file '$entry': ".
					    "$!\n");
			}
		}
		close($handle);


		# Check if there are new entries to be removed first
		if ($index == $#dirs) {
			rmdir($curr_dir) or
				die("Could not remove directory '$curr_dir': ".
				    "$!\n");
			delete($dirs[$index]);
		}
	} while (@dirs);
}

#
# cons_type_to_str(type)
#
# Return string representation of the specified consumer TYPE.
#
sub cons_type_to_str($)
{
	my ($type) = @_;

	if ($type == $CONS_TYPE_T_REPORT) {
		return "report";
	} elsif ($type == $CONS_TYPE_T_HANDLER) {
		return "handler";
	}

	return "<unknown type>";
}

#
# term_use_color()
#
# Return if ANSI color codes should be used.
#
sub term_use_color()
{
	my $result;

	# Return cached value if available
	return $_use_color if (defined($_use_color));

	goto auto if (!defined($opt_color));
	if ($opt_color eq "always") {
		$result = 1;
		goto out;
	} elsif ($opt_color eq "never") {
		$result = 0;
		goto out;
	}

auto:
	if (! -t STDOUT) {
		# Don't use color if output is not a terminal
		$result = 0;
	} else {
		# Consult terminfo database
		my ($err, $exit_code, $output ) =
			run_cmd("tput colors", undef, 1);

		if (defined($err) || $exit_code != 0 ||
		    $output !~ /^\s*\d+\s*$/ || int($output) < 8) {
			$result = 0;
		} else {
			$result = 1;
		}
	}

out:
	$_use_color = $result;

	return $result;
}

#
# get_colors()
#
# Return control codes for color coding/bold text if available. Returns
# codes for (red, green, blue, bold, reset) or empty strings if no
# color coding is available.
#
sub get_colors()
{
	my ($red, $green, $blue, $bold, $reset);

	if (term_use_color()) {
		$red	= color("red");
		$green	= color("green");
		$blue	= color("blue");
		$bold	= color("bold");
		$reset	= color("reset");
	} else {
		($red, $green, $blue, $bold, $reset) = ("", "", "", "", "");
	}

	return ($red, $green, $blue, $bold, $reset);
}


#
# Code entry
#

# Indicate successful module initialization
1;
