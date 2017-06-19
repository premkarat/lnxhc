#
# check.error
#   Errors handled within LNXHC python framework
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

__all__ = ['LnxhcBaseError', 'LnxhcCheckError', 'LnxhcParamError',
	   'LnxhcSysinfoError', 'LnxhcCheckDependency']

class LnxhcError(Exception):
	"""Base class for LNXHC error"""
	def __init__(self, error):
		Exception.__init__(self, error)
		self.error = error
		return

	def __str__(self):
		return("%s" %self.error)

class LnxhcBaseError(LnxhcError):
	"""Lnxhc error within framework"""
	pass

class LnxhcCheckError(LnxhcError):
	"""Lnxhc error within check"""
	pass

class LnxhcParamError(LnxhcError):
	"""Lnxhc error while handling check parameters"""
	pass

class LnxhcSysinfoError(LnxhcError):
	"""Lnxhc error while handling sysinfo"""
	pass

class LnxhcCheckDependency(LnxhcError):
	"""Lnxhc check dependency not met"""
	pass
