#!/bin/bash
#
# Usage: fixpath.sh <filename> <lib_path> <db_path1> <db_path2> ...
#
# Apply fixed values for the Linux Health Checker library and database paths
# to the file specified by FILENAME. This helper script is used by the
# Makefile install target.
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

# Get parameters
FILE="$1"
shift
LIB_PATH="$1"
shift
DB_PATHS=($*)

# Define replacement strings
DB_PATH_LIST=""
for PATH in "${DB_PATHS[@]}" ; do
	DB_PATH_LIST="${DB_PATH_LIST}			\"$PATH\",\\
"
done
REP_BIN_PATHS="
		\$lib_dir = \"${LIB_PATH}\";\\
		@default_db_dirs = (\\
${DB_PATH_LIST}		);\
"

REP_RC_PATHS=""
for PATH in "${DB_PATHS[@]}" ; do
	REP_RC_PATHS="${REP_RC_PATHS}db_path = \"${PATH}\"\\
"
done

# Apply replacement
${SED} '/__REP_START_BIN_PATHS/,/__REP_END_BIN_PATHS/c\'"${REP_BIN_PATHS}" -i ${FILE}
${SED} '/__REP_START_RC_PATHS/,/__REP_END_RC_PATHS/c\'"${REP_RC_PATHS}" -i ${FILE}
