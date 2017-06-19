#
# check.base
#   Base class/functions for a Linux health check (in python)
#
# Copyright IBM Corp. 2012
#
# Author: Gowri Shankar <gowrishankar.m@linux.vnet.ibm.com>
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors: See file CONTRIBUTORS which is part of this package
#

import os
import abc
import sys

from check.error import *

# Export symbols from this module
__all__ = ["LnxhcCheck", "LnxhcException"]

class LnxhcCheck(object):
	""" Abstract class for LNXHC checks """

	__metaclass__ = abc.ABCMeta

	# Non-zero if health check program should output
	# additional information
	VERBOSE = os.environ['LNXHC_VERBOSE']

	# Non-zero if health check program should output
	# debugging information
	DEBUG = os.environ['LNXHC_DEBUG']

	def __init__(self):
		# Health check ID is subclass name
		check_id = self.__class__.__name__

		if not check_id or check_id == "":
			raise LnxhcBaseError("check id not defined")

		self.__check_id = check_id

		# Health check installation directory
		self.__check_dir = os.environ['LNXHC_CHECK_DIR']

		# Path to the file used to report exceptions
		self.__ex_file = os.environ['LNXHC_EXCEPTION']

		return

	def __str__(self):
		return("%s" %self.__check_id)

	@staticmethod
	def info(msg):
		"""
		Report an information in stdout
		@msg: message to print
		"""
		sys.stdout.write("%s\n" %msg)
		return

	@staticmethod
	def verbose(msg):
		"""
		Report an additional information in stdout
		@msg: message to print
		"""
		if LnxhcCheck.VERBOSE:
			sys.stdout.write("%s\n" %msg)
		return

	@staticmethod
	def debug(msg):
		"""
		Report an additional debug information in stdout
		@msg: message to print
		"""
		if LnxhcCheck.DEBUG:
			sys.stdout.write("%s\n" %msg)
		return

	@staticmethod
	def error(msg):
		"""
		Report an error that check can not proceed
		@msg: message to print before exiting
		"""
		sys.stderr.write("%s\n" %msg)
		sys.exit(1)

	@staticmethod
	def fail_dep(msg):
		"""
		Report a failed dependency
		@msg: message to print before exiting
		"""
		sys.stderr.write("%s\n" %msg)
		sys.exit(64)

	def setup(self):
		"""
		Validate input from framework
		"""
		if (self.__check_id and self.__check_dir and
		    self.__ex_file) and LnxhcCheck.DEBUG:
			return
		LnxhcCheck.error("""
				This program cannot be called directly.
				Please use the 'lnxhc run' function to
				call this program!""")

	def cause(self, ex_obj):
		"""
		Raise LnxhcException objects into LNXHC framework
		@ex_obj: LnxhcException object to raise from
		"""
		try:
			fo = open(self.__ex_file, "a")
		except:
			raise LnxhcBaseError("unable open %s file" %
					       self.__ex_file)

		fo.write("%s\n" %ex_obj)
		xvard = ex_obj.getxvar_dict()
		for var, val in xvard.iteritems():
			fo.write("%s='%s'\n" %(var, val))
		fo.close()
		return

	def get_param(self, name):
		"""
		Return parameter value set in check definition
		@name: parameter name to lookup
		"""
		lnxhc_param = "LNXHC_PARAM_%s" %name
		ret = None
		try:
			ret = os.environ[lnxhc_param]
		except KeyError:
			raise LnxhcParamError("param '%s' not found" %
					        lnxhc_param)
		return ret

	def get_sysinfo(self, name):
		"""
		Return sysinfo set in check definition
		@name: sysinfo name to lookup
		"""
		lnxhc_si = "LNXHC_SYSINFO_%s" %name
		ret = None
		try:
			ret = os.environ[lnxhc_si]
		except KeyError:
			raise LnxhcSysinfoError("sysinfo '%s' not found" %
						  lnxhc_si)
		return ret

	@abc.abstractmethod
	def run(self):
		"""
		Run health check instructions
		"""
		return

class LnxhcException(Exception):
	""" class for LNXHC check exceptions """

	def __init__(self, name):
		Exception.__init__(self, name)
		self.__xname = name
		self.__xattr = {}
		return

	def __str__(self):
		return("%s" %self.__xname)

	def setxvar(self, var, value):
		"""
		Set exception variable in LNXHC Exception object
		@var: exception variable to set
		@value: value of the variable
		"""
		if not var or var == "":
			raise LnxhcBaseError("invalid exception variable")

		self.__xattr[var] = value
		return

	def getxvar(self, var):
		"""
		Get value of exception variable from LNXHC Exception
		object
		@var: exception variable for which value is read
		"""
		if not var or var == "":
			raise LnxhcBaseError("invalid exception variable")
		try:
			value = self.__xattr[var]
		except keyError:
			raise LnxhcBaseError("no such exception variable '%s'"
					      %var)
		return value

	def getxvar_dict(self):
		"""
		Return exception variables dictionary
		"""
		return self.__xattr
