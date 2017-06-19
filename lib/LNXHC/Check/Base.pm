#
# LNXHC::Check::Base
#   Base functions for a Linux health check
#
# Copyright IBM Corp. 2012
#
# Author(s): Hendrik Brueckner <brueckner@linux.vnet.ibm.com>
#	     Peter Oberparleiter <peter.oberparleiter@de.ibm.com>
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors: See file CONTRIBUTORS which is part of this package
#
package LNXHC::Check::Base;

=head1 NAME

LNXHC::Check::Base - Base functions for Linux health checks

=head1 DESCRIPTION

The B<LNXHC::Check::Base> module provides base functions to help
health check authors to easily create new check programs.

=cut

use strict;
use warnings;
use Exporter qw/import/;

our $VERSION = "1.0.0";
our @EXPORT = qw(lnxhc_exception lnxhc_exception_var lnxhc_exception_var_list
		 lnxhc_fail_dep lnxhc_param_error
		 check_empty_param check_int_param check_dir_list_param
		 parse_list_param
		 $LNXHC_VERBOSE $LNXHC_DEBUG
		 $LNXHC_CHECK_ID $LNXHC_CHECK_DIR $LNXHC_EXCEPTION);
our @EXPORT_OK = qw();
our %EXPORT_TAGS = (
);

our ($LNXHC_VERBOSE, $LNXHC_DEBUG);
our ($LNXHC_CHECK_ID, $LNXHC_CHECK_DIR, $LNXHC_EXCEPTION);

=head1 PACKAGE VARIABLES

The following variables can be imported by check programs either
explicitly or using the C<:vars> import tag.

=over 8

=item LNXHC_VERBOSE

Non-zero if the check program should output additional messages.

=item LNXHC_DEBUG

Non-zero if health check program should output debugging messages.

=item LNXHC_CHECK_ID

The health check identifier for this check program.

=item LNXHC_CHECK_DIR

The health check installation directory.  You can use this variable
to access check-specific resources.

=item LNXHC_EXCEPTION

File path to the file used to report exceptions:

=back

=cut

$LNXHC_VERBOSE = $ENV{"LNXHC_VERBOSE"};
$LNXHC_DEBUG = $ENV{"LNXHC_DEBUG"};
$LNXHC_CHECK_ID = $ENV{"LNXHC_CHECK_ID"};
$LNXHC_CHECK_DIR = $ENV{"LNXHC_CHECK_DIR"};
$LNXHC_EXCEPTION = $ENV{"LNXHC_EXCEPTION"};

=head1 FUNCTIONS

=over 8

=cut

# prototypes
sub lnxhc_exception($);
sub lnxhc_exception_var($$);
sub lnxhc_fail_dep($);

=item B<lnxhc_exception>($)

Reports an exception.  Specify the exception ID as argument.

=cut
sub lnxhc_exception($)
{
	my ($ex_id) = @_;
	my $fh = undef;

	open($fh, ">>", $LNXHC_EXCEPTION) or
		die("Failed to append to exception file " .
		    "'$LNXHC_EXCEPTION': $!\n");
	print($fh "$ex_id\n");
	close($fh);
}

=item B<lnxhc_exception_var>($$)

Reports the value of an exception template variable.
The first argument specifies the variable name and the second argument
specifies the value.

If you call this function multiple times for the same variable name,
the value is appended by the framework.

=cut
sub lnxhc_exception_var($$)
{
	my ($var_id, $value) = @_;
	my $fh = undef;

	open($fh, ">>", $LNXHC_EXCEPTION) or
		die("Failed to append to exception file " .
		    "'$LNXHC_EXCEPTION': $!\n");
	print($fh "$var_id=\"$value\"\n");
	close($fh);
}

=item B<lnxhc_exception_var_list>($$$;$)

Formats a Perl list and reports the result as value of an
exception template variable.
The first argument specifies the variable name and the second
argument specifies the list reference.
The third argument specifies the output delimiter.
The optional fourth argument specifies the maximum number elements
to be reported.  If omitted, four elements are displayed.

=cut
sub lnxhc_exception_var_list($$$;$)
{
	my ($var_id, $lref, $delim, $num) = @_;
	$num = 4 unless defined($num);

	lnxhc_exception_var($var_id,
		join $delim, scalar(@$lref) > $num
				? (@{$lref}[0..$num-1], "...")
				: @$lref);

}

=item B<lnxhc_fail_dep>(I<message>)

Ends the check program with the specified I<message> and
returns an exit code that indicates a failed dependency.

=cut
sub lnxhc_fail_dep($)
{
	print STDERR shift() . "\n";
	exit(64);
}

=item B<lnxhc_param_error>(I<message>)

Ends the check program with the specified I<message> and
returns an exit code that indicates an invalid parameter
value.

=cut
sub lnxhc_param_error($)
{
	print STDERR shift() . "\n";
	exit(65);
}

=item B<check_empty_param>($)

Check if the specified parameter contains a non-empty value.
If the parameter is empty, exit with an error message.

=cut

sub check_empty_param($)
{
	my $param_id = shift();
	my $value = $ENV{"LNXHC_PARAM_$param_id"};

	if (!defined($value) || $value =~ /^\s*$/) {
		lnxhc_param_error("Parameter is empty: $param_id");
	}
}

=item B<check_int_param>($;$$)

Check if a parameter is an integer number. Optional arguments specify the
acceptable lower and upper boundaries for the number.

=cut
sub check_int_param($;$$)
{
	my ($param_id, $lower, $upper) = @_;
	my $value = $ENV{"LNXHC_PARAM_$param_id"};

	check_empty_param($param_id);

	if ($value !~ /^[-+]?\d+$/) {
		lnxhc_param_error("Parameter value is not an integer: ".
				  "$param_id='$value'");
	}
	$value = int($value);
	if (defined($lower) && $value < $lower) {
		lnxhc_param_error("Parameter value is too low " .
				  "(minimum $lower): $param_id='$value'");
	}
	if (defined($upper) && $value > $upper) {
		lnxhc_param_error("Parameter value is too high " .
				  "(maximum $upper): $param_id='$value'");
	}
}

=item B<check_dir_list_param>($)

Check if the value of the given parameter specifies absolute directory
paths.

=cut
sub check_dir_list_param($)
{
	my $param_id = shift();

	check_empty_param($param_id);

	my @dirs = split /\s+/, $ENV{"LNXHC_PARAM_$param_id"};
	my @invalid_dirs = grep { !m#^/# } @dirs;
	if (@invalid_dirs) {
		lnxhc_param_error("Parameter $param_id contains " .
				  "relative paths: @invalid_dirs");
	}
}

=item B<parse_list_param>(I<param>;I<delim>,I<trim>)

Parses the specified list parameter and returns a hash that contains
unique elements.  Each hash key evaluates to true in a boolean context.
If the delimiter character is omitted, colon (:) is used.  Optionally,
if last argument (I<trim>) is true, leading and trailing whitespaces are
removed for each element.

=cut
sub parse_list_param($;$$)
{
	my $param_id = shift();
	my $delim = @_ ? shift() : ':';
	my $trim = @_ ? shift() : 0;
	my $result = {};

	foreach (split($delim, $ENV{"LNXHC_PARAM_$param_id"})) {
		s/^\s+|\s+$//g if $trim;
		$result->{$_} = 1 unless /^\s*$/;
	}

	return $result;
}

# Indicate successful module initialization
1;

=back

=head1 SEE ALSO

L<lnxhc_check_program(7)>,
L<lnxhc_writing_checks(7)>

=cut
__DATA__
__END__
