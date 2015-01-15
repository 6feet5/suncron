# SunCron
Generate cron entries from rules based on sunset and/or sunrise

SunCron is a perl program that will generate cron rules based on the time when sun sets and/or rises. I made it to control the lighting in my apartment together with the nexa remote control I made. You can however run any command that doesn’t require user input.

## Requirements:
 - Perl
 - Astro::Sunrise module (included in this package)
 - DateTime module (available from CPAN)

## Installation:
 - Run 'make install' as root.
 - Edit /etc/default/suncron
 - Verify that daily cron jobs execute sometime between 00:00 and 01:00 or
   you'll risk missing the sunset. In this case you'll be a day late, that
   is, the sunrise and sunset times will be for previous day.

## Usage:
The idea behind this project is to execute programs at sunset or sunrise.
Instead of running an entire program to wait for sunset or sunrise, this 
program is supposed to execute at midnight and calculate todays sunrise and
sunset times. It will then parse a configuration file with a set of rules 
and update the cron file with the new values.

The configuration file is found in '/etc/default/suncron.conf'.
It has a Location section and a rule section. Each rule consists of four 
parts:
  - a condition<br/>
    The condition is a clear text formula describing the condition, 
    eg. 'sunset < 17:00' to test if sun sets before 17:00.
    
  - a "true" and a "false" statement<br/>
    these statements is the time to use if condition is true/false,
    eg. 'sunrise + 03:30' for three and a half hour after sunrise.
    Or you can leave it empty to ignore it.

  - a cron part<br/>
    the cron part is a cron line without the minute and hour field,
    eg. '* * [1-4] root /path/to/command arg'

The resulting cron data is written to /etc/cron.d/suncron (unless you
redirect it with the command line switch, see 'suncron --help').
Conditions that evaluate to a true/false state that is empty will NOT
be written to the file.

## Known issues:
The program makes no attempt at parsing the cron rule, so rules that
have a cron part that is to execute at, say, every thursday will be
written every day. This does not mean it will be executed every day, 
since cron will handle this correctly. It's just that suncron makes
an unnecessary line in the cron file. I'm lazy, so you'll have to 
accept this ;-)

I have also received a report about a "feature" where suncron "change"
sunset or sunrise based on previous calculations. This is of course a bug and I'm working on it now, but progress is slow.
