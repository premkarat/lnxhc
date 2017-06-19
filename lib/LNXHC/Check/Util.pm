#
# LNXHC::Check::Util
#   Linux Health Checker utility functions for health checks
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
package LNXHC::Check::Util;

=head1 NAME

LNXHC::Check::Util - Utility functions for Linux health checks

=head1 DESCRIPTION

The B<LNXHC::Check::Util> module helps health check authors to reuse
common functions to easily develop new check programs.

=head1 FUNCTIONS

=over 8

=cut

use strict;
use warnings;
use Carp qw/carp/;
use Exporter qw/import/;

our $VERSION = "1.0.0";
our @EXPORT;
our @EXPORT_OK = qw(load_proc_sysinfo load_proc_cpuinfo load_sysctl
		    load_chkconfig);
our %EXPORT_TAGS = (
	proc	 => [qw(load_proc_sysinfo load_proc_cpuinfo)],
);


# prototypes
sub load_proc_sysinfo($);
sub load_proc_cpuinfo($);
sub _parse_colon_data($;$);


=item B<load_proc_sysinfo($)>

Parses F</proc/sysinfo> and returns a hash reference which contains
the information.  You must specify the file path to a file that
contains the /proc/sysinfo output.

=cut
sub load_proc_sysinfo($)
{
	my $sysinfo_file = shift;
	my $fd = undef;

	return undef unless open($fd, "<", $sysinfo_file);
	my $href = _parse_colon_data($fd);
	close($fd);

	return $href;
}

=item B<load_proc_cpuinfo($)>

Parses F</proc/cpuinfo> and returns a hash reference which contains
the information.  You must specify the file path to a file that
contains the /proc/sysinfo output.

=cut
sub load_proc_cpuinfo($)
{
	my $cpuinfo_file = shift;
	my $fd = undef;

	return undef unless open($fd, "<", $cpuinfo_file);
	my $href = _parse_colon_data($fd);
	close($fd);

	return $href;
}

sub _parse_colon_data($;$)
{
	my $fd = shift;
	my $href = (@_) ? shift : {};	# lazy initialization

	while (<$fd>) {
		# skip lines which do not specify a colon-separated key/value
		next unless /^([^:]+):(.+)$/;
		my ($key, $val) = ($1, $2);
		$key =~ s/^\s+|\s+$//g;     # trim
		$val =~ s/^\s+|\s+$//g;     # trim
		if (exists $href->{$key}) {
			carp "Replacing hash key: $key\n";
		}
		$href->{$key} = $val;
	}
	return $href;
}


=item B<load_sysctl($)>

Parses the output of "sysctl -a" returns a hash reference containing
the key/values pairs of system controls.
You must specify the file path to a file that contains the sysctl output.

=cut
sub load_sysctl($)
{
	my $sysctl_file = shift;
	my $href = {};
	my $fd = undef;

	return undef unless open($fd, "<", $sysctl_file);
	while (<$fd>) {
		next unless /^(\S+)\s*=\s*(.+)\s*$/;
		$href->{$1} = $2;
	}
	close($fd);

	return $href;
}

=item B<load_chkconfig>(I<filename>)

Parses the output of "chkconfig --list" and stores the information
whether a system or xinetd service is enabled (in any runlevel).

The function returns a list reference pointing to a list with two
hash references.  The first hash contains init services using
the service name as hash key.  The second hash contains xinetd
services also using the service name as hash key.  Active services
have a non-zero hash value.

The input format which the function expects is as follows:

  dumpconf                  0:off  1:on   2:on   3:on   4:on   5:on   6:off
  xinetd based services:
          echo:               off

=cut
sub load_chkconfig($)
{
	my $chkconfig = shift;
	my $srv = {};
	my $xinetd = {};
	my $fd = undef;

	return undef unless open ($fd, "<", $chkconfig);
	my $in_xinetd = 0;
	while (<$fd>) {
		if ($in_xinetd && /^\s+(.+):\s+(on|off)$/) {
			my ($key, $val) = ($1, $2);
			$key =~ s/^\s+|\s+$//g;
			$val =~ s/^\s+|\s+$//g;
			$xinetd->{$key} = $val eq "on" ? 1 : 0;
		} else {
			if (/^xinetd based/) {
				$in_xinetd = 1;
				next;
			}
			if (/^(\S+)\s+(.+)$/) {
				my $key = $1;
				my $settings = $2;
				if ($settings =~ /\w:on/) {
					$srv->{$key} = 1;
				} else {
					$srv->{$key} = 0;
				}
			}
		}
	}
	close ($fd);
	return [$srv, $xinetd];
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
