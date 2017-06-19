Summary: Linux Health Checker framework and base health checks
Name: lnxhc
Version: 1.3
Release: 1
License: Eclipse Public License
Group: Applications/System
URL: http://lnxhc.sourceforge.net/
Source0: http://downloads.sourceforge.net/lnxhc/lnxhc-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-root
BuildRequires: perl-XML-Parser
BuildArch: noarch

Requires: /bin/bash
Requires: /bin/sh
Requires: /usr/bin/perl
%if 0%{?with-python}
Requires: /usr/bin/python
%endif
Requires: perl(Carp)
Requires: perl(Cwd)
Requires: perl(Data::Dumper)
Requires: perl(Digest::MD5)
Requires: perl(Exporter)
Requires: perl(File::Basename)
Requires: perl(File::Spec::Functions)
Requires: perl(File::Temp)
Requires: perl(File::stat)
Requires: perl(FindBin)
Requires: perl(Getopt::Long)
Requires: perl(MIME::Base64)
Requires: perl(Pod::Usage)
Requires: perl(Storable)
Requires: perl(Sys::Hostname)
Requires: perl(Time::HiRes)
Requires: perl(XML::Parser)
Requires: perl(Term::ANSIColor)

%description
The Linux Health Checker checks system settings and examines system status
information. It identifies potential problems before they impact system
availability or cause outages.

%prep
%setup -q -n lnxhc-%{version}

%build
make

%install
rm -rf "${RPM_BUILD_ROOT}"
make install DESTDIR="${RPM_BUILD_ROOT}" \
	     DOCDIR="%{_defaultdocdir}/%{name}-%{version}/"

%clean
rm -rf "${RPM_BUILD_ROOT}"

%files
%defattr(-,root,root)
%config(noreplace) /etc/lnxhcrc
%{_defaultdocdir}/%{name}-%{version}/*
%dir /usr/local/lib/lnxhc/
/usr/bin/*
/usr/lib/lnxhc/*
%{_mandir}/man1/*
%{_mandir}/man5/*
%{_mandir}/man7/*

%changelog

* Wed Dec 18 2013 Hendrik Brueckner <brueckner@linux.vnet.ibm.com> - 1.3-1
- lnxhc: Update CONTRIBUTORS file (Peter Oberparleiter) [f8177b4]
- checks: Make common helper script consistent (Peter Oberparleiter) [9d6ba8b]
- checks: Remove unused variables (Peter Oberparleiter) [413ed10]
- checks: Remove unnecessary imports (Peter Oberparleiter) [a00888c]
- checks: Ensure consistent copyright statements (Peter Oberparleiter) [123e9d0]
- checks: Remove spaces at end of line (Peter Oberparleiter) [4d12b3c]
- checks: Fix check components (Peter Oberparleiter) [93bd843]
- checks: Fix spelling (Peter Oberparleiter) [2776f8e]
- lnxhc: Fix misspellings using 'codespell' tool (Hendrik Brueckner) [ab82213]
- lnxhc: Fix locale handling (Peter Oberparleiter) [a602fb9]
- zfcp_lun_configured_available: Check configured LUNs for availability (Manik Bajpai) [0663746]
- tty_devnodes, tty_usage: load data in a restricted compartment (Hendrik Brueckner) [b43d4a2]
- lnxhc: prevent data corruption in case of concurrent runs (Peter Oberparleiter) [eb126a5]
- lnxhc: updated CONTRIBUTORS file (Peter Oberparleiter) [cb6b397]
- lnxhc: add info message when changing active report consumer (Peter Oberparleiter) [b84874b]
- lnxhc: rename report consumers (Peter Oberparleiter) [73b5852]
- lnxhc: implement lnxhc sysinfo --show-data (Peter Oberparleiter) [5470203]
- lnxhc: implement 'lnxhc run --add-data' (Peter Oberparleiter) [a54e54e]
- lnxhc: implement 'lnxhc cons --report' (Peter Oberparleiter) [f854d2e]
- lnxhc: implement 'lnxhc run --report' (Peter Oberparleiter) [51e3fa7]
- lnxhc: implement option --no-sudo (Peter Oberparleiter) [1389bea]
- lnxhc: implement lnxhc check --show-sudoers (Peter Oberparleiter) [3920557]
- zfcp_target_port_recovery_failed: Check for failed target port recovery (Manik Bajpai) [5c903e6]
- zfcp_hba_shared_chpids: Identify FCP devices that share CHPIDs (Manik Bajpai) [02e5fc7]
- zfcp_hba_recovery_failed: Check if FCP device recovery failed (Manik Bajpai) [8145dc8]
- storage_mp_zfcp_redundancy: Check for redundant zfcp paths (Manik Bajpai) [bda46f4]
- lnxhc: Add support for Fedora distribution ID (Peter Oberparleiter) [b00f608]
- zfcp_hba_npiv_active: Check if NPIV is active for FCP devices (Nageswara R Sastry) [fbe97e0]
- storage_mp_service_active: Check for active multipath service (Nageswara R Sastry) [5b24922]
- genvcl.sh: adapt parsing of tag information due to git cat-file -p changes (Hendrik Brueckner) [f8f6a67]
- zfcp_lun_recovery_failed: Identify if recovery of a zFCP LUN failed (Nageswara R Sastry) [500e7f5]
- scsi_dev_state: Ensure correct state of SCSI device (Nageswara R Sastry) [33592d6]
- fc_remote_port_state: Identifies unusable Fibre Channel remote ports (Nageswara R Sastry) [d22e8b2]
- sec_users_uid_zero: do not display usernames added by other services (Nageswara R Sastry) [5c95903]
- net_dns_settings: incorrect formatting of ip address in exception message (Peter Oberparleiter) [d94869e]
- net_dns_settings: fix ip not showing in exception message (Peter Oberparleiter) [d1a5720]
- lnxhc: make columns check more robust (Peter Oberparleiter) [629ecc3]

* Fri Feb 8 2013 Hendrik Brueckner <brueckner@linux.vnet.ibm.com> - 1.2-1
- CONTRIBUTORS: update entry (Peter Oberparleiter) [e26eeb6]
- crypto_*: adjust default activation states (Peter Oberparleiter) [debfc1e]
- log_syslog_rotate: fix formatting in exception (Peter Oberparleiter) [efc3381]
- crypto_z_module_loaded: update texts based on review comments (Peter Oberparleiter) [7af4ebb]
- checks: more non-functional fallout from check renaming (Peter Oberparleiter) [091afbe]
- tty_hvc_iucv: add missing dependency on z/VM (Peter Oberparleiter) [0550dfa]
- crypto_*: enforce exception dependencies (Peter Oberparleiter) [857f762]
- crypto_z_module_loaded: implement check (Peter Oberparleiter) [4e70479]
- crypto_cpacf_usage: rename to crypto_cpacf (Peter Oberparleiter) [007147a]
- crypto_cpacf_usage: check for cpacf enablement (Peter Oberparleiter) [81e1d9a]
- crypto_*: update exceptions (Peter Oberparleiter) [f862462]
- crypto_*: remove double escapes in sysinfo items (Peter Oberparleiter) [02dfdc4]
- proc_load_avg: prevent misinterpretation of percentage (Peter Oberparleiter) [a46bfc3]
- lnxhc: fix unwanted removal of escape characters (Peter Oberparleiter) [7a2f7ef]
- lnxhc: improve detection of changes in lnxhc database (Peter Oberparleiter) [824cde5]
- zvm_priv_class: suppress redundant exception (Peter Oberparleiter) [fae0a42]
- tty_usage: precise glob to list terminal devices (Hendrik Brueckner) [92031a2]
- tty_usage: improve check (Peter Oberparleiter) [7dee6b6]
- proc_cpu_usage: restrict exceptions to long-running processes (Peter Oberparleiter) [30c8a52]
- net_qeth_buffercount: exclude HiperSockets devices (Peter Oberparleiter) [50c0c55]
- net_qeth_buffercount: adjust ruleset (Peter Oberparleiter) [90d96f2]
- net_qeth_buffercount: improve parameter description (Peter Oberparleiter) [684fb72]
- crypto_openssl_stack_32bit: corrected filename in exceptions (Nageswara R Sastry) [96276a1]
- crypto checks: minor spelling corrections (Nageswara R Sastry) [cdf058f]
- crypto checks: minor spelling corrections (Nageswara R Sastry) [768f943]
- Cryptography checks: changed exception name for correct ness (Nageswara R Sastry) [8475326]
- cryptography health checks: rpm name changes (Nageswara R Sastry) [db194da]
- Clear key checks: raise exception when both adapters are not available (Nageswara R Sastry) [7d2a490]
- crypto_opencryptoki_{ckc, skc, ckc_32bit, skc_32bit}: corrected rpm name (Nageswara R Sastry) [6b941fb]
- crypto_cca_stack: corrected severity of 'cpacf_not_available' (Nageswara R Sastry) [531bdfc]
- checks: fix fallout from check renaming (Peter Oberparleiter) [03303ae]
- lnxhc: use color coding for verbose output (Peter Oberparleiter) [10b00ff]
- lnxhc: fix verbose output when running sudo commands (Peter Oberparleiter) [9fca8b4]
- consumer: rename USE_COLOR to LNXHC_USE_COLOR (Peter Oberparleiter) [8b20bea]
- basic_report: add parameter full_hostname (Peter Oberparleiter) [64e2e50]
- basic_report: add color to output (Peter Oberparleiter) [4b330cf]
- lnxhc: prepare for consumers with color output (Peter Oberparleiter) [0f9c1f9]

* Fri Nov 9 2012 Hendrik Brueckner <brueckner@linux.vnet.ibm.com> - 1.1-1
- build/packaging: fix version replacement script (Peter Oberparleiter) [924d744]
- build/packaging: consolidate scripts and add genvcl.sh (Hendrik Brueckner) [d408bdf]
- lnxhc: remove whitespaces (Hendrik Brueckner) [ea4836c]
- build/packaging: add version and change log information (Hendrik Brueckner) [fd81649]
- ras_dump_kdump_on_panic: fix regexp (Peter Oberparleiter) [f3f3a07]
- README: add content to README file (Peter Oberparleiter) [926fbb2]
- checks: make dependency statements consistent (Peter Oberparleiter) [14a71a9]
- man: add naming guidelines (Peter Oberparleiter) [2121acc]
- man: Mention helper functions (Peter Oberparleiter) [f6e44c8]
- ras_dump_kdump_on_panic: fix warning (Peter Oberparleiter) [17c4ad2]
- crypto_openssl_stack_32bit: fix warning (Peter Oberparleiter) [9c8d019]
- CONTRIBUTORS: apply check renaming (Peter Oberparleiter) [85e640f]
- mem_swap_availability: tolerate swap entry (Peter Oberparleiter) [ec577ca]
- proc_{mem,cpu}_usage: make parsing consistent (Peter Oberparleiter) [2f4b1fc]
- crypto_*: adjust default activation states (Peter Oberparleiter) [b6bfc24]
- lnxhc: fix statement parsing (Peter Oberparleiter) [abedf5b]
- lnxhc: fix overzealous base64 encoding (Peter Oberparleiter) [49b57ad]
- checks: rename exceptions (Peter Oberparleiter) [2bc9c6e]
- checks: rename components (Peter Oberparleiter) [71b87b0]
- checks: rename checks (Peter Oberparleiter) [c96363e]
- build: correct variable use (Hendrik Brueckner) [873caef]
- build: install all documentation file and update rpm doc packaging (Hendrik Brueckner) [d161640]
- Makefile: ensure that lnxhc doc dir is removed by make uninstall (Peter Oberparleiter) [c03ae67]
- pythondemo: add a demo check for python LNXHC (Gowrishankar M) [9b95608]
- lnxhc: add framework to write checks in python (Gowrishankar M) [e1aa389]
- minimal_report: fix bug when only one check is run (Peter Oberparleiter) [2e6a1a8]
- minimal_report: add new minimal report consumer (Peter Oberparleiter) [5661246]
- basic_report: add copyright statement (Peter Oberparleiter) [66c5d5f]
- lnxhc: add missing section to consumer man page (Peter Oberparleiter) [cd32fa5]
- lnxhc: improve consumer handling (Peter Oberparleiter) [9fe8aa0]
- lnxhc: fix warning when first running lnxhc run (Peter Oberparleiter) [bd9d014]
- build, lib: Remove CVS/ and exclude .git/ (Hendrik Brueckner) [bf886d5]
- checks: Replace die() calls for parameter errors with lnxhc_parm_error() (Hendrik Brueckner) [c2fcc6a]
- LNXHC::Check::Base: Use lnxhc_param_error() in check parameter functions (Hendrik Brueckner) [25b8dca]
- lnxhc: Introduce result condition for failed check parameters (Hendrik Brueckner) [b9f4ede]
- LNXHC::Check::Base: add the "lnxhc_param_error" function (Hendrik Brueckner) [2d4899a]
- checks: rename exception identifiers (Nageswara R Sastry) [3fb8f7a]
- fs_fstab_dasd: resolved formatted issue (Nageswara R Sastry) [12f4061]
- sys_cpu_hog_processes: fix formatting and improve wording (Peter Oberparleiter) [1206bb0]
- sys_cpu_hog_processes: Check for processes hogging cpu (Aruna Balakrishnaiah) [0f1f7fa]
- sys_idle_{ttys,users}: Improve validation of idle_time check parameter (Hendrik Brueckner) [d6f2e7e]
- sys_tty_securetty: /etc/securetty requires root authority (Hendrik Brueckner) [cff284f]
- fs_tmp_dir_cleanup: Corrected the sysinfo items for RHEL distribution (Nageswara R Sastry) [73fa7a3]
- sys_logrotate_syslog: Modified for format issues (Nageswara R Sastry) [02e552c]
- sys_logrotate_syslog: Added 'deps' section (Nageswara R Sastry) [0cbab36]
- mm_hog_processes: fix truncated command line (Peter Oberparleiter) [7b859a5]
- mm_hog_processes: fix formatting and parsing issues (Peter Oberparleiter) [7da0d5b]
- mm_hog_processes: Check for processes hogging memory (Aruna Balakrishnaiah) [7120472]
- Revert "mm_hog_processes: Check for processes hogging memory" (Hendrik Brueckner) [a215123]
- mm_hog_processes: Check for processes hogging memory (Aruna Balakrishnaiah) [d2e3cbe]
- CONTRIBUTORS: Added Cryptographic checks implementation (Nageswara R Sastry) [5e55e41]
- crypto_skc_opencryptoki: SKC openCryptiki stack 64-bit (Nageswara R Sastry) [91410e3]
- crypto_openssl_stack: OpenSSL 64-bit stack (Nageswara R Sastry) [a78d2e3]
- crypto_ckc_opencryptoki: CKC openCryptiki stack 64-bit (Nageswara R Sastry) [2a67512]
- crypto_cca_stack: CCA stack (Nageswara R Sastry) [03bc212]
- crypto_32bit_skc_opencryptoki: SKC openCryptiki stack 32-bit (Nageswara R Sastry) [9389795]
- crypto_32bit_openssl_stack: OpenSSL 32-bit stack (Nageswara R Sastry) [f31d023]
- crypto_32bit_ckc_opencryptoki: CKC openCryptiki stack 32-bit (Nageswara R Sastry) [6a84c00]
- sys_tty_hvc_iucv: check number of required z/VM IUCV HVC terminal devices (Hendrik Brueckner) [5c840e9]
- sys_tty_hvc_iucv: use alternate data sources and make check more robust (Hendrik Brueckner) [a514d78]
- sys_tty_{usage, devnodes}: rework ls-tty (Hendrik Brueckner) [1af2b3c]
- sys_tty_securetty: fail if terminal is specified as secure and insecure (Hendrik Brueckner) [65271e0]
- mm_ram_usage: Check for RAM usage of the system (Aruna Balakrishnaiah) [6e64b67]
- lnxhc: fix error when writing sysinfo XML files (Peter Oberparleiter) [2abb1c4]
- net_dns_settings: Ensure that multiple nameservers are checked (Peter Oberparleiter) [e9147ea]
- net_dns_settings: Ensure nameserver is listed with correct address (Aruna Balakrishnaiah) [839c22d]
- CONTRIBUTORS: Added Rajesh checks (Nageswara R Sastry) [2cc67e5]
- storage_dasd_aliases : ID review changes (Nageswara R Sastry) [a283b8b]
- storage_dasd_aliases : looking for aliases device with out a base device (Nageswara R Sastry) [a13c75f]
- ras_kdump_on_panic: Check if kdump is configured and running (Aruna Balakrishnaiah) [eeaba72]
- sys_logrotate_syslog: (Rajesh K Pirati) [fc9077d]
- fs_fstab_dasd: (Rajesh K Pirati) [00b4527]
- storage_multipath_failed_path:Removed dasd related info and rephrase the sentence (Rajesh K Pirati) [93b343d]
- lnxhc: More minor man page updates (Peter Oberparleiter) [bdeabd0]
- lnxhc: Fix typo in man page (Peter Oberparleiter) [ed516f9]
- basic_report: Use framework functions for formatting text (Peter Oberparleiter) [a38cd10]
- lnxhc: Fix formatting issues in check plug-ins (Peter Oberparleiter) [6deeeba]
- lnxhc: Improve text formatting (Peter Oberparleiter) [6a69452]
- lnxhc: Move text formatting routines to Util.pm (Peter Oberparleiter) [3e4e385]
- lnxhc: fix man page headings (Peter Oberparleiter) [db80514]
- sys_load_avg: Check for system load (Aruna Balakrishnaiah) [2a933d0]
- lnxhc: Intercept repeated reporting of exceptions (Peter Oberparleiter) [c15ed16]
- sys_sysctl_log_level: Check for current console_loglevel (Aruna Balakrishnaiah) [445b9d4]
- mm_swap_space: Check for swap space in the system (Aruna Balakrishnaiah) [229e0b0]
- storage_dasd_eckd_blksize: Corrected the user permissions (Nageswara R Sastry) [7971f8c]
- lnxhc: fix formatting problems in consumer output (Peter Oberparleiter) [e387cd4]
- lnxhc: update multiple man pages (Peter Oberparleiter) [bfc14c5]
- vm_priv_class: ID review changes (Nageswara R Sastry) [7e74d92]
- net_bond_single_dev: ID review changes (Nageswara R Sastry) [f956577]
- lnxhc: update man page for the 'run' subcommand (Peter Oberparleiter) [270f493]
- CONTRIBUTORS: add sys_fw_cpi check and sort list (Hendrik Brueckner) [13144fe]
- lnxhc: suppress incorrect message about changing user (Peter Oberparleiter) [ea34cdf]
- CONTRIBUTORS: Added vm check and network check under Nageswara (Nageswara R Sastry) [7775b26]
- sys_cpi: Check if CPI can display meaningful Linux instance names (Hendrik Brueckner) [feb514f]
- net_bonding_single_dev: Identify bonding setups with single NICs (Nageswara R Sastry) [cef8877]
- vm_priv_class: check for z/VM guest virtual machine authorizations (Nageswara R Sastry) [6eba110]
- LNXHC::Check::Base: add "trim" option to parse_list_param() (Hendrik Brueckner) [11c8e7d]
- fs_fsck_order: use parse_list_param() (Hendrik Brueckner) [ea30d63]
- fs_fsck_order: Check if filesystems are skipped by fsck (Aruna Balakrishnaiah) [adfc576]
- fs_tmp_dir_cleanup, sec_services_insecure: use parse_list_param() (Hendrik Brueckner) [3ae7a5e]
- storage_invalid_multipath: Removed dasd related info. (Rajesh K Pirati) [ee09cbe]
- sys_tty_securetty: use parse_list_param() (Hendrik Brueckner) [d544c1a]
- fs_partition_mount: use parse_list_param() (Hendrik Brueckner) [0ddfc71]
- fs_disk_usage, fs_inode_usage: use parse_list_param() (Hendrik Brueckner) [6ee9caf]
- LNXHC::Check::Base: introduce parse_list_param() (Hendrik Brueckner) [06d8d9d]
- fs_inode_usage: use lnxhc_exception_var_list() (Hendrik Brueckner) [a95c2ac]
- fs_inode_usage: display status about processed mount points (Hendrik Brueckner) [241d104]
- fs_disk_usage: use lnxhc_exception_var_list() (Hendrik Brueckner) [e8671b3]
- fs_disk_usage: display status about processed mount points (Hendrik Brueckner) [e74c9ea]
- crypto_openssl_ibmca_config: fixed 'libica' rpm query error (Nageswara R Sastry) [65246c7]
- crypto_openssl_ibmca_config: fixed 'too many arguments' error (Nageswara R Sastry) [15cc0a2]
- net_qeth_buffercount: fixed array index when 'GuestLAN' is used. (Nageswara R Sastry) [d74410d]
- Makefile: extract changelog from git history (Hendrik Brueckner) [0603ec8]
- Makefile: generate version using git (Hendrik Brueckner) [c8e0792]
- fs_partition_mount: Check for read-only file systems (Aruna Balakrishnaiah) [2b1e9f8]
- sys_sysctl_privilege_dump: Ensure that privilege dump is switched off (Aruna Balakrishnaiah) [5dee617]
- cleanup: correct copyright year (Hendrik Brueckner) [d51a723]
- cleanup: remove whitespaces, part II. (Hendrik Brueckner) [0167eec]
- sys_idle_*: update contributors (Hendrik Brueckner) [a7abeaf]
- sys_sysctl_call_home: exception: add module load specifics (Hendrik Brueckner) [f9e3c01]
- cleanup: remove whitespaces (Hendrik Brueckner) [6b4d6d4]
- css_ccw_unused_devices: validate 'device_print_limit' parameter (Nageswara R Sastry) [c32eaf2]
- fs_tmp_dir_cleanup: Verify that temporary files are deleted regularly (Rajesh K Pirati) [4a2cac0]
- LNXHC::Check::Base: introduce check_dir_list_param() (Hendrik Brueckner) [14276d0]
- storage_dasd_eckd_blksize: Confirm 4K block size on ECKD DASD devices (Nageswara R. Sastry) [a8014b2]
- storage_dasd_cdl_part: check partitions of CDL-formatted DASDs (Nageswara R. Sastry) [8c3c812]
- CONTRIBUTORS: update (Hendrik Brueckner) [ae31a5b]
- sys_idle_users, sys_idle_ttys: Identify idle users and terminals (Hendrik Brueckner) [b92b8f5]
- sys_tty_devnodes: split sys_tty_usage (Hendrik Brueckner) [b62ab80]
- sys_tty_securetty: Check list of secure terminal devices used for root logins (Hendrik Brueckner) [c2e8f0c]
- sys_tty_hvc_iucv: Check configuration of z/VM IUCV HVC terminal devices (Hendrik Brueckner) [b206267]
- crypto_cpacf_availability: Check if the CPACF feature is in use (Hendrik Brueckner) [9b4ecbe]
- storage_multipath_failed_path: Check available path configuration (Hendrik Brueckner) [eb23a6e]
- boot_zipl_update_required: remove blank comment line (Hendrik Brueckner) [aa129a2]

* Tue Mar 20 2012 Hendrik Brueckner <brueckner@linux.vnet.ibm.com> - 1.0-1
- Linux Health Checker, Version 1.0 (Hendrik Brueckner) [9b7149a]
