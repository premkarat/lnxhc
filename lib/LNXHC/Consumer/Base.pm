#
# LNXHC::Consumer::Base
#   Base functions for Linux health check result consumers

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
package LNXHC::Consumer::Base;

=head1 NAME

LNXHC::Consumer::Base - Base functions for health check result consumers

=head1 DESCRIPTION

The B<LNXHC::Consumer::Base> module provides base functions to help
health check result consumer authors to easily create new consumer programs.

=cut

use strict;
use warnings;
use Exporter qw/import/;
use LNXHC::Util qw/:consumer/;

our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

$VERSION = "1.0.0";
@EXPORT = qw();
@EXPORT_OK = qw();
%EXPORT_TAGS = ();
# re-export consumer functions from LNXHC::Util
push @EXPORT_OK, @{$LNXHC::Util::EXPORT_TAGS{consumer}};



# Indicate successful module initialization
1;

=head1 SEE ALSO

=cut
__DATA__
__END__
