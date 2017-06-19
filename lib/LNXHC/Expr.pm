#
# LNXHC::Expr.pm
#   Linux Health Checker support functions for handling boolean expressions
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

package LNXHC::Expr;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#
use LNXHC::Consts qw($MATCH_ID);
use LNXHC::Misc qw(debug2 quote);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&expr_evaluate &expr_parse &expr_to_string);


#
# Constants
#

# Node types used in an expression tree

# Operator node:	[ type, operator ]
my $_NODE_TYPE_OP		= 0;
# Sub-expression node:	[ type, sub-expression ]
my $_NODE_TYPE_SUB		= 1;
# Statement node:	[ type, op, key, value ]
my $_NODE_TYPE_STATEMENT	= 2;
# Literal node:		[ type, literal ]
my $_NODE_TYPE_LITERAL		= 3;


#
# Global variables
#


#
# Sub-routines
#

# Forward declarations for use in recursion
sub expr_parse($$;$$);
sub expr_to_string($);
sub _copy_expr($);
sub expr_evaluate($$$);

#
# _parse_quoted_value(source, quote, line)
#
# Parse LINE for a string quoted using QUOTE. Unescape all escaped characters
# within the string. Return remaining line and resulting string. If an error
# occurs, use SOURCE to indicate the source location of the expression.
#
# result: ( remaining line, value )
#
sub _parse_quoted_value($$$)
{
	my ($source, $quote, $line) = @_;
	my $check;
	my $value;

	$check = $line;
	# Replace quoted characters to be able to match for first unescaped
	# quoting character. We can't remove them since we need the total
	# string length afterward.
	$check =~ s/\\./xx/g;
	if (!($check =~ s/^([^$quote]*)$quote.*$/$1/)) {
		die("$source: error in expression: missing closing quote\n");
	}
	$value = substr($line, 0, length($check));
	# Adjust line by removing value + quote character
	$line = substr($line, length($check) + 1);
	# Remove escape characters from value string
	$value =~ s/\\(.)/$1/g;

	return ($line, $value);
}

#
# expr_parse(source, line[, level, orig])
#
# Parse expression LINE and return an internal representation of the
# expression. LEVEL indicates the parentheses nesting level. If an error
# occurs, use SOURCE to indicate the source location of the expression
#
sub expr_parse($$;$$)
{
	my ($source, $line, $level, $orig) = @_;
	my $num_statements = 0;
	my @result;
	my $error;

	$level = 0 if (!defined($level));
	$orig = $line if (!defined($orig));
	while (!($line =~ /^\s*$/)) {
		my $key;
		my $op;
		my $value;

		# Get closing parenthesis
		if ($line =~ s/^\s*\)(.*)$/$1/) {
			if ($num_statements == 0) {
				$error = "empty parenthesis";
				goto error;
			}
			if ($level > 0) {
				return ($line, \@result);
			}
			$error = "unexpected closing parenthesis\n";
			goto error;
		}
		# Check for chained statements
		if ($num_statements > 0) {
			# Get operator
			if ($line =~ s/^\s*(and|or)(.*)$/$2/i) {
				push(@result, [$_NODE_TYPE_OP, lc($1)]);
			} else {
				$error = "missing operator";
				goto error;
			}
		}
		# Get negation
		if ($line =~ s/^\s*!(.*)$/$1/) {
			push(@result, [ $_NODE_TYPE_OP, "!" ]);
		}
		# Get opening parentheses
		if ($line =~ s/^\s*\((.*)$/$1/) {
			my $sub_expr;

			($line, $sub_expr) = expr_parse($source, $line,
							$level + 1, $orig);
			push(@result, [$_NODE_TYPE_SUB, $sub_expr]);
			$num_statements++;
			next;
		}
		# Get key
		if ($line =~ s/^\s*($MATCH_ID)(.*)$/$2/i) {
			# Found keyword
			$key = $1;
		} else {
			$error = "missing identifier";
			goto error;
		}
		# Get operator
		if ($line =~ s/^\s*(=~|!=|<=|>=|<|>|=)(.*)$/$2/) {
			# Found operator
			$op = $1;
		} else {
			$error = "missing operator";
			goto error;
		}
		# Get value
		if ($line =~ s/^\s*("|')(.*)$/$2/) {
			# Found quoted value
			($line, $value) = _parse_quoted_value($source, $1,
							     $line);
		} elsif ($line =~ s/^\s*([^\s\)]+)(.*)$/$2/) {
			# Found value
			$value = $1;
		} else {
			$error = "missing value string";
			goto error;
		}
		push(@result, [ $_NODE_TYPE_STATEMENT, $op, $key, $value ]);
		$num_statements++;
	}

	if ($level > 0) {
		$error = "missing closing parenthesis";
		goto error;
	}

	return ("", \@result);

error:
	die("$source: error in expression: $error\n".
	    "$orig\n".
	    (" "x(length($orig) - length($line)))."^\n");
}

#
# expr_to_string(expr)
#
# Return a textual representation of EXPR.
#
sub expr_to_string($)
{
	my ($expr) = @_;
	my $sep = "";
	my $result;

	$result = "[ ";
	foreach my $node (@$expr) {
		my $type = $node->[0];

		$result .=  $sep;
		$sep = ", ";
		if ($type == $_NODE_TYPE_OP) {
			my $op = $node->[1];

			$result .= "[ OP, \"$op\" ]";
		} elsif ($type == $_NODE_TYPE_STATEMENT) {
			my $op;
			my $key;
			my $value;

			(undef, $op, $key, $value) = @$node;
			$result .= "[ STATEMENT, \"$op\", \"$key\", ".
				   "\"$value\" ]";
		} elsif ($type == $_NODE_TYPE_SUB) {
			$result .= "[ SUB, ";
			$result .= expr_to_string($node->[1]);
			$result .= " ]";
		} elsif ($type == $_NODE_TYPE_LITERAL) {
			my $literal = $node->[1];
			$result .= "[ LITERAL, $literal ]";
		}
	}
	$result .= " ]";

	return $result;
}

#
# _eval_cmp(a, b)
#
# Compare values a and b. Return 0 if both values are eqal, -1 if a is lower
# than b, 1 if a is greater than b. Assume that a and b are numbers or version
# identifiers.
#
sub _eval_cmp($$)
{
	my ($a, $b) = @_;
	my @a = split(/[_\.,-]+/, $a);
	my @b = split(/[_\.,-]+/, $b);
	my $i = 0;
	my $c;

	if (($a =~ /^\s*\d+\s*$/) && ($b =~ /^\s*\d+\s*$/)) {
		return $a <=> $b;
	}
	if ((scalar(@a) < 2) || (scalar(@b) < 2)) {
		return $a cmp $b;
	}
	while (defined($a[$i]) && defined($b[$i])) {
		if (($a[$i] =~ /^\s*\d+\s*$/) && ($b[$i] =~ /^\s*\d+\s*$/)) {
			$c = $a[$i] <=> $b[$i];
		} else {
			$c = $a[$i] cmp $b[$i];
		}
		if ($c != 0) {
			return $c;
		}
		$i++;
	}
	if (!defined($a[$i])) {
		if (!defined($b[$i])) {
			return 0;
		}
		# undef < def
		return -1;
	}
	# def > undef
	return 1;
}

#
# _evaluate_statement(op, key, value, var)
#
# Evaluate statement "KEY OP VALUE" using the values for KEY found in VAR.
# Return 1 if the statement is true, 0 otherwise. If an error occurs, use
# SOURCE to indicate the source location of the expression
#
sub _evaluate_statement($$$$$)
{
	my ($source, $op, $key, $value, $var) = @_;
	my $actual = $var->{$key};
	my $result = 0;

	if (!defined($actual)) {
		warn("$source: Unknown variable '$key' referenced\n");
		$actual = "<undef>";
	} elsif ($op eq "=") {
		$result = 1 if ($value eq $actual);
	} elsif ($op eq "!=") {
		$result = 1 if ($value ne $actual);
	} elsif ($op eq "<") {
		$result = 1 if (_eval_cmp($actual, $value) < 0);
	} elsif ($op eq ">") {
		$result = 1 if (_eval_cmp($actual, $value) > 0);
	} elsif ($op eq "<=") {
		$result = 1 if (_eval_cmp($actual, $value) <= 0);
	} elsif ($op eq ">=") {
		$result = 1 if (_eval_cmp($actual, $value) >= 0);
	} elsif ($op eq "=~") {
		# Use eval to catch syntax errors in regexp
		eval {
			local $SIG{__DIE__};
			$result = 1 if ($actual =~ /$value/);
		}
	} else {
		die("$source: error in expression: unknown operator '$op' ".
		    "found\n");
	}
	debug2("($key=\"$actual\", $key$op\"$value\", result=$result)\n");

	return $result;
}

#
# _evaluate_rec(source, expr, var)
#
# Evaluate expression EXPR using the variable values in VAR. Return 1 if the
# expression evaluates to true, 0 otherwise. Note that EXPR is changed in the
# course of evaluation.
#
sub _evaluate_rec($$$)
{
	my ($source, $expr, $var) = @_;
	my $i;

	# Evaluate sub-expressions
	for ($i = 0; $i < scalar(@$expr); $i++) {
		my $node = $expr->[$i];
		my $type = $node->[0];

		# Replace sub-expressions with their result
		if ($type == $_NODE_TYPE_SUB) {
			$expr->[$i] = [ $_NODE_TYPE_LITERAL,
					expr_evaluate($source, $node->[1],
						      $var) ];
		}
	}
	# Evaluate statements
	for ($i = 0; $i < scalar(@$expr); $i++) {
		my $node = $expr->[$i];
		my $type = $node->[0];

		# Replace statements with their result
		if ($type == $_NODE_TYPE_STATEMENT) {
			my $key;
			my $value;
			my $op;

			(undef, $op, $key, $value) = @$node;
			$expr->[$i] = [ $_NODE_TYPE_LITERAL,
					_evaluate_statement($source, $op, $key,
							   $value, $var) ];
		}
	}
	# Evaluate negations
	for ($i = 0; $i < scalar(@$expr); $i++) {
		my $node = $expr->[$i];
		my ($type, $op) = @$node;

		# Replace negations with their result
		if (($type == $_NODE_TYPE_OP) && ($op eq "!")) {
			my ($rtype, $rliteral) = @{$expr->[$i + 1]};

			if ($rtype != $_NODE_TYPE_LITERAL) {
				die("Unexpected node type found during ".
				    "negation: $rtype\n");
			}
			splice(@$expr, $i, 2, [ $_NODE_TYPE_LITERAL,
						!$rliteral ? 1 : 0 ]);
			$i--;
			next;
		}
	}
	# Evaluate AND statements
	for ($i = 0; $i < scalar(@$expr); $i++) {
		my $node = $expr->[$i];
		my ($type, $op) = @$node;

		# Replace AND operations with their result
		if (($type == $_NODE_TYPE_OP) && ($op eq "and")) {
			my ($ltype, $lliteral) = @{$expr->[$i - 1]};
			my ($rtype, $rliteral) = @{$expr->[$i + 1]};

			if ($ltype != $_NODE_TYPE_LITERAL) {
				die("Unexpected node type found during ".
				    "AND: $ltype\n");
			}
			if ($rtype != $_NODE_TYPE_LITERAL) {
				die("Unexpected node type found during ".
				    "AND: $rtype\n");
			}
			splice(@$expr, $i - 1, 3, [ $_NODE_TYPE_LITERAL,
						    $lliteral && $rliteral ]);
			$i--;
			next;
		}
	}
	# Evaluate OR statements
	for ($i = 0; $i < scalar(@$expr); $i++) {
		my $node = $expr->[$i];
		my ($type, $op) = @$node;

		# Replace OR operations with their result
		if (($type == $_NODE_TYPE_OP) && ($op eq "or")) {
			my ($ltype, $lliteral) = @{$expr->[$i - 1]};
			my ($rtype, $rliteral) = @{$expr->[$i + 1]};

			if ($ltype != $_NODE_TYPE_LITERAL) {
				die("Unexpected node type found during ".
				    "AND: $ltype\n");
			}
			if ($rtype != $_NODE_TYPE_LITERAL) {
				die("Unexpected node type found during ".
				    "AND: $rtype\n");
			}
			splice(@$expr, $i - 1, 3, [ $_NODE_TYPE_LITERAL,
						    $lliteral || $rliteral ]);
			$i--;
			next;
		}
	}
	# Return final result
	if (scalar(@$expr) != 1) {
		die("Unresolved expression found after evaluation\n");
	}

	return $expr->[0]->[1];
}

#
# _copy_expr(expr)
#
# Return a copy of expression EXPR.
#
sub _copy_expr($)
{
	my ($expr) = @_;
	my $node;
	my @result;

	foreach $node (@$expr) {
		my $type = $node->[0];

		if ($type == $_NODE_TYPE_OP) {
			push(@result, [ @$node ]);
		} elsif ($type == $_NODE_TYPE_SUB) {
			push(@result, [ $type, _copy_expr($node->[1])]);
		} elsif ($type == $_NODE_TYPE_STATEMENT) {
			push(@result, [ @$node ]);
		} elsif ($type == $_NODE_TYPE_LITERAL) {
			push(@result, [ @$node ]);
		} else {
			die("Found unknown node type in expression.\n");
		}
	}

	return \@result;
}

#
# expr_evaluate(source, expr, var)
#
# Evaluate expression EXPR using the variable values in VAR. Return 1 if the
# expression evaluates to true, 0 otherwise.
#
sub expr_evaluate($$$)
{
	my ($source, $expr, $var) = @_;

	$expr = _copy_expr($expr);

	return _evaluate_rec($source, $expr, $var);
}


#
# Code entry
#

# Indicate successful module initialization
1;
