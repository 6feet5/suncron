package ConfigFile;

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

use strict;
use warnings;

sub new {
    my ($package, $file) = @_;
    my ($latitude, $longitude, $timezone);
    my $section = "none";
    my @rules = ();

    die('Error: Need a filename to configuration file') if not defined($file);

    my $conf;
    my $result = open($conf, "<", $file);

    if($result) {
        while(<$conf>) {
            if(!/^\s*#/ && !/^\s*$/) {
                if(/^\s*\[(\w*)\]\s*/) {
                    $section = lc $1;
                } else {
                    if($section eq "location") {
                        (my $key, my $value) = split(/=/, $_, 2);
                        $value =~ s/^\s*//;
                        $value =~ s/\s*$//;
                        $key =~ s/^\s*//;
                        $key =~ s/\s*$//;
                        if(lc $key eq "longitude") {
                            $longitude = $value;
                        } elsif(lc $key eq "latitude") {
                            $latitude = $value;
                        } elsif(lc $key eq "timezone") {
                            $timezone = $value;
                        }
                    } elsif (lc $section eq "rules") {
                        # do the magix
                        s/^\s*//;
                        s/\s*$//;
                        push @rules, ($_);
                    } else {
                        die("Unknown section: $section\n");
                    }
                }
            }
        }
    } else {
        die("Couldn't open configuration file: '$file'");
    }

    my $self = { _file => $file, _latitude => $latitude, _longitude => $longitude, _rules => \@rules, _timezone => $timezone };

    bless($self, $package);

    return $self;
}

sub latitude {
    my $self = shift;

    return $self->{_latitude};
}

sub longitude {
    my $self = shift;

    return $self->{_longitude};
}

sub timezone {
    my $self = shift;

    return $self->{_timezone};
}

sub get_rules {
    my $self = shift;

    return $self->{_rules};
}

1;
__END__
