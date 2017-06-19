#
# LNXHC::Locale.pm
#   Linux Health Checker support functions for language support
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

package LNXHC::Locale;

use strict;
use warnings;

use Exporter qw(import);
use File::Spec::Functions qw(catfile);


#
# Local imports
#


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&locale_matches &localify);


#
# Constants
#


#
# Global variables
#

my $_locale;
our @_locale_versions;


#
# Sub-routines
#

sub _expand_locale($)
{
	my ($locale) = @_;
	my @result;

	while ($locale ne "") {
		push(@result, $locale);
		last if (!($locale =~ s/[_.@][a-z0-9]+$//i));
	}
	return @result;
}

#
# _init_locale()
#
# Initialize lnxhc localization.
#
sub _init_locale()
{
	if (defined($ENV{"LC_MESSAGES"})) {
		$_locale = $ENV{"LC_MESSAGES"};
	}
	$_locale = "" if (!defined($_locale));
	@_locale_versions = _expand_locale($_locale);
}

#
# localify(directory, file)
#
# Convert DIRECTORY+FILE to a directory according to the current locale
#
sub localify($$)
{
	my ($directory, $file) = @_;
	my $l;

	# Lazy locale initialization
	_init_locale() if (!defined($_locale));

	foreach $l (@_locale_versions) {
		my $path = catfile($directory, $l, $file);

		return $path if (-f $path);
	}

	return catfile($directory, $file);
}

#
# locale_matches(locale)
#
# Return non-zero if LOCALE matches current locale for health checker
# messages.
#
sub locale_matches($)
{
	my ($locale) = @_;
	my $current_locale = $ENV{"LC_MESSAGES"};

	return 1 if (!defined($locale) && !defined($current_locale));
	return 0 if (!defined($locale) || !defined($current_locale));

	return $locale eq $current_locale;
}


#
# Code entry
#

# Indicate successful module initialization
1;
