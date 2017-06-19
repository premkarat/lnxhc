#
# LNXHC::Util.pm
#   Linux Health Checker utility functions for use by framework and plug-ins
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

package LNXHC::Util;

use strict;
use warnings;

use Exporter qw(import);


#
# Local imports
#
use LNXHC::Consts qw($COLUMNS);
use LNXHC::Misc qw(xml_encode_predeclared);


#
# Default exports
#
our @EXPORT;


#
# On-demand exports
#
our @EXPORT_OK = qw($ALIGN_T_CENTER $ALIGN_T_LEFT $ALIGN_T_RIGHT $FIELD_T_ALIGN
		    $FIELD_T_DELIM $FIELD_T_MAX $FIELD_T_MIN $FIELD_T_WEIGHT
		    $LAYOUT_T_FIELDS $LAYOUT_T_FMT $LAYOUT_T_WIDTH
		    $LAYOUT_T_WIDTHS &format_as_html &format_as_text
		    &layout_get_width &lprintf &lsprintf);


#
# Export tags
#
our %EXPORT_TAGS = (
	consumer => [qw($ALIGN_T_CENTER $ALIGN_T_LEFT $ALIGN_T_RIGHT
			$FIELD_T_ALIGN $FIELD_T_DELIM $FIELD_T_MAX $FIELD_T_MIN
			$FIELD_T_WEIGHT $LAYOUT_T_FIELDS $LAYOUT_T_FMT
			$LAYOUT_T_WIDTH $LAYOUT_T_WIDTHS &format_as_html
			&format_as_text &layout_get_width &lprintf &lsprintf)],
);


#
# Constants
#

# Define alignment for layout fields
# Enumeration (enum align_t)

# Item is aligned to the left
our $ALIGN_T_LEFT		= 0;
# Item is aligned to the right
our $ALIGN_T_RIGHT		= 1;
# Item is centered
our $ALIGN_T_CENTER		= 2;


# Define layout for a single field
# Enumeration of data fields for struct field_t

# Minimum number of characters required by this field
our $FIELD_T_MIN		= 0;	# unsigned int
# Maximum number of characters required by this field or undef for unlimited
our $FIELD_T_MAX		= 1;	# unsigned int
# Weight determining share of extra space assigned to this field
our $FIELD_T_WEIGHT		= 2;	# unsigned int
# Item alignment
our $FIELD_T_ALIGN		= 3;	# enum align_t
# Right-hand delimiter string for this field
our $FIELD_T_DELIM		= 4;	# string


# Layout definition
# Enumeration of data fields for struct layout_t

# List of field layouts
our $LAYOUT_T_FIELDS		= 0;	# struct field_t[]
# List of resulting field widths
our $LAYOUT_T_WIDTHS		= 1;	# unsigned int[]
# Format string representing fields
our $LAYOUT_T_FMT		= 2;	# string
# Total width
our $LAYOUT_T_WIDTH		= 3;	# unsigned int


# Node format in internal representation
my $_NODE_ID		= 0;
my $_NODE_PARENT	= 1;
my $_NODE_NEXT		= 2;
my $_NODE_INDENT	= 3;
my $_NODE_PARAMS	= 4;

# Parameter of an unsorted list item node
my $_UL_LI_PARAM_CHILD	= 0;

# Parameter of a sorted list item node
my $_OL_LI_PARAM_CHILD	= 0;
my $_OL_LI_PARAM_VALUE	= 1;

# Parameter of a table cell
my $_CELL_ALIGN		= 0;
my $_CELL_TEXT		= 1;
my $_CELL_PRE		= 2;

# Node type IDs
my $_ID_P		= 0;
my $_ID_PRE		= 1;
my $_ID_UL_LI		= 2;
my $_ID_OL_LI		= 3;
my $_ID_TABLE_ROW	= 4;
my $_ID_SEPARATOR	= 5;

# Table cell alignments
my $_ALIGN_LEFT		= 0;
my $_ALIGN_CENTER	= 1;
my $_ALIGN_RIGHT	= 2;

my $_ALIGN_DEFAULT	= $_ALIGN_LEFT;

# Number of characters between a tab stop
my $_TAB_STOP		= 8;


#
# Global variables
#

my $_columns = $ENV{"COLUMNS"};


#
# Sub-routines
#

#
# _layout_prepare(layout)
#
# Prepare LAYOUT for use by layout_printf.
#
sub _layout_prepare($)
{
	my ($layout) = @_;
	my $fields = $layout->[$LAYOUT_T_FIELDS];
	my $field;
	my @widths;
	my $fmt;
	my @todos;
	my $free = $_columns;
	my $total_weight;
	my $total_width;
	my $i;

	# Initialize widths array
	$i = 0;
	$total_weight = 0;
	foreach $field (@$fields) {
		my ($min, $max, $weight, $align, $delim) = @$field;

		push(@widths, $min);
		if ($weight > 0 && (!defined($max) || $max != $min)) {
			# Variable width field, either min..max or
			# min..max share of available space
			push(@todos, $i);
			$total_weight += $weight;
		}
		$free -= $min + length($delim);
		$i++;
	}

	# Distribute free space until either all fields are satisfied or
	# no free space is left
	while (@todos && $free > 0) {
		my @new_todos;
		my $new_total_weight = 0;
		my $new_free = $free;
		my %fract_db;

		# Distribute free space among fields which still have place
		foreach $i (@todos) {
			my $max = $fields->[$i]->[$FIELD_T_MAX];
			my $weight = $fields->[$i]->[$FIELD_T_WEIGHT];
			my $width = $widths[$i];
			my $share = ($free * $weight) / $total_weight;
			my $fract = $share - int($share);

			$share = int($share);
			if (defined($max) && $width + $share > $max) {
				# Field is full
				$share = $max - $width;
			}
			$width += $share;
			$new_free -= $share;

			if (!defined($max) || $width < $max) {
				# There's more room
				push(@new_todos, $i);
				$new_total_weight += $weight;

				# Fract will be used to determine order when
				# distributing rounding error leftovers
				$fract_db{$i} = $fract;
			}
			$widths[$i] = $width;
		}

		# In case no field gained any share, distribute leftovers
		# according to share fractions to prevent an endless loop
		if ($free == $new_free) {
			while (%fract_db && $new_free > 0) {
				foreach $i (sort( {
					  $fract_db{$a} == $fract_db{$b} ?
						$a <=> $b :
						$fract_db{$b} <=> $fract_db{$a}
					  } keys(%fract_db))) {
					my $max = $fields->[$i]->
							[$FIELD_T_MAX];
					$widths[$i]++;
					if (defined($max) &&
					    $widths[$i] == $max) {
						delete($fract_db{$i});
					}
					$new_free--;
					if ($new_free == 0) {
						last;
					}
				}
			}
			last;
		}

		@todos		= @new_todos;
		$total_weight	= $new_total_weight;
		$free		= $new_free;
	}

	# Build format string
	$fmt = "";
	$total_width = 0;
	for ($i = 0; $i < scalar(@$fields); $i++) {
		my $field = $fields->[$i];
		my $align = $field->[$FIELD_T_ALIGN];
		my $delim = $field->[$FIELD_T_DELIM];
		my $width = $widths[$i];

		if ($align == $ALIGN_T_RIGHT) {
			$fmt .= "%".$width."s".$delim;
		} else {
			$fmt .= "%-".$width."s".$delim;
		}
		$total_width += $width + length($delim);
	}

	# Store results
	$layout->[$LAYOUT_T_WIDTHS]	= \@widths;
	$layout->[$LAYOUT_T_WIDTH]	= $total_width;
	$layout->[$LAYOUT_T_FMT]	= $fmt;
}

#
# lsprintf(layout, @args)
#
# Return string representation of ARGS formatted according to LAYOUT.
#
sub lsprintf($@)
{
	my ($layout, @args) = @_;
	my ($fields, $widths, $fmt) = @$layout;
	my $arg;
	my $i;

	if (!defined($widths)) {
		# Do this only once
		_layout_prepare($layout);
		($fields, $widths, $fmt) = @$layout;
	}

	$i = 0;
	foreach $arg (@args) {
		my $arg_nocolor = $arg;

		$arg_nocolor =~ s/\e\[\d+(?>(;\d+)*)m//g;
		if (length($arg_nocolor) > $widths->[$i]) {
			$arg = substr($arg, 0, $widths->[$i] - 3)."...";
		} elsif ($fields->[$i]->[$FIELD_T_ALIGN] == $ALIGN_T_CENTER) {
			my $pad = ($widths->[$i] - length($arg_nocolor)) / 2;

			$arg = (" "x$pad).$arg;
		}
		$i++;
	}

	# Fill in missing args
	while ($i < scalar(@$widths)) {
		push(@args, "");
		$i++;
	}

	return sprintf($fmt, @args);
}

#
# lprintf(layout, @args)
#
# Print string representation of ARGS formatted according to LAYOUT.
#
sub lprintf($@)
{
	my ($layout, @args) = @_;

	print(lsprintf($layout, @args));
}

#
# layout_get_width(layout)
#
# Return total width of LAYOUT.
#
sub layout_get_width($)
{
	my ($layout) = @_;
	my $width = $layout->[$LAYOUT_T_WIDTH];

	if (!defined($width)) {
		# Do this only once
		_layout_prepare($layout);
		$width = $layout->[$LAYOUT_T_WIDTH];
	}

	return $width;
}

#
# _get_prev(current, indent)
#
# Find the predecessor node for a text line starting with INDENT indentation
# after node CURRENT.
#
sub _get_prev($$)
{
	my ($current, $indent) = @_;

	# Find previous node with correct indentation level
	while ($indent < $current->[$_NODE_INDENT]) {
		my $parent = $current->[$_NODE_PARENT];

		last if (!defined($parent));
		$current = $parent;
	}

	return $current;
}

#
# _add_p(current, indent, line)
#
# Insert a new paragraph node containing the text found in LINE. The position
# of the new node is determined by node CURRENT and indentation level INDENT.
#
sub _add_p($$$)
{
	my ($current, $indent, $line) = @_;
	my $prev = _get_prev($current, $indent);
	my $new;

	# Merge with existing node if possible
	if ($prev->[$_NODE_ID] == $_ID_P) {
		push(@{$prev->[$_NODE_PARAMS]}, $line);
		return $prev;
	}

	# Create new paragraph node with same parent and indent as predecessor
	$new = [ $_ID_P, $prev->[$_NODE_PARENT], undef, $prev->[$_NODE_INDENT],
		 [ $line ] ];
	$prev->[$_NODE_NEXT] = $new;

	return $new;
}

#
# _add_separator(current)
#
# Insert a new separator node after the CURRENT node.
#
sub _add_separator($)
{
	my ($current) = @_;
	my $prev = _get_prev($current, $current->[$_NODE_INDENT]);
	my $new;

	# Skip if separator already exists at this position
	if ($prev->[$_NODE_ID] == $_ID_SEPARATOR) {
		return $prev;
	}

	# Create non-content paragraph to separate nodes, for example
	# between two tables
	$new = [ $_ID_SEPARATOR, $prev->[$_NODE_PARENT], undef,
		 $prev->[$_NODE_INDENT], ];
	$prev->[$_NODE_NEXT] = $new;

	return $new;
}

#
# _add_pre(current, indent, line)
#
# Insert a new preformat node containing the text found in LINE. The position
# of the new node is determined by node CURRENT and indentation level INDENT.
#
sub _add_pre($$$)
{
	my ($current, $indent, $line) = @_;
	my $prev = _get_prev($current, $indent);
	my $new;

	# Remove introducing character
	$line =~ s/^#//;

	# Merge with existing node if possible
	if ($prev->[$_NODE_ID] == $_ID_PRE) {
		push(@{$prev->[$_NODE_PARAMS]}, $line);
		return $prev;
	}

	# Create new preformat node with same parent and indent as predecessor
	$new = [ $_ID_PRE, $prev->[$_NODE_PARENT], undef,
		 $prev->[$_NODE_INDENT], [ $line ] ];
	$prev->[$_NODE_NEXT] = $new;

	return $new;
}

#
# _add_ul_li(current, indent)
#
# Insert a node representing a list item in a bulleted list. The position of
# the new node is determined by node CURRENT and indentation level INDENT.
#
sub _add_ul_li($$)
{
	my ($current, $indent) = @_;
	my $prev = _get_prev($current, $indent);
	my $new_parent;
	my $new_child;
	my $new_indent;

	# For lines to be considered a continuation of this list item,
	# the indentation level must be one more than that of the list item
	# itself
	$new_indent = $indent + 1;

	# Create a dummy child node
	$new_child = [ $_ID_SEPARATOR, undef, undef, $new_indent, [ ] ];

	# Create new ul_li node with same parent and indent as predecessor
	$new_parent = [ $_ID_UL_LI, $prev->[$_NODE_PARENT], undef,
			$prev->[$_NODE_INDENT], [ $new_child ] ];
	$prev->[$_NODE_NEXT] = $new_parent;

	# Add link to parent
	$new_child->[$_NODE_PARENT] = $new_parent;

	return $new_child;
}

#
# _add_ol_li(current, indent, value)
#
# Insert a node representing a list item in a numbered list. The position of
# the new node is determined by node CURRENT and indentation level INDENT.
# VALUE specifies the number of this list item.
#
sub _add_ol_li($$$)
{
	my ($current, $indent, $value) = @_;
	my $prev = _get_prev($current, $indent);
	my $new_parent;
	my $new_child;
	my $new_indent;
	my $new_value;

	# For lines to be considered a continuation of this list item,
	# the indentation level must be one more than that of the list item
	# itself
	$new_indent = $indent + 1;

	# Create new paragraph node as first child of new ul_li node.
	$new_child = [ $_ID_SEPARATOR, undef, undef, $new_indent, [ ] ];

	# Create new ul_li node with same parent and indent as predecessor
	$new_parent = [ $_ID_OL_LI, $prev->[$_NODE_PARENT], undef,
			$prev->[$_NODE_INDENT], [ $new_child, $value ] ];
	$prev->[$_NODE_NEXT] = $new_parent;

	# Add link to parent
	$new_child->[$_NODE_PARENT] = $new_parent;

	return $new_child;
}

#
# _add_cell(cells, text)
#
# Add table cell data specified by TEXT to list of table cells CELLS.
#
sub _add_cell($$)
{
	my ($cells, $text) = @_;
	my $align = $_ALIGN_DEFAULT;
	my $pre = 0;

	if ($text =~ s/^([<^>])//) {
		$align = $_ALIGN_LEFT if ($1 eq "<");
		$align = $_ALIGN_CENTER if ($1 eq "^");
		$align = $_ALIGN_RIGHT if ($1 eq ">");
	}
	if ($text =~ s/^#//) {
		$pre = 1;
	}
	push(@{$cells}, [ $align, $text, $pre ]);
}

#
# _parse_cells(line)
#
# Parse cell definitions found in text LINE. Return list of parsed cell data.
#
sub _parse_cells($)
{
	my ($line) = @_;
	my @cells;
	my $in_esc = 0;
	my $last = 0;
	my $i;

	# Definition of cell text format:
	#
	# cell   = "|" , [ align ] , [ "#" ] , text
	# align  = "<" | "^" | ">"
	# text   = { any character - "|" | escaped character }
	# escaped character = "\" , any character
	#
	# Example: |<1283|>#echo \| cat
	for ($i = 1; $i < length($line); $i++) {
		my $ch = substr($line, $i, 1);

		if ($in_esc) {
			$in_esc = 0;
		} elsif ($ch eq "\\") {
			$in_esc = 1;
		} elsif ($ch eq "|") {
			my $text = substr($line, $last + 1, $i - $last - 1);
			_add_cell(\@cells, $text);
			$last = $i;
		}
	}

	# Add last cell
	if ($last != $i) {
		my $text = substr($line, $last + 1, $i - $last - 1);
		_add_cell(\@cells, $text);
	}

	return \@cells;
}

#
# _add_table_row(current, indent, line)
#
# Insert a new node representing a table row based on the cell data found
# in LINE. The position of the new node is determined by node CURRENT and
# indentation level INDENT.
#
sub _add_table_row($$$)
{
	my ($current, $indent, $line) = @_;
	my $prev = _get_prev($current, $indent);
	my $cells = _parse_cells($line);
	my $new;

	# Create new table row node with same parent and indent as predecessor
	$new = [ $_ID_TABLE_ROW, $prev->[$_NODE_PARENT], undef,
		 $prev->[$_NODE_INDENT], $cells ];
	$prev->[$_NODE_NEXT] = $new;

	return $new;
}

#
# _expand_tabs(line)
#
# Convert tabs to spaces until tab stop.
#
sub _expand_tabs($)
{
	my ($line) = @_;

	while ($line =~ /^([^\t]*)\t(.*)$/) {
		my $pos = length($1);
		my $blanks = (int($pos / $_TAB_STOP) + 1) * $_TAB_STOP - $pos;

		$line = $1.(" "x$blanks).$2;
	}

	return $line;
}

#
# _raw_to_internal(raw)
#
# Convert RAW text with formatting instructions according to man page
# 'lnxhc_text_formatting.7' into an internal format.
#
# Description of internal format:
#
# internal:              node
# node:                  [ id, parent, next, indent, params ]
# p_node_params:         [ text_line1, text_line2, ... ]
# pre_node_params:       [ text_line1, text_line2, ... ]
# ul_li_node_params:     [ child_node ]
# ol_li_node_params:     [ child_node, value ]
# table_row_node_params: [ cell1, cell2, ... ]
# cell:                  [ align, text, preformat ]
# separator_node_params: [ ]
#
sub _raw_to_internal($)
{
	my ($text) = @_;
	my @lines = split(/\n/, $text);
	my $root = [ $_ID_SEPARATOR, undef, undef, 0, [] ];
	my $current = $root;

	foreach my $line (@lines) {
		my $indent = 0;
		my $new_node;

		# Expand tabs
		$line = _expand_tabs($line);

		# Calculate indentation level
		if ($line =~ s/^(\s+)//) {
			$indent = length($1);
		}

		# Handle container nodes first
		if ($line =~ s/(^[\*-]\s*)//) {
			# List item in bulleted list
			$current = _add_ul_li($current, $indent);
			$indent += length($1);
		} elsif ($line =~ s/^(\d+)(\.\s*)//) {
			# List item in numbered list
			$current = _add_ol_li($current, $indent, $1);
			$indent += length($1) + length($2);
		}

		if ($line =~ /^#/) {
			# Preformatted text
			$current = _add_pre($current, $indent, $line);
		} elsif ($line =~ /^\|/) {
			# Table row data
			$current = _add_table_row($current, $indent, $line);
		} elsif ($line eq "") {
			# Separator
			$current = _add_separator($current);
		} else {
			# Normal text paragraph
			$current = _add_p($current, $indent, $line);
		}
	}

	return $root;
}

#
# _break_into_lines(string, columns, indent1, indent2)
#
# Break a string into lines at appropriate columns (whitespaces).
#
sub _break_into_lines($$@)
{
	my ($string, $columns, @indents) = @_;
	my @result;
	my @words = split(/\s+/, $string);
	my $indent;
	my $current;

	return shift(@indents) if (!@words);

	foreach my $word (@words) {
repeat:
		if (!defined($current)) {
			$indent = shift(@indents) if (@indents);
			$current = $indent.$word;
		} else {
			if ((length($current) + 1 + length($word)) > $columns) {
				push(@result, $current);
				$current = undef;
				goto repeat;
			} else {
				$current .= " ".$word;
			}
		}
	}
	push(@result, $current) if (defined($current));

	return @result;
}

#
# _unescape(text)
#
# Replace escaped characters (\ + char) in TEXT with their original
# represenation.
#
sub _unescape($)
{
	my ($text) = @_;

	$text =~ s/\\(.)/$1/g;

	return $text;
}

#
# _align_to_str(align)
#
# Convert alignment code ALIGN into an HTML attribute.
#
sub _align_to_str($)
{
	my ($align) = @_;
	my $align_str;

	if ($align == $_ALIGN_LEFT) {
		$align_str = "left";
	} elsif ($align == $_ALIGN_CENTER) {
		$align_str = "center";
	} elsif ($align == $_ALIGN_RIGHT) {
		$align_str = "right";
	} else {
		return "";
	}

	return "align=\"$align_str\"";
}

#
# _internal_to_html(internal, indent)
#
# Return HTML representation of data found in INTERNAL. INDENT specifies the
# requested indentation level of the output.
#
sub _internal_to_html($$);
sub _internal_to_html($$)
{
	my ($internal, $indent) = @_;
	my $result = "";
	my $prefix;
	my $last_id = $_ID_SEPARATOR;

	$prefix = " "x$indent;

	for (my $node = $internal; $node; $node = $node->[$_NODE_NEXT]) {
		my ($id, $parent, $next, $n_indent, $params) = @{$node};

		# Closing tags
		if ($id != $last_id) {
			# Add closing tags for elements that span multiple
			# nodes
			if ($last_id == $_ID_UL_LI) {
				$result .= $prefix."</ul>\n";
			} elsif ($last_id == $_ID_OL_LI) {
				$result .= $prefix."</ol>\n";
			} elsif ($last_id == $_ID_TABLE_ROW) {
				$result .= $prefix."</table>\n";
			}
		}

		if ($id == $_ID_P) {
			my $text = join("\n", @{$params});

			$text = _unescape($text);
			$text = xml_encode_predeclared($text);
			$text =~ s/^/$prefix  /mg;
			$result .= "$prefix<p>\n";
			$result .= $text."\n";
			$result .= $prefix."</p>\n";
		} elsif ($id == $_ID_PRE) {
			my $text = join("\n", @{$params});

			$text = _unescape($text);
			$text = xml_encode_predeclared($text);
			$result .= "$prefix<pre>$text</pre>\n";
		} elsif ($id == $_ID_UL_LI) {
			my ($child) = @{$params};

			# Add opening tag
			$result .= $prefix."<ul>\n" if ($last_id != $_ID_UL_LI);
			$result .= $prefix."  <li>\n";
			$result .= _internal_to_html($child, $indent + 4);
			$result .= $prefix."  </li>\n";
		} elsif ($id == $_ID_OL_LI) {
			my ($child, $value) = @{$params};

			# Add opening tag
			$result .= $prefix."<ol>\n" if ($last_id != $_ID_OL_LI);
			$result .= $prefix."  <li value=\"$value\">\n";
			$result .= _internal_to_html($child, $indent + 4);
			$result .= $prefix."</li>\n";
		} elsif ($id == $_ID_TABLE_ROW) {
			my (@cells) = @{$params};
			my $first = ($last_id != $_ID_TABLE_ROW) ? 1 : 0;

			# Add opening tag
			$result .= $prefix."<table border=\"1\">\n" if ($first);
			$result .= $prefix."  <tr>\n";
			foreach my $cell (@cells) {
				my ($align, $text, $pre) = @{$cell};
				my $attrs = "";
				my $elem_name = $first ? "th" : "td";

				# Prepare cell text
				$text = _unescape($text);
				$text = xml_encode_predeclared($text);

				# Set alignment attribute
				$attrs .= " "._align_to_str($align);

				# Add element data
				$result .= $prefix."    <".
					   $elem_name.$attrs.">";
				$result .= "<pre>" if ($pre);
				$result .= $text;
				$result .= "</pre>" if ($pre);
				$result .= "</".$elem_name.">\n";
			}
			$result .= $prefix."  </tr>\n";
		}

		$last_id = $id;
	}

	# Closing tags at end of output
	if ($last_id == $_ID_UL_LI) {
		$result .= $prefix."</ul>\n";
	} elsif ($last_id == $_ID_OL_LI) {
		$result .= $prefix."</ol>\n";
	} elsif ($last_id == $_ID_TABLE_ROW) {
		$result .= $prefix."</table>\n";
	}

	return $result;
}

#
# _prepare_cell_text(cell[, size])
#
# Return text for cell data CELL. When SIZE is specified, the text will
# include padding to fit a cell of SIZE characters.
#
sub _prepare_cell_text($;$)
{
	my ($cell, $size) = @_;
	my ($align, $text, $pre) = @{$cell};

	$text = _unescape($text);
	if (!$pre) {
		$text =~ s/(^\s*|\s*$)//g;
		$text =~ s/\s+/ /g;
	}

	if (defined($size)) {
		my $len = length($text);
		my $pad = 0;
		my $pad2 = 0;

		if ($align == $_ALIGN_RIGHT) {
			$pad = $size - $len;
		} elsif ($align == $_ALIGN_LEFT) {
			$pad2 = $size - $len;
		} elsif ($align == $_ALIGN_CENTER) {
			$pad = int(($size - $len) / 2 + 0.9);
			$pad2 = $size - $len - $pad;
		}
		$text = (" "x$pad).$text.(" "x$pad2);
	}

	return $text;
}

#
# _get_table_cell_sizes(node)
#
# Return a list of cell sizes for the table that starts with NODE.
#
sub _get_table_cell_sizes($)
{
	my ($node) = @_;
	my @cell_sizes;

	for (; $node && $node->[$_NODE_ID] == $_ID_TABLE_ROW;
	     $node = $node->[$_NODE_NEXT]) {
		my $cells = $node->[$_NODE_PARAMS];

		for (my $i = 0; $i < scalar(@{$cells}); $i++) {
			my $text = _prepare_cell_text($cells->[$i]);
			my $len = length($text);

			if (!defined($cell_sizes[$i]) ||
			    $cell_sizes[$i] < $len) {
				$cell_sizes[$i] = $len;
			}
		}
	}

	return \@cell_sizes;
}

#
# _table_row_to_text(cells, cell_sizes)
#
# Return a textual representation of the table row data found in CELLS.
# CELL_SIZES specifies the sizes to which each cell content should be
# padded.
#
sub _table_row_to_text($$)
{
	my ($cells, $cell_sizes) = @_;
	my $row = "";

	for (my $i = 0; $i < scalar(@{$cell_sizes}); $i++) {
		my $size = $cell_sizes->[$i];
		my $cell = $cells->[$i];

		if (!defined($cell)) {
			$cell = [ $_ALIGN_DEFAULT, "", 0 ];
		}
		$row .= "|"._prepare_cell_text($cell, $size);
	}
	$row .= "|";

	return $row;
}

#
# _get_table_line(CELL_SIZES)
#
# Return a line containing an ASCII-art representation of a horizontally
# delimiting line in a table. CELL_SIZES specifies the size of each cell
# in the table.
#
sub _get_table_line($)
{
	my ($cell_sizes) = @_;
	my $line = "";

	$line = "+";
	foreach my $size (@{$cell_sizes}) {
		$line .= ("-"x$size)."+";
	}

	return $line;
}

#
# _get_bullet(level)
#
# Return bullet character for an unsorted list item of nesting level LEVEL.
#
sub _get_bullet($)
{
	my ($level) = @_;

	return "-" if ($level % 2 == 0);
	return "*";
}

#
# _internal_to_text(internal, base_indent, columns[, level])
#
# Return text representation of data found in INTERNAL. INDENT specifies the
# requested indentation level of the output. COLUMNS specifies the maximum
# number of columns to use for output (including indentation).
#
sub _internal_to_text($$$;$);
sub _internal_to_text($$$;$)
{
	my ($node, $indent, $columns, $level) = @_;
	my $prefix;
	my $result = "";
	my $last_id = $_ID_SEPARATOR;
	my $cell_sizes;

	$level = 0 if (!defined($level));
	$prefix = " "x$indent;

	for (; $node; $node = $node->[$_NODE_NEXT]) {
		my ($id, $parent, $next, $node_indent, $params) = @{$node};

		if ($last_id == $_ID_TABLE_ROW && $id != $_ID_TABLE_ROW) {
			# Add line after table
			my $line = _get_table_line($cell_sizes);

			$result .= $prefix.$line."\n";
			$result .= "\n";
		}

		if ($id == $_ID_P) {
			# Paragraph
			my $text = join(" ", @{$params});
			my @lines;

			$text = _unescape($text);
			@lines =_break_into_lines($text, $columns, $prefix);

			$result .= join("\n", @lines)."\n\n";
		} elsif ($id == $_ID_PRE) {
			# Preformatted paragraph
			my $text = join("\n", @{$params});

			$text = _unescape($text);
			$text =~ s/^/$prefix/mg;

			$result .= $text."\n\n";
		} elsif ($id == $_ID_UL_LI) {
			# List item in bulleted list
			my ($child) = @{$params};
			my $text;
			my $bullet = _get_bullet($level);

			$text = _internal_to_text($child, $indent + 2,
						  $columns, $level + 1);
			substr($text, $indent, 2) = $bullet." ";

			$result .= $text."\n";
		} elsif ($id == $_ID_OL_LI) {
			# List item in numbered list
			my ($child, $value) = @{$params};
			my $len = length($value);
			my $text;

			$text = _internal_to_text($child, $indent + $len + 2,
						  $columns, $level + 1);
			substr($text, $indent, $len + 2) = $value.". ";

			$result .= $text."\n";
		} elsif ($id == $_ID_TABLE_ROW) {
			# Table row
			my $text;
			my $line;

			if ($last_id != $_ID_TABLE_ROW) {
				# First row in table, get sizes
				$cell_sizes = _get_table_cell_sizes($node);
				# Add line before table
				$line = _get_table_line($cell_sizes);
				$result .= $prefix.$line."\n";
			}

			$text = _table_row_to_text($params, $cell_sizes);

			$result .= $prefix.$text."\n";

			if ($last_id != $_ID_TABLE_ROW) {
				# Add line after heading
				$result .= $prefix.$line."\n";
			}
		}

		$last_id = $id;
	}

	if ($last_id == $_ID_TABLE_ROW) {
		# Add line after table
		my $line = _get_table_line($cell_sizes);

		$result .= $prefix.$line."\n";
		$result .= "\n";
	}

	# Remove trailing empty lines
	$result =~ s/\n+$/\n/;

	return $result;
}


#
# format_as_html(raw[, indent])
#
# Return HTML representation of the RAW text containing formatting instructions
# according to man page 'lnxhc_text_format.7'. INDENT specifies the indentation
# level.
#
sub format_as_html($;$)
{
	my ($raw, $indent) = @_;
	my $internal;

	$indent = 0 if (!defined($indent));
	$internal = _raw_to_internal($raw);

	return _internal_to_html($internal, $indent);
}

#
# format_as_text(raw[, indent, columns])
#
# Return textual representation of the RAW text containing formatting
# instructions according to man page 'lnxhc_text_format.7'. INDENT specifies
# the indentation level and COLUMNS the number of available columns. A negative
# COLUMNS number specifies that the maximum number of available columns minus
# the provided number should be used.
#
sub format_as_text($;$$)
{
	my ($raw, $indent, $columns) = @_;
	my $internal;

	$indent = 0 if (!defined($indent));
	if (!defined($columns)) {
		$columns = $COLUMNS;
	} elsif ($columns < 0) {
		$columns += $COLUMNS;
	}

	$internal = _raw_to_internal($raw);

	return _internal_to_text($internal, $indent, $columns);
}


#
# Code entry
#

# Indicate successful module initialization
1;
