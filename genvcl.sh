#!/bin/sh
#
# Generate version and change log from the Linux Health Checker git repository
#
#
# Copyright IBM Corp. 2012
# Author(s): Hendrik Brueckner <brueckner@linux.vnet.ibm.com>
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors: See file CONTRIBUTORS which is part of this package
#

# ---- Variables and constants --------------------------------------------
#
# Version information file for distribution archives
readonly VERSION_FILE=.lnxhc.version
# Change log file for distribution and package archives
readonly CHANGELOG_FILE=CHANGES
# RPM specfile name
readonly RPM_SPECFILE=lnxhc.spec
# Base version from which to create the change log
readonly BASE_VERSION='v1.0'
# Base release number for every new version
readonly BASE_RELEASE_NUM=1

# Destination (build) directory
opt_dir=""

# ---- Functions ----------------------------------------------------------
pr_usage()
{
cat <<EoHelp
Usage:
	$0 [OPTIONS]

Options:
  -d	      Specifies the destination (build) directory.
  -c	      Creates a changes file.
  -p	      Creates a RPM change log.
  -s	      Creates a lnxhc version file.
  -r	      Displays release information.
  -v	      Displays version information.
  -h	      Displays help information and exits.
EoHelp
}

pr_err_exit()
{
	local msg="$1"
	local rc="${2:-1}"

	echo "$1" >&2
	exit $rc
}

do_display_version()
{
	if test -d .git; then
		git describe |cut -d- -f1 |sed -e 's/^v\([0-9.]*\)/\1/'
	else
		test -r $VERSION_FILE || \
			pr_err_exit "Could not read version file: $VERSION_FILE"
		local version release
		IFS='|' read version release < $VERSION_FILE
		echo $version
	fi
}

do_display_release()
{
	if test -d .git; then
		# If the branch head is referenced by an annotated (release) tag,

		# always return "1" indicating the first release.  Otherwise, use
		# the number of commits and the abbreviated head commit as release
		# information.
		if test -z "`git describe --exact-match 2>/dev/null`"; then
			git describe |cut -d- -f2,3 |sed -e 's/-/./g'
		else
			echo $BASE_RELEASE_NUM
		fi
	else
		test -r $VERSION_FILE || \
			pr_err_exit "Could not read version file: $VERSION_FILE"
		local version release
		IFS='|' read version release < $VERSION_FILE
		echo $release
	fi
}

do_create_version_file()
{
	local destdir="$1"

	test -d .git || pr_err_exit "Could not access lnxhc git repository"
	test -d "$destdir" || pr_err_exit "You must specify a directory"

	# save information to display version w/o git
	version_string="`$0 -v`|`$0 -r`"
	echo "$version_string" > $destdir/$VERSION_FILE
}

do_create_changes_file()
{
	local destdir="$1"
	local tip=`git rev-parse HEAD`

	test -d .git || pr_err_exit "Could not access lnxhc git repository"
	test -d "$destdir" || pr_err_exit "You must specify a directory"

	git log --pretty=medium $BASE_VERSION..$tip >> $destdir/$CHANGELOG_FILE
}

parse_git_tag()
{
	local tagger="`git cat-file -p $1 |grep tagger`"
	local _date _rest

	# On old git versions (prior 1.8):
	# tagger Hendrik Brueckner <brueckner@linux.vnet.ibm.com> Tue Mar 20 14:18:00 2012 +0100
	# On current git versions
	# tagger Hendrik Brueckner <brueckner@linux.vnet.ibm.com> 1360335011 +0100
	echo $tagger |sed -e 's/^tagger[[:blank:]]*//'			  \
			  -e 's/>[[:blank:]]*/>|/'			  \
			  -e 's/[[:blank:]]*[[:digit:]]*:[[:digit:]]*:[[:digit:]]*//' \
			  -e 's/[[:blank:]]*+[[:digit:]]*$//'		  \
		     |sed -e 's/^\([^|]*\)|\(.*\)$/\2 \1/'		  \
		     |while read _date _rest; do
			if expr "$_date" : '^[[:digit:]]*$' >/dev/null; then
				echo $(date -d "@$_date" +"%a %b %d %Y") $_rest
			else
				echo $_date $_rest
			fi
		      done
}

do_create_rpm_changelog()
{
	local destdir="$1"
	local specfile="$destdir/$RPM_SPECFILE"

	# Check pre-reqs
	test -d .git || pr_err_exit "Could not access lnxhc git repository"
	test -d "$destdir" || pr_err_exit "You must specify a directory"
	test -w "$specfile" || pr_err_exit "RPM specfile not writable"

	# Create temporary file to save changelog
	local tmpfile=`mktemp /tmp/lnxhc-rpm_cllog.XXXXXX || echo ""`
	test -w "$tmpfile" || pr_err_exit "Failed to create temporary file"

	# Traverse through the commits and create the change log starting
	# with the first commit (reverse order) and reverse the final output
	# and temporarily save it.
	(
	local tip=`git rev-parse HEAD`
	local rev
	for rev in `git rev-list --reverse $tip`; do
		# Create changelog line: "- " subj " (" name ")" meta;
		git log -1 --format="- %s (%an) [%h]" $rev

		# Test if a revision points to a release tag and print release
		# line using format:
		#   * Thu Mar 15 2012 Hendrik Brueckner <brueckner@linux.vnet.ibm.com> - 1.0-1
		local rtag=`git describe --exact-match $rev 2>/dev/null`
		if test -n "$rtag"; then
			local tagger="`parse_git_tag $rtag`"
			local version="${rtag#v}-$BASE_RELEASE_NUM"
			printf "* $tagger - $version\n\n"
		fi
	done

	# Check if the last commit refers to a release tag.  If not, create a
	# temporary release for entry for it.  The temporary release line
	# looks like:
	#   * Thu Nov 08 2012 Hendrik Brueckner <brueckner@linux.vnet.ibm.com> [v1.0-130-gf3f3a07]
	if test -z `git describe --exact-match $rev 2>/dev/null`; then
		local aname="`git config user.name`"
		local aemail="`git config user.email`"
		local tempver=`git describe $rev`
		echo "* $(date "+%a %b %d %Y") $aname <$aemail> [$tempver]"
	fi
	) |tac > $tmpfile

	# Append the change log to the %changelog section in the RPM specfile
	printf "/^%%changelog/r $tmpfile\nwq\n" |ed -s $specfile

	rm $tmpfile
}

# ---- Main script --------------------------------------------------------

# Parse command line parameters and set action
action=""
while getopts ":cd:hprsv" arg; do
        case $arg in
	d)	opt_dir=$OPTARG ;;
	c)	action=create_changes ;;
	p)	action=create_rpm_changelog  ;;
        h) 	action=help ;;
	s) 	action=create_version ;;
	r)	action=display_release ;;
	v)	action=display_version ;;
        \?)
		echo "Invalid option specified" >&2
		pr_usage
		exit 1
		;;
        esac
done

case $action in
create_changes)
	do_create_changes_file "$opt_dir"
	;;
create_rpm_changelog)
	do_create_rpm_changelog "$opt_dir"
	;;
create_version)
	do_create_version_file "$opt_dir"
	;;
display_release)
	do_display_release
	;;
display_version)
	do_display_version
	;;
help)
	pr_usage
	;;
esac
exit 0
