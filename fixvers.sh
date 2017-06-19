#!/bin/bash
#
# Usage: fixvers.sh <version> <release> <directory>
#
# Apply fixed values for the Linux Health Checker version and last modified
# strings
#
# Copyright IBM Corp. 2012
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors: See file CONTRIBUTORS which is part of this package
#

SED="/bin/sed"
DATE="/bin/date"

VERSION=$1
RELEASE=$2
DIR=$3

if [ -z "${VERSION}" -o -z "${RELEASE}" -o -z "${DIR}" ] ; then
	echo "Usage: $0 <version> <release> <directory>" >&2
	exit 1
fi

${SED} 's/linux\s\+health\s\+checker\s\+version[^"]\+/Linux Health Checker version '"${VERSION}"'-'"${RELEASE}"'/i' -i "${DIR}/bin/lnxhc"

for MAN in ${DIR}/man/*.[0-9] ; do
	TTIME=$(${DATE} -r "${MAN}" +%Y%m%d%H%M.%S)
	MTIME=$(${DATE} -r "${MAN}" +%Y-%m-%d)
	${SED} 's/lnxhc [0-9]\+\.[0-9a-z\.-]\+/lnxhc '"${VERSION}"'-'"${RELEASE}"'/g' -i ${MAN}
	${SED} 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/'"${MTIME}"'/g' -i ${MAN}
	touch ${MAN} -t ${TTIME}
done

${SED} -e 's/Version:.*$/Version: '"${VERSION}"'/g' \
       -e 's/Release:.*$/Release: '"${RELEASE}"'/g' -i ${DIR}/lnxhc.spec
