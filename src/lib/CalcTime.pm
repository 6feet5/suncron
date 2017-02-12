package CalcTime;

# This file is part of SunCron.
#
# SunCron is free software; you can redistribute it and/or modify
# it under the terms of the GNU Gerenral Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# SunCron is distributed in the hope that it will be usefull,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with SunCron; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# Copyright: (C) 2009-2010 Johan Stenarson <johan.stenarson@gmail.com>

use warnings;
use strict;

use DateTime;
use Astro::Sunrise;

our $VERSION = '0.1';

#
# The following variables are allowed in an expression
#
my %params = ( 
    'time'      => 1,       # Replaced with current time
    'sunset'    => 1,       # Replaced with time of sunset
    'sunrise'   => 1        # Replaced with time of sunrise
    );

#
# The following operators are allowed in an expression
# The higher value, the later the expression is evaluated.
#
my %operators = ( 
    '-'         => 1,       # Substract two operands 
    '+'         => 2,       # Add two operands
    '<'         => 3,       # Test left side is less than right side
    '>'         => 4,       # Test left side is less than right side 
    'or'        => 5,       # One or both must be true
    'and'       => 6,       # Both peft and right must be true
    );



=head1 USAGE

=over

=item B<new>

=over

=item C<CalcTime-E<gt>new();>
=item C<CalcTime-E<gt>new( time =E<gt> DateTime-E<gt>now(), longitude =E<gt> 12.345, latitude =E<gt> 34.567 );>

=back

Create a new CalcTime object. The time parameter will override the default value, which is
to use the current time at object creation. Longitude and latitude values need to be set
if sunrise or sunset are used in the expressions.

=cut

sub new {
    my ($class, %args) = @_;
    
    my $timezone    = $args{'timezone'}   || 'UTC';
    my $time        = $args{'time'}       || DateTime->now(time_zone => $timezone);
    my $latitude    = $args{'latitude'}   || 0.0;
    my $longitude   = $args{'longitude'}  || 0.0;

    my $self = { _time => $time, _latitude => $latitude, _longitude => $longitude };

    return bless($self, $class);
}

=item B<set_datetime>

=over

=item C<$parser-E<gt>set_datetime(DateTime-E<gt>now());>

=back

This will set the time to use instead of current time, which is default if no 
time is given.

=cut

sub set_datetime ($) {
    my ($self, $time) = @_;

    $self->{'_time'} = $time;
}

=item B<set_coordinate>

=over

=item C<$parser-E<gt>set_coordinate( 12.345, 23.456 );>

=back

This will set the coordinates used to calculate sunset and sunrise.
First parameter is longitude and second parameter is latitude.
Both are in decimal degrees

=cut

sub set_coordinate ($$) {
    my ($self, $longitude, $latitude) = @_;

    $self->{'_longitude'} = $longitude;
    $self->{'_latitude'} = $latitude;
}

=item B<evaluate>

=over

=item C<$parser-E<gt>evaluate("time E<gt> 07:00 and time E<lt> sunrise");>

=back

Test if time expression is true and if so, return the final DateTime
object.

=cut

sub evaluate {
    my ($self, $expression) = @_;
    my $result = 1;

    my @parts = $self->_prepare($expression);

    $result = $self->_calculate(@parts);

    if(ref($result) eq 'DateTime::Duration') {
        my $tmp = $self->{_time}->clone();
        $tmp->set_hour($result->hours);
        $tmp->set_minute($result->minutes);
        $result = $tmp;
    }

    return $result;
}

=item B<crosses_horizon>

=over

=item C<$parser-E<gt>crosses_horizon();>

=back

Test if sun goes up and down (not midnight sun or polar night)

=cut

sub crosses_horizon {
    my $self = shift;

    if(not defined $self->{_sunset}) {
        $self->_calc_sun();
    }

    return (($self->{_sunset}->hours != $self->{_sunrise}->hours) and ($self->{_sunset}->minutes != $self->{_sunrise}->minutes));
}

#
# Convert string format to an array of elements. The order will be a postfix
# order for easier calculation. 
# Each element will be tested if it is an allowed operation or variable.
# 
sub _prepare {
    my ($self, $rule) = @_;
    my @result = ();
    my @stack = ();
    
    # Insert spaces for easier split
    $rule =~ s/</ \< /g;
    $rule =~ s/>/ \> /g;
    $rule =~ s/\+/ + /g;
    $rule =~ s/-/ - /g;
    $rule =~ s/and/ and /g;
    $rule =~ s/or/ or /g;
    $rule =~ s/ [ ]+/ /g;
    $rule =~ s/^ *//;
    $rule =~ s/ *$//;

    my @parts = split(/ /, $rule);

    foreach my $item (@parts) {
        if( ($item =~ m/[\d]{1,2}:[\d]{1,2}/) or $params{$item} ) {
            push( @result, $item );
        } else {
            OPERATOR: while(@stack) {
                die("Syntax error: Unknown expression '$item'\n") if not defined($operators{$item});
                if($operators{$item} > $operators{$stack[0]}) {
                    push(@result, pop(@stack));
                } else {
                    last OPERATOR;
                }
            }
            push(@stack, $item);
        }
    }

    while(@stack) {
        push(@result, pop(@stack));
    }

    return @result;
}

#
# Parse an element.
#
# Elements can be a variable (time, sunrise or sunset) or a time (HH:MM).
#
sub _parse_parameter {
    my ($self, $parameter) = @_;
    my $result;
    
    if($parameter eq "time") {
        $result = $self->{_time}->clone();
    } elsif($parameter eq "sunset") {
        if(not defined $self->{_sunset}) {
            $self->_calc_sun();
        }
        $result = $self->{_sunset}->clone();
    } elsif($parameter eq "sunrise") {
        if(not defined $self->{_sunrise}) {
            $self->_calc_sun();
        }
        $result = $self->{_sunrise}->clone();
    } elsif($parameter =~ m/[\d]{1,2}:[\d]{1,2}/) {
        # Try parsing it as a HH:MM value
        my @items = split(/:/, $parameter);
        $result = DateTime::Duration->new( hours => $items[0], minutes => $items[1] );
    }

    return $result;
}

sub _calc_sun {
    my $self = shift;

    #
    # NOTE! Daylight Saving parameter is set to 0, since offset is adjusted
    # accordingly from DateTime object, that is DST is included in offset.
    #
    my ($sunrise, $sunset) = sunrise($self->{_time}->year, $self->{_time}->month, $self->{_time}->day, 
                                     $self->{_longitude}, $self->{_latitude}, $self->{_time}->offset / 3600, 0);

    $self->{_sunrise} = $self->_parse_parameter($sunrise);
    $self->{_sunset} = $self->_parse_parameter($sunset);
}

#
# Calculate the postfix expression
#
sub _calculate {
    my ($self, @expr) = @_;
    my @stack = ();

    foreach my $item (@expr) {
        if( ($item =~ m/[\d]{1,2}:[\d]{1,2}/) or $params{$item} ) {
            push(@stack, $self->_parse_parameter($item));
        } else {
            my $rhs = pop(@stack);
            my $lhs = pop(@stack);
            push(@stack, $self->_do_operator($item, $lhs, $rhs));
        }
    }

    return pop(@stack);
}

sub _do_operator {
    my ($self, $operator, $lhs, $rhs) = @_;
    my $result;

    if($operator eq "+") {
        $lhs->add_duration( $rhs );
        $result = $lhs;
    } elsif( $operator eq "-") {
        $lhs->subtract_duration( $rhs );
        $result = $lhs;
    } elsif( $operator eq ">") {
        # We can't compare a real time with a duration. Treat duration as a 
        # real time.
        if($lhs->isa('DateTime::Duration')) {
            my $tmp = $self->{_time}->clone()->set( hour => $lhs->hours, minute => $lhs->minutes );
            $lhs = $tmp;
        }
        if($rhs->isa('DateTime::Duration')) {
            my $tmp = $self->{_time}->clone()->set( hour => $rhs->hours, minute => $rhs->minutes );
            $rhs = $tmp;
        }
        $result = DateTime->compare( $lhs, $rhs ) > 0;
    } elsif( $operator eq "<") {
        if($lhs->isa('DateTime::Duration')) {
            my $tmp = $self->{_time}->clone()->set( hour => $lhs->hours, minute => $lhs->minutes );
            $lhs = $tmp;
        }
        if($rhs->isa('DateTime::Duration')) {
            my $tmp = $self->{_time}->clone()->set( hour => $rhs->hours, minute => $rhs->minutes );
            $rhs = $tmp;
        }
        $result = DateTime->compare( $lhs, $rhs ) < 0;
    } elsif( $operator eq "or") {
        $result = ( $lhs or $rhs );
    } elsif( $operator eq "and") {
        $result = ( $lhs and $rhs );
    } else {
        die("Syntax error: Unknown operator '$operator'\n");
    }

    #$result = 0 if not defined $result;

    #print _debug_item($lhs) . " $operator " . _debug_item($rhs) . " = " .  _debug_item($result) . "\n";

    return $result;
}

sub _debug_item {
    my $item = shift;

    if(ref($item) eq 'DateTime::Duration') {
        return $item->hours . ":" . $item->minutes;
    }

    return $item;
}

__END__
=head1 NAME

CalcTime - An object that compute simple time expressions

=head1 SYNOPSIS

    use CalcTime;

    $parser = CalcTime->new();
    $parser = CalcTime->new( 
        time        => DateTime->new( month => 1, day => 1 ),
        longitude   => 17.345,
        latitude    => 53.123
    );

    $parser->set_datetime( DateTime->new( year => 1971 );
    $parser->set_coordinate( 12.345, 45.678 );
 
    $result = $parser->evaluate("time > 06:15 and sunrise > time");  

=head1 DESCRIPTION

This module will parse a clear text time expression and evaluate if it is 
true or not.

Expressions are written in clear text and may contain operators, variables and 
time expressions.

=head2 Operators

Valid operators are:

=over

=item B<+>

Add two times

=item B<->

Subtracts a time from another

=item B<E<lt>>

Verify left time expression is less than right expression. 

=item B<E<gt>>

Verify left time expression is greater than right expression. 

=item B<and>

Left and right expression must be true

=item B<or>

Left, right or both expressions must be true.

=back

=head2 Variables

Valid variables are:

=over

=item B<time>

Current time at object creation. It is also possible to set the current time, 
using the B<time> parameter at creation, or the B<set_datetime()> method.

=item B<sunset>

Time when sun sets at the location given during object contsruction or the the
B<set_coordinates()> method. The date used is the same date as in time 
(ie. current time).

=item B<sunrise>

Time when sun sets at the location given during object contsruction or the the
B<set_coordinates()> method. The date used is the same date as in time
(ie. current time).

=back

=head2 Time expressions

Time expressions are written as HH:MM, where HH is the hour and MM is the 
minute. One or two digits may be used, and they can both be in the range 
00 to 99 (time and date will be adjusted accordingly).

=cut


=back

=head1 AUTHOR

Johan Stenarson <johan.stenarson@gmail.com>

=head1 COPYRIGHT

Copyright (c) 2009 Johan Stenarson.  All rights reserved.  This
program is free software; you can redistribute it and/or modify it.

The full text of the license can be found in the copyright file included
with this module.

=cut
