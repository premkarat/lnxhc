#
# LNXHC::Prop.pm
#   Linux Health Checker property parsing helper routines
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

package LNXHC::Prop;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#
use LNXHC::Consts qw($PROP_EXP_ALWAYS $PROP_EXP_NO_PRIO $PROP_EXP_PRIO
		     $PROP_NS_T_REGEXP);
use LNXHC::Misc qw(filter_ids_by_wildcard match_wildcard);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw(&prop_parse_key);


#
# Constants
#

# This data structure represents one work item in the process of expanding
# wildcards in property key.
# Enumeration of data fields for struct _item_t

# Node that corresponds to the current processing state of the key
my $_ITEM_T_NODE	= 0;
# Sub-keys at current processing state
my $_ITEM_T_SUBKEYS	= 1;
# Sub-IDs of current processing state
my $_ITEM_T_IDS		= 2;

# This data structure represents one node in the graph that represents the
# definition of allowed property keys.

# Node head contains a definition of the sub-key which is accepted at this
# location within a property key.
my $_NODE_T_HEAD	= 0;
# Node tag contains the property ID tag for leaf nodes.
my $_NODE_T_TAG		= 1;
# Node children contains list of possible sub-nodes
my $_NODE_T_CHILDREN	= 2;


#
# Global variables
#


#
# Sub-routines
#

#
# _split_key(key)
#
# Split KEY into list of subkeys. Needed because split() doesn't
# handle empty components adequately for this purpose.
#
sub _split_key($)
{
	my ($key) = @_;
	my @subkeys;

	while ($key =~ s/^([^\.]*)\.(.*)/$2/) {
		push(@subkeys, $1);
	}
	push(@subkeys, $key);

	return @subkeys;
}

sub _get_node($$$);

#
# _get_node(ns, keydef, tag)
#
# Return node for the specified KEYDEF.
#
sub _get_node($$$)
{
	my ($ns, $keydef, $tag) = @_;
	my $first_keydef;
	my $rest_keydef;
	my $head;

	if ($keydef =~ /^([^.]+)\.(.*)$/) {
		$first_keydef = $1;
		$rest_keydef = $2;
	} else {
		$first_keydef = $keydef;
	}

	$head = $ns->{$first_keydef};
	if (!defined($head)) {
		# Literal
		$head = $first_keydef;
	}

	if (defined($rest_keydef)) {
		# More keydefs to process
		return [ $head, undef, [ _get_node($ns, $rest_keydef, $tag) ] ];
	} else {
		# All keydefs processed
		return [ $head, $tag, undef ];
	}
}

sub _merge_node($$);

#
# _merge_node(parent, node)
#
# Add NODE as child of PARENT. NODE must have at most one child node.
#
sub _merge_node($$)
{
	my ($parent, $node) = @_;
	my ($head, $tag, $children) = @$node;
	my $child;

	# Ensure that node has at most one child
	if (defined($children) && scalar(@$children) > 1) {
		die("internal error: property parse tree ".
		    "definition incorrect!\n");
	}

	# Look for a sub-node of parent with the same head
	foreach $child (@{$parent->[$_NODE_T_CHILDREN]}) {
		my $child_head = $child->[$_NODE_T_HEAD];
		my $child_tag = $child->[$_NODE_T_TAG];

		if ($child_head ne $head) {
			# This is not the node you are looking for..
			next;
		}

		# Found insertion point
		if (defined($child_tag) && defined($tag)) {
			# Sanity check: only one tag can be associated per node
			die("internal error: property parse tree ".
			    "definition incorrect!\n");
		}

		# Repeat until leaf of node is reached
		if (defined($children)) {
			# Add single child to children
			_merge_node($child, $children->[0]);
		} else {
			# Add our tag
			$child->[$_NODE_T_TAG] = $tag;
		}
		return;
	}

	# No matching child node found, add new one
	push(@{$parent->[$_NODE_T_CHILDREN]}, $node);
}

#
# _get_parse_tree(map, ns)
#
# Return root node of a parse tree for the specified property parsing MAP and
# NAMESPACE definition.
#
# result:   [ undef, undef, [ node1, node2, ... ] ]
# node:     [ head, tag, children ]
# head:     ns|literal
# tag:      corresponding property ID tag
# children:     subnodes
# ns:       [ type, regexp, fn_get_ids, fn_id_is_valid ]
# literal:  string to match against
# subnodes: [ node1.1, node1.2, ... ]
#
sub _get_parse_tree($$)
{
	my ($map, $ns) = @_;
	my $root = [ undef, undef, []];
	my $keydef;

	foreach $keydef (keys(%{$map})) {
		my $tag = $map->{$keydef};
		my $node;

		$node = _get_node($ns, $keydef, $tag);

		_merge_node($root, $node);
	}

	return $root;
}

#
# _find_subnodes(parent, subkey)
#
# Find sub-nodes of PARENT which matches SUBKEY.
#
sub _find_subnodes($$)
{
	my ($parent, $subkey) = @_;
	my $children = $parent->[$_NODE_T_CHILDREN];
	my $subnode;
	my @result;

	if ($subkey eq "*") {
		# Shortcut for "*" - match all children
		return [ @$children ];
	} elsif ($subkey eq "") {
		# Empty sub-key may refer to selected items
		if (scalar(@$children) != 1) {
			# Accept only one child node when considering
			# selections - this should always be true
			return [];
		}
		return [ $children->[0] ];
	}
	foreach $subnode (@$children) {
		my $subhead = $subnode->[$_NODE_T_HEAD];

		if (ref($subhead) eq "ARRAY") {
			# This is a namespace node
			my $regexp = $subhead->[$PROP_NS_T_REGEXP];

			if ($subkey =~ /^$regexp$/) {
				push(@result, $subnode);
			}
		} else {
			# This is a literal node
			if ($subhead eq $subkey ||
			    match_wildcard($subhead, $subkey)) {
				push(@result, $subnode);
			}
		}
	}

	return \@result;
}

#
# _get_resolved_subkeys(node, subkeys, level, create)
#
# Return list of resolved subkeys.
#
sub _get_resolved_subkeys($$$$)
{
	my ($node, $subkeys, $level, $create) = @_;
	my $head = $node->[$_NODE_T_HEAD];
	my $subkey = $subkeys->[$level];
	my @result;
	my $err;
	my $type;
	my $regexp;
	my $fn_ids_get;
	my $fn_ids_get_selected;
	my $fn_id_is_valid;

	if (ref($head) ne "ARRAY") {
		# Return single subkey
		return (undef, [ $head ]);
	}
	($type, $regexp, $fn_ids_get, $fn_ids_get_selected,
	 $fn_id_is_valid) = @$head;

	# Check for wildcards
	if ($subkey =~ /[\?\*]/) {
		my $num_ids;

		# Wildcards, get matching IDs
		@result = &$fn_ids_get($subkeys, $level, $create);
		$num_ids = scalar(@result);
		@result = filter_ids_by_wildcard($subkey, $type, @result);
		if (!@result && $num_ids > 0) {
			$err = "no $type matched $subkey";
			goto err;
		}
	} elsif ($subkey eq "") {
		# An empty sub-key may be used to refer to selected IDs
		if (!defined($fn_ids_get_selected)) {
			# This namespace does not support selection
			$err = "found unexpected empty sub-key";
			goto err;
		}
		# Empty string, match selected IDs
		@result = &$fn_ids_get_selected($subkeys, $level,
						  $create);
		if (!@result) {
			$err = "no $type was selected";
			goto err;
		}
	} else {
		# No wildcards, check namespace for this key
		if (!&$fn_id_is_valid($subkeys, $level, $create)) {
			$err = "no property for $type '$subkey' found";
			goto err;
		}
		# ID exists in this namespace, mark for processing
		push(@result, $subkey);
	}

	return (undef, \@result);
err:
	return ($err, undef);
}

#
# _determine_action(node, subkeys, level, expand)
#
# Determine what to do with this subkey.
#
sub _determine_action($$$$)
{
	my ($node, $subkeys, $level, $expand) = @_;
	my $tag = $node->[$_NODE_T_TAG];
	my $children = $node->[$_NODE_T_CHILDREN];
	my $act_finish;
	my $act_expand;
	my $act_cont;
	my $err;

	# Check ending conditions
	if (!defined($subkeys->[$level + 1])) {
		my $could_fin = defined($tag);
		my $could_exp = defined($children);

		# This is the last subkey - what to do next?
		if ($could_fin &&
		      !($expand == $PROP_EXP_PRIO && $could_exp)) {
			# Generate a result for this node
			$act_finish = 1;
		}
		if ($could_exp &&
		      ($expand == $PROP_EXP_ALWAYS ||
		       $expand == $PROP_EXP_PRIO ||
		       $expand == $PROP_EXP_NO_PRIO && !$could_fin)) {
			# Expand sub-keys of this node
			$act_expand = 1;
		}

		if (!$act_finish && !$act_expand) {
			$err = "incomplete key";
		}
	} elsif (!defined($children)) {
		# There are more subkeys but they are not expected
		$err = "trailing sub-keys found: '".
			join(".", @$subkeys[$level + 1 ..
				scalar(@$subkeys) - 1])."'";
	} else {
		$act_cont = 1;
	}

	return ($err, $act_finish, $act_expand, $act_cont);
}

#
# _handle_item(item, level, expand, create, skip_invalid, result, todo,
#              num_subkeys)
#
# Handle specified item.
#
sub _handle_item($$$$$$$$)
{
	my ($item, $level, $expand, $create, $skip_invalid, $result, $todo,
	    $num_subkeys) = @_;
	my ($node, $subkeys, $subids) = @$item;
	my $subkey = $subkeys->[$level];
	my $subnodes;
	my $subnode;
	my $err;

	# Find sub-nodes in the definition that matches the subkey at this level
	$subnodes = _find_subnodes($node, $subkey);
	if (!@$subnodes) {
		if ($skip_invalid) {
			return undef;
		}
		if ($subkey eq "") {
			$err = "found unexpected empty sub-key";
		} else {
			$err = "unknown sub-key '$subkey'";
		}
		goto out;
	}

	# Process each possible sub-node
	foreach $subnode (@$subnodes) {
		my ($head, $tag) = @$subnode;
		my $resolved;
		my $act_finish;
		my $act_expand;
		my $act_cont;
		my $res_key;

		# Resolve wildcards in namespace subkey
		($err, $resolved) = _get_resolved_subkeys($subnode, $subkeys,
						          $level, $create);
		if (defined($err)) {
			if ($skip_invalid) {
				next;
			}
			goto out;
		}

		# Determine action
		($err, $act_finish, $act_expand, $act_cont) =
			_determine_action($subnode, $subkeys, $level, $expand);
		if (defined($err)) {
			if ($skip_invalid) {
				next;
			}
			goto out;
		}

		# Perform action for each resolved subkey
		foreach $res_key (@$resolved) {
			my $new_subkeys = [ @$subkeys ];
			my $new_subids = [ @$subids ];

			# Replace potential pattern with resolved subkey
			$new_subkeys->[$level] = $res_key;

			# If this is a namespace, we need to add the
			# resolved ID to the list of sub-IDs
			if (ref($head) eq "ARRAY") {
				push(@$new_subids, $res_key);
			}

			if ($act_expand) {
				# Put expanded item on the todo list
				push(@$todo, [ $subnode, [ @$new_subkeys, "*" ],
					       [ @$new_subids ] ]);

				# Increase maximum subkey level if necessary
				if (scalar(@$new_subkeys) >= $$num_subkeys) {
					$$num_subkeys =
						scalar(@$new_subkeys) + 1;
				}
			}
			if ($act_finish) {
				# Put property ID on the result list
				push(@$result, [ $tag, @$new_subids ]);
			}
			if ($act_cont) {
				# Put new item on the todo list
				push(@$todo, [ $subnode, [ @$new_subkeys ],
					       [ @$new_subids ] ]);
			}
		}
	}

out:
	return $err;
}

#
# prop_parse_key(map, ns, expand, create, skip_invalid, key)
#
# Parse property KEY against property definition defined by MAP and NS.
# EXPAND defines how incomplete sub-keys are handled. If CREATE is non-zero,
# check IDs against possible IDs and not against existing IDs. If SKIP_INVALID
# is non-zero, skip keys which are not valid, otherwise abort with an error.
#
# Return (undef, \@prop_id_list) on success, (err_msg, undef) on error.
#
sub prop_parse_key($$$$$$)
{
	my ($map, $ns, $expand, $create, $skip_invalid, $key) = @_;
	my $root_node;
	my $subkeys;
	my $num_subkeys;
	my $level;
	my $err_msg;
	my $todo_list;
	my @result;

	if ($key eq "") {
		if ($skip_invalid) {
			return (undef, []);
		}
		$err_msg = "empty property key";
		goto err;
	}

	# Create parse tree from definitions
	$root_node = _get_parse_tree($map, $ns);

	# Determine subkeys of specified key
	$subkeys = [ _split_key($key) ];
	$num_subkeys = scalar(@$subkeys);

	$todo_list = [ [ $root_node, $subkeys, [] ] ];

	# Iterate over each sub-key level
	for ($level = 0; $level < $num_subkeys; $level++) {
		my $new_todo_list = [];
		my $item;

		foreach $item (@$todo_list) {
			$err_msg = _handle_item($item, $level, $expand,
						$create, $skip_invalid,
						\@result, $new_todo_list,
						\$num_subkeys);
			if (defined($err_msg)) {
				goto err;
			}
		}

		$todo_list = $new_todo_list;

		# Fast exit if there is nothing left todo
		if (!@$new_todo_list) {
			last;
		}
	}
	return (undef, \@result);

err:
	return ($err_msg, undef);
}


#
# Code entry
#

# Indicate successful module initialization
1;
