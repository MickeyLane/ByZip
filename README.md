# ByZip

I’d been keeping a pretty close eye on the pandemic data published by the State of Florida’s various agencies and while trying to find out what the real risk was to me in my little zip code, it occurred to me that while they reported how many people got sick with COVID-19, they never reported how many people got better. I had no idea how many sick people there were around me.
Someone who was reported as positive on July 4th was surely better by now.
I decided to write a simulator using the published cumulative positive case data that would estimate how many people were still sick, dead or cured and no longer a threat.

The Data
--------

I managed to find comma separated value (.csv) files for each day. Each file contains a row for each zip code and columns for ‘zip code’ and ‘number of cases’ (along with a lot of information I’m not interested in).
The simulator scans the files and, searching by zip code, picks out number of cases. If today’s number of cases is one more than yesterday’s number of cases, then a new case has been discovered. The simulator makes a list of these new cases.
Each case in the list has a number of parameters:
    Start date (determined by when the case was discovered.)
    End date (determined below)
    Disposition (aka what happened to this case? Did they die?)
    Still sick?
    Cured?

Prior to the simulation process, a random number picker is used to set some of the parameters. The percentage of fatal cases is estimated (somewhere between 1 and 3.5 percent) and the duration of the sickness is estimated (somewhere between 9 and 19 days) in the non-fatal cases.

Simulation
----------

The program picks a start date (usually the beginning of the input data) and the end date (today) for the simulation. The simulation process is to touch each case in the list and, as the dates pass, one by one, the note the case status changes. Lists are kept noting the number of cured, still sick and dead on each day.

The simulation is run three times and the random number generator is used prior to each ‘run’ to pick new numbers.

When all is done, the saved lists are plotted.

Adjusting the numbers
---------------------

The program (actually a perl script) uses command line arguments to set the various simulation values. Enter the command help (“perl ByZip.pl help”) to get a display of the current command line options.

Some of the options are for debugging and are defaulted ‘off’.


