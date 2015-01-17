package Astro::Sunrise;

=head1 NAME

Astro::Sunrise - Perl extension for computing the sunrise/sunset on a given day

=head1 SYNOPSIS

 use Astro::Sunrise;
#use Astro::Sunrise qw(:constants);

 ($sunrise, $sunset) = sunrise(YYYY,MM,DD,longitude,latitude,Time Zone,DST);
 ($sunrise, $sunset) = sunrise(YYYY,MM,DD,longitude,latitude,Time Zone,DST,ALT);
 ($sunrise, $sunset) = sunrise(YYYY,MM,DD,longitude,latitude,Time Zone,DST,ALT,inter);

 $sunrise = sun_rise(longitude,latitude);
 $sunset = sun_set(longitude,latitude);

 $sunrise = sun_rise(longitude,latitude,ALT);
 $sunset = sun_set(longitude,latitude,ALT);

 $sunrise = sun_rise(longitude,latitude,ALT,day_offset);
 $sunset = sun_set(longitude,latitude,ALT,day_offset);

=head1 DESCRIPTION

This module will return the sunrise/sunset for a given day.

 Eastern longitude is entered as a positive number
 Western longitude is entered as a negative number
 Northern latitude is entered as a positive number
 Southern latitude is entered as a negative number

inter is set to either 0 or 1.
If set to 0 no Iteration will occur.
If set to 1 Iteration will occur.
Default is 0.

There are a number of sun altitides to chose from.  The default is
-0.833 because this is what most countries use. Feel free to
specify it if you need to. Here is the list of values to specify
altitude (ALT) with, including symbolic constants for each.

=over

=item B<0> degrees

Center of Sun's disk touches a mathematical horizon

=item B<-0.25> degrees

Sun's upper limb touches a mathematical horizon

=item B<-0.583> degrees

Center of Sun's disk touches the horizon; atmospheric refraction accounted for

=item B<-0.833> degrees, DEFAULT

Sun's supper limb touches the horizon; atmospheric refraction accounted for

=item B<-6> degrees, CIVIL

Civil twilight (one can no longer read outside without artificial illumination)

=item B<-12> degrees, NAUTICAL

Nautical twilight (navigation using a sea horizon no longer possible)

=item B<-15> degrees, AMATEUR

Amateur astronomical twilight (the sky is dark enough for most astronomical observations)

=item B<-18> degrees, ASTRONOMICAL

Astronomical twilight (the sky is completely dark)

=back

=cut
use strict;
#use warnings;
use POSIX qw(floor);
use Math::Trig;
use Carp;
use DateTime;
use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $RADEG $DEGRAD );

require Exporter;

@ISA       = qw( Exporter );
@EXPORT    = qw( sunrise sun_rise sun_set );
@EXPORT_OK = qw( DEFAULT CIVIL NAUTICAL AMATEUR ASTRONOMICAL );
%EXPORT_TAGS = ( 
	constants => [ @EXPORT_OK ],
	);
	
$VERSION =  '0.91';
$RADEG   = ( 180 / pi );
$DEGRAD  = ( pi / 180 );
my $INV360     = ( 1.0 / 360.0 );

my $upper_limb = '1';

=head1 USAGE

=over

=item B<sunrise>

=over

=item C<($sunrise, $sunset) = sunrise(YYYY,MM,DD,longitude,latitude,Time Zone,DST);>

=item C<($sunrise, $sunset) = sunrise(YYYY,MM,DD,longitude,latitude,Time Zone,DST,ALT);>



Returns the sunrise and sunset times, in HH:MM format.
(Note: Time Zone is the offset from GMT and DST is daylight
savings time, 1 means DST is in effect and 0 is not).  In the first form,
a default altitude of -.0833 is used.  In the second form, the altitude
is specified as the last argument.  Note that adding 1 to the
Time Zone during DST and specifying DST as 0 is the same as indicating the
Time Zone correctly and specifying DST as 1.

=item F<Notes on Iteration>

=over

=item F<($sunrise, $sunset) = sunrise(YYYY,MM,DD,longitude,latitude,Time Zone,DST,ALT,inter);>

The orginal method only gives an approximate value of the Sun's rise/set times. 
The error rarely exceeds one or two minutes, but at high latitudes, when the Midnight Sun 
soon will start or just has ended, the errors may be much larger. If you want higher accuracy, 
you must then use the iteration feature. This feature is new as of version 0.7. Here is
what I have tried to accomplish with this.

a) Compute sunrise or sunset as always, with one exception: to convert LHA from degrees to hours,
   divide by 15.04107 instead of 15.0 (this accounts for the difference between the solar day 
   and the sidereal day.

b) Re-do the computation but compute the Sun's RA and Decl, and also GMST0, for the moment 
   of sunrise or sunset last computed.

c) Iterate b) until the computed sunrise or sunset no longer changes significantly. 
   Usually 2 iterations are enough, in rare cases 3 or 4 iterations may be needed.

=item I<For Example>

 ($sunrise, $sunset) = sunrise( 2001, 3, 10, 17.384, 98.625, -5, 0 );
 ($sunrise, $sunset) = sunrise( 2002, 10, 14, -105.181, 41.324, -7, 1, -18);
 ($sunrise, $sunset) = sunrise( 2002, 10, 14, -105.181, 41.324, -7, 1, -18, 1);
=back

=back

=cut

sub sunrise  {
my ( $year, $month, $day, $lon, $lat, $TZ, $isdst, $alt, $iter ) = @_;
   my $altit      = $alt || -0.833;
   my $iteration = defined($iter) ? $iter:0 ;
   
   if ($iteration)   {
   # This is the initial start

   my $d = days_since_2000_Jan_0( $year, $month, $day ) + 0.5 - $lon / 360.0;
   my ($tmp_rise_1,$tmp_set_1) = sun_rise_set($d, $lon, $lat,$altit,15.04107);

   # Now we have the initial rise/set times next recompute d using the exact moment
   # recompute sunrise
   
   my $tmp_rise_2=9;
   my $tmp_rise_3 = 0;
   until (equal($tmp_rise_2, $tmp_rise_3, 8) )   {

         my $d_sunrise_1 = $d + $tmp_rise_1/24.0;
         ($tmp_rise_2,undef) = sun_rise_set($d_sunrise_1, $lon, $lat,$altit,15.04107);
         $tmp_rise_1 = $tmp_rise_3;
         my $d_sunrise_2 = $d + $tmp_rise_2/24.0;
         ($tmp_rise_3,undef) = sun_rise_set($d_sunrise_2, $lon, $lat,$altit,15.04107);
       
         #print "tmp_rise2 is: $tmp_rise_2 tmp_rise_3 is:$tmp_rise_3\n";
         
   }

   
#######################################################################################
# end sunrise
###################################################################################


my $tmp_set_2=9;
my $tmp_set_3=0;

   until (equal($tmp_set_2, $tmp_set_3, 8) )   {

         my $d_sunset_1 = $d + $tmp_set_1/24.0;
         (undef,$tmp_set_2) = sun_rise_set($d_sunset_1, $lon, $lat,$altit,15.04107);
         $tmp_set_1 = $tmp_set_3;
         my $d_sunset_2 = $d + $tmp_set_2/24.0;
         (undef,$tmp_set_3) = sun_rise_set($d_sunset_2, $lon, $lat,$altit,15.04107);
        
         #print "tmp_set_1 is: $tmp_set_1 tmp_set_3 is:$tmp_set_3\n";
         
   }
   
   
   return convert_hour($tmp_rise_3,$tmp_set_3,$TZ, $isdst);

   }else{
   my $d = days_since_2000_Jan_0( $year, $month, $day ) + 0.5 - $lon / 360.0;
   my ($h1,$h2) = sun_rise_set($d, $lon, $lat,$altit,15.0);
   return convert_hour($h1,$h2,$TZ, $isdst);
   }
}


sub sun_rise_set {
    my ($d, $lon, $lat,$altit) =@_;
    #my ( $year, $month, $day, $lon, $lat, $TZ, $isdst, $alt ) = @_;
    #my $altit      = $alt || -0.833;
    #my $d = days_since_2000_Jan_0( $year, $month, $day ) + 0.5 - $lon / 360.0;

    my $sidtime = revolution( GMST0($d) + 180.0 + $lon );

    my ( $sRA, $sdec ) = sun_RA_dec($d);
    my $tsouth  = 12.0 - rev180( $sidtime - $sRA ) / 15.0;
    my $sradius = 0.2666 / $sRA;

    if ($upper_limb) {
        $altit -= $sradius;
    }

    # Compute the diurnal arc that the Sun traverses to reach 
    # the specified altitude altit: 

    my $cost =
      ( sind($altit) - sind($lat) * sind($sdec) ) /
      ( cosd($lat) * cosd($sdec) );

    my $t;
    if ( $cost >= 1.0 ) {
        carp "Sun never rises!!\n";
        $t = 0.0;    # Sun always below altit
    }
    elsif ( $cost <= -1.0 ) {
        carp "Sun never sets!!\n";
        $t = 12.0;    # Sun always above altit
    }
    else {
        $t = acosd($cost) / 15.0;    # The diurnal arc, hours
    }

    # Store rise and set times - in hours UT 

    my $hour_rise_ut = $tsouth - $t;
    my $hour_set_ut  = $tsouth + $t;
    return($hour_rise_ut, $hour_set_ut);
    #return convert_hour($hour_rise_ut,$hour_set_ut,$TZ, $isdst);
}

#########################################################################################################
sub GMST0 {
#
#
# FUNCTIONAL SEQUENCE for GMST0 
#
# _GIVEN
# Day number
#
# _THEN
#
# computes GMST0, the Greenwich Mean Sidereal Time  
# at 0h UT (i.e. the sidereal time at the Greenwhich meridian at  
# 0h UT).  GMST is then the sidereal time at Greenwich at any     
# time of the day..
# 
#
# _RETURN
#
# Sidtime
#
    my ($d) = @_;

    my $sidtim0 =
      revolution( ( 180.0 + 356.0470 + 282.9404 ) +
      ( 0.9856002585 + 4.70935E-5 ) * $d );
    return $sidtim0;

}

sub sunpos {

#
#
# FUNCTIONAL SEQUENCE for sunpos
#
# _GIVEN
#  day number
#
# _THEN
#
# Computes the Sun's ecliptic longitude and distance */
# at an instant given in d, number of days since     */
# 2000 Jan 0.0. 
# 
#
# _RETURN
#
# ecliptic longitude and distance
# ie. $True_solar_longitude, $Solar_distance
#
    my ($d) = @_;

    #                       Mean anomaly of the Sun 
    #                       Mean longitude of perihelion 
    #                         Note: Sun's mean longitude = M + w 
    #                       Eccentricity of Earth's orbit 
    #                       Eccentric anomaly 
    #                       x, y coordinates in orbit 
    #                       True anomaly 

    # Compute mean elements 
    my $Mean_anomaly_of_sun = revolution( 356.0470 + 0.9856002585 * $d );
    my $Mean_longitude_of_perihelion = 282.9404 + 4.70935E-5 * $d;
    my $Eccentricity_of_Earth_orbit  = 0.016709 - 1.151E-9 * $d;

    # Compute true longitude and radius vector 
    my $Eccentric_anomaly =
      $Mean_anomaly_of_sun + $Eccentricity_of_Earth_orbit * $RADEG *
      sind($Mean_anomaly_of_sun) *
      ( 1.0 + $Eccentricity_of_Earth_orbit * cosd($Mean_anomaly_of_sun) );

    my $x = cosd($Eccentric_anomaly) - $Eccentricity_of_Earth_orbit;

    my $y =
      sqrt( 1.0 - $Eccentricity_of_Earth_orbit * $Eccentricity_of_Earth_orbit )
      * sind($Eccentric_anomaly);

    my $Solar_distance = sqrt( $x * $x + $y * $y );    # Solar distance
    my $True_anomaly = atan2d( $y, $x );               # True anomaly

    my $True_solar_longitude =
      $True_anomaly + $Mean_longitude_of_perihelion;    # True solar longitude

    if ( $True_solar_longitude >= 360.0 ) {
        $True_solar_longitude -= 360.0;    # Make it 0..360 degrees
    }

    return ( $Solar_distance, $True_solar_longitude );
}

sub sun_RA_dec {

#
#
# FUNCTIONAL SEQUENCE for sun_RA_dec 
#
# _GIVEN
# day number, $r and $lon (from sunpos) 
#
# _THEN
#
# compute RA and dec
# 
#
# _RETURN
#
# Sun's Right Ascension (RA) and Declination (dec)
# 
#
    my ($d) = @_;

    # Compute Sun's ecliptical coordinates 
    my ( $r, $lon ) = sunpos($d);

    # Compute ecliptic rectangular coordinates (z=0) 
    my $x = $r * cosd($lon);
    my $y = $r * sind($lon);

    # Compute obliquity of ecliptic (inclination of Earth's axis) 
    my $obl_ecl = 23.4393 - 3.563E-7 * $d;

    # Convert to equatorial rectangular coordinates - x is unchanged 
    my $z = $y * sind($obl_ecl);
    $y = $y * cosd($obl_ecl);

    # Convert to spherical coordinates 
    my $RA  = atan2d( $y, $x );
    my $dec = atan2d( $z, sqrt( $x * $x + $y * $y ) );

    return ( $RA, $dec );

}    # sun_RA_dec

sub days_since_2000_Jan_0 {

#
#
# FUNCTIONAL SEQUENCE for days_since_2000_Jan_0 
#
# _GIVEN
# year, month, day
#
# _THEN
#
# process the year month and day (counted in days)
# Day 0.0 is at Jan 1 2000 0.0 UT
# Note that ALL divisions here should be INTEGER divisions
#
# _RETURN
#
# day number
#
    use integer;
    my ( $year, $month, $day ) = @_;

    my $d =
      ( 367 * ($year) -
      int( ( 7 * ( ($year) + ( ( ($month) + 9 ) / 12 ) ) ) / 4 ) +
      int( ( 275 * ($month) ) / 9 ) + ($day) - 730530 );

    return $d;

}

sub sind {
    sin( ( $_[0] ) * $DEGRAD );
}

sub cosd {
    cos( ( $_[0] ) * $DEGRAD );
}

sub tand {
    tan( ( $_[0] ) * $DEGRAD );
}

sub atand {
    ( $RADEG * atan( $_[0] ) );
}

sub asind {
    ( $RADEG * asin( $_[0] ) );
}

sub acosd {
    ( $RADEG * acos( $_[0] ) );
}

sub atan2d {
    ( $RADEG * atan2( $_[0], $_[1] ) );
}

sub revolution {
#
#
# FUNCTIONAL SEQUENCE for revolution
#
# _GIVEN
# any angle
#
# _THEN
#
# reduces any angle to within the first revolution 
# by subtracting or adding even multiples of 360.0
# 
#
# _RETURN
#
# the value of the input is >= 0.0 and < 360.0
#

    my $x = $_[0];
    return ( $x - 360.0 * floor( $x * $INV360 ) );
}

sub rev180 {
#
#
# FUNCTIONAL SEQUENCE for rev180
#
# _GIVEN
# 
# any angle
#
# _THEN
#
# Reduce input to within +180..+180 degrees
# 
#
# _RETURN
#
# angle that was reduced
#
    my ($x) = @_;
    
    return ( $x - 360.0 * floor( $x * $INV360 + 0.5 ) );
}

sub equal {
    my ($A, $B, $dp) = @_;

    return sprintf("%.${dp}g", $A) eq sprintf("%.${dp}g", $B);
  }


sub convert_hour   {

#
#
# FUNCTIONAL SEQUENCE for convert_hour 
#
# _GIVEN
# Hour_rise, Hour_set, Time zone offset, DST setting
# hours are in UT
#
# _THEN
#
# convert to local time
# 
#
# _RETURN
#
# hour:min rise and set 
#

  my ($hour_rise_ut, $hour_set_ut, $TZ, $isdst) = @_;

  my $rise_local = $hour_rise_ut + $TZ;
  my $set_local = $hour_set_ut + $TZ;
  if ($isdst) {
    $rise_local +=1;
    $set_local +=1;
  }

  # Rise and set should be between 0 and 24;
  if ($rise_local<0) {
    $rise_local+=24;
  } elsif ($rise_local>24) {
    $rise_local -=24;
  }
  if ($set_local<0) {
    $set_local+=24;
  } elsif ($set_local>24) {
    $set_local -=24;
  }

  my $hour_rise =  int ($rise_local);
  my $hour_set  =  int($set_local);

  my $min_rise  = floor(($rise_local-$hour_rise)*60+0.5);
  my $min_set   = floor(($set_local-$hour_set)*60+0.5);

  if ($min_rise>=60) {
    $min_rise -=60;
    $hour_rise+=1;
    $hour_rise-=24 if ($hour_rise>=24);
  }
  if ($min_set>=60) {
    $min_set -=60;
    $hour_set+=1;
    $hour_set-=24 if ($hour_set>=24);
  }

  if ( $min_rise < 10 ) {
    $min_rise = sprintf( "%02d", $min_rise );
  }
  if ( $min_set < 10 ) {
    $min_set = sprintf( "%02d", $min_set );
  }
  $hour_rise = sprintf( "%02d", $hour_rise );
  $hour_set  = sprintf( "%02d", $hour_set );
  return ( "$hour_rise:$min_rise", "$hour_set:$min_set" );

}

=over

=item B<sun_rise>

=over

=item C<$sun_rise = sun_rise( longitude, latitude );>

=item C<$sun_rise = sun_rise( longitude, latitude, ALT );>

=item C<$sun_rise = sun_rise( longitude, latitude, ALT, day_offset );>

Returns the sun rise time for the given location.  The first form
uses today's date (from DateTime) and the default altitude.  The second
form adds specifying a custom altitude.  The third form allows for specifying
an integer day offset from today, either positive or negative.

=item I<For Example>

 $sunrise = sun_rise( -105.181, 41.324 );
 $sunrise = sun_rise( -105.181, 41.324, -15 );
 $sunrise = sun_rise( -105.181, 41.324, -12, +3 );
 $sunrise = sun_rise( -105.181, 41.324, undef, -12);

=back

=back

=cut

sub sun_rise
   {
   my $longitude = shift;
   my $latitude = shift;
   my $alt = shift || -0.833;
   my $offset = int( shift || 0 );

   my $today = DateTime->today->set_time_zone( 'local' );
   $today->add( days => $offset );

   my( $sun_rise, undef ) = sunrise( $today->year, $today->mon, $today->mday,
                                     $longitude, $latitude,
                                     ( $today->offset / 3600 ),
                                     #
                                     # DST is always 0 because DateTime
                                     # currently (v 0.16) adds one to the
                                     # offset during DST hours
                                     0,
                                     $alt );
   return $sun_rise;
   }

=over

=item B<sun_set>

=over

=item C<$sun_set = sun_set( longitude, latitude );>

=item C<$sun_set = sun_set( longitude, latitude, ALT );>

=item C<$sun_set = sun_set( longitude, latitude, ALT, day_offset );>

Returns the sun set time for the given location.  The first form
uses today's date (from DateTime) and the default altitude.  The second
form adds specifying a custom altitude.  The third form allows for specifying
an integer day offset from today, either positive or negative.

=item I<For Example>

 $sunrise = sun_set( -105.181, 41.324 );
 $sunrise = sun_set( -105.181, 41.324, -15 );
 $sunrise = sun_set( -105.181, 41.324, -12, +3 );
 $sunrise = sun_set( -105.181, 41.324, undef, -12);

=back

=back

=cut

sub sun_set
   {
   my $longitude = shift;
   my $latitude = shift;
   my $alt = shift || -0.833;
   my $offset = int( shift || 0 );

   my $today = DateTime->today->set_time_zone( 'local' );
   $today->add( days => $offset );

   my( undef, $sun_set ) = sunrise( $today->year, $today->mon, $today->mday,
                                    $longitude, $latitude,
                                    ( $today->offset / 3600 ),
                                    #
                                    # DST is always 0 because DateTime
                                    # currently (v 0.16) adds one to the
                                    # offset during DST hours
                                    0,
                                    $alt );
   return $sun_set;
   }

sub DEFAULT      () { -0.833 }
sub CIVIL        () { - 6 }
sub NAUTICAL     () { -12 }
sub AMATEUR      () { -15 }
sub ASTRONOMICAL () { -18 }

=head1 AUTHOR

Ron Hill
rkhill@firstlight.net

=head1 SPECIAL THANKS

Robert Creager [Astro-Sunrise@LogicalChaos.org]
For providing help with converting Paul's C code to perl
For providing code for sun_rise, sun_set sub's
Also adding options for different altitudes.

Joshua Hoblitt [jhoblitt@ifa.hawaii.edu]
For providing the patch to convert to DateTime

Chris Phillips for providing patch for conversion to 
local time.

Brian D Foy for providing patch for constants :)

=head1 CREDITS


=item  Paul Schlyer, Stockholm, Sweden 

for his excellent web page on the subject.

=item Rich Bowen (rbowen@rbowen.com)

for suggestions

=item Adrian Blockley [adrian.blockley@environ.wa.gov.au]

for finding a bug in the conversion to local time

=back

Lightly verified against http://aa.usno.navy.mil/data/docs/RS_OneYear.html

=head1 COPYRIGHT and LICENSE

Here is the copyright information provided by Paul Schlyer:

Written as DAYLEN.C, 1989-08-16

Modified to SUNRISET.C, 1992-12-01

(c) Paul Schlyter, 1989, 1992

Released to the public domain by Paul Schlyter, December 1992

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=head1 BUGS

=head1 SEE ALSO

perl(1).

=cut

1;
