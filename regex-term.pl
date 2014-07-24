#!/usr/bin/env perl
package yq;
# ABSTRACT: Filter YAML through a command-line program

use strict;
use warnings;
use Pod::Usage qw( pod2usage );
use Getopt::Long qw( GetOptionsFromArray );
use YAML;

sub main {
    my ( $class, @argv ) = @_;
    my %opt;
    GetOptionsFromArray( \@argv, \%opt,
        'h|help',
    );
    pod2usage(0) if $opt{help};

    my $program = shift @argv;
    pod2usage("ERROR: Must give a program") unless $program;

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

my $filter_re = qr{[.]\w+};
my $int_re = qr{\d+};
my $term_re = qr{$filter_re|$int_re};
my $equal_re = qr{$term_re\s+==\s+$term_re};
my $func_re = qr{(\w+)[(]\s+($equal_re)\s+[)]};

# Filter MUST NOT mutate $doc!
sub filter {
    my ( $class, $program, $document ) = @_;
    if ( $program =~ m{^$filter_re$} ) {
        my ( undef, $key ) = split /[.]/, $program;
        return $document->{ $key };
    }
    elsif ( $program =~ m{^$int_re$} ) {
        return $program;
    }
    elsif ( $program =~ m{^$equal_re$} ) {
        my ( $lhs, $op, $rhs ) = split /\s+(==)\s+/, $program;

        my $lhs_value = $class->filter( $lhs, $document );
        my $rhs_value = $class->filter( $rhs, $document );

        if ( $lhs_value == $rhs_value ) {
            return 1;
        }
        else {
            return 0;
        }
    }
    elsif ( $program =~ m{^$func_re$} ) {
        my ( $name, $argument ) = ( $1, $2 );
        my $arg_val = $class->filter( $argument, $document );
        if ( $name eq 'grep' ) {
            if ( $arg_val ) {
                return $document;
            }
            else {
                return;
            }
        }
    }
    die "Could not parse program '$program'\n";
}

exit __PACKAGE__->main( @ARGV ) unless caller(0);

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
