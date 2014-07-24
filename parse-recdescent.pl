#!/usr/bin/env perl
package yq;
# ABSTRACT: Filter YAML through a command-line program

use strict;
use warnings;
use Pod::Usage qw( pod2usage );
use Getopt::Long qw( GetOptionsFromArray );
use YAML;
use Parse::RecDescent;

my $grammar = <<'...';
    <autotree>
    program: func | expr | int
    filter: '.' <skip:""> /\w+/
    int: /\d+/
    term: filter | int
    equal: lhs_term '==' rhs_term
    expr: equal | filter
    func: /\w+/ '(' expr ')'
    lhs_term: term
    rhs_term: term
...

#$::RD_ERRORS = 1;
#$::RD_WARN = 1;
#$::RD_HINT = 1;
#$::RD_TRACE = 1;

my $parser = Parse::RecDescent->new( $grammar );

sub main {
    my ( $class, @argv ) = @_;
    my %opt;
    GetOptionsFromArray( \@argv, \%opt,
        'h|help',
        'tree',
    );
    pod2usage(0) if $opt{help};

    my $program = shift @argv;
    pod2usage("ERROR: Must give a program") unless $program;

    if ( $opt{tree} ) {
        my $tree = $parser->program( $program );
        use Data::Dumper::Concise;
        print Dumper $tree;
        return 0;
    }

    my $buffer;
    while ( my $line = <STDIN> ) {
        if ( $buffer && $line =~ /^---/ ) {
            my @output = $class->filter( $program, YAML::Load( $buffer ) );
            print YAML::Dump( @output ) if @output;
            $buffer = '';
        }
        $buffer .= $line;
    }
    if ( $buffer ) {
        my @output = $class->filter( $program, YAML::Load( $buffer ) );
        print YAML::Dump( @output ) if @output;
    }

    return 0;
}

exit __PACKAGE__->main( @ARGV ) unless caller(0);

# Filter MUST NOT mutate $doc!
sub filter {
    my ( $class, $program, $document ) = @_;
    my $tree = $parser->program( $program );
    return run_tree( $tree, $document );
}

sub run_tree {
    my ( $tree, $document ) = @_;

    if ( $tree->{filter} ) {
        my ( $key ) = $tree->{filter}{__PATTERN1__};
        return $document->{ $key };
    }
    elsif ( $tree->{int} ) {
        return $tree->{int}{__VALUE__};
    }
    elsif ( $tree->{equal} ) {
        my $lhs = $tree->{equal}{lhs_term};
        my $rhs = $tree->{equal}{rhs_term};
        my $lhs_value = run_tree( $lhs, $document );
        my $rhs_value = run_tree( $rhs, $document );
        if ( $lhs_value == $rhs_value ) {
            return 1;
        }
        else {
            return 0;
        }
    }
    elsif ( $tree->{func} ) {
        my $arg_val = run_tree( $tree->{func}{expr}, $document );
        if ( $tree->{func}{__PATTERN1__} ) {
            if ( $arg_val ) {
                return $document;
            }
            else {
                return;
            }
        }
    }
    elsif ( $tree->{expr} ) {
        return run_tree( $tree->{expr}, $document );
    }
    elsif ( $tree->{term} ) {
        return run_tree( $tree->{term}, $document );
    }

    return;
}

=head1 SYNOPSIS

    yq <filter>

    yq -h|--help

=head1 DESCRIPTION

This program takes a stream of YAML documents on STDIN, applies a filter, then
writes the results to STDOUT.

=head1 ARGUMENTS

=head2 filter

See L<SYNTAX>.

=head1 OPTIONS

=head1 SYNTAX

=head2 FILTERS

Filters select a portion of the incoming documents. Filters can be combined
to reach deep inside the documents you're working with.

=over

=item .key

Extract a single item out of a hash.

    # INPUT
    foo: 1
    bar: 2

    $ yq .foo
    1

    $ yq .bar
    2

=back
