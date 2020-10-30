# ByZip

I’d been keeping a pretty close eye on the pandemic data published by the State of Florida’s various agencies and while trying to find out what the real risk was to me in my little zip code, it occurred to me that while they reported how many people got sick with COVID-19, they never reported how many people got better.

I had no idea how many sick people there were around me. Someone who was reported as positive on July 4th was surely better by now.

I decided to write a simulator using the published cumulative positive case data that would estimate how many people were still sick, dead or cured and no longer a threat. This is that
simulator.

## The data

This project contains data for the following

    Florida
    New York (some zips, not all)
    Pennsylvania
    North Carolina (currently broken due to data format change early October)
    Maryland

I managed to find comma separated value (.csv) files for each day. Each file contains a row for each zip code and columns for ‘zip code’ and ‘number of cases’ (along with a lot of information I’m not interested in).

The simulator scans the files and, searching by 'zip code', picks out 'number of cases'. If today’s number of cases is one more than yesterday’s number of cases, then a new case has been discovered. The simulator makes a list of these new cases.

Each case in the list has a number of parameters:
    Start date (determined by when the case was discovered.)
    End date (determined below)
    Disposition (aka what happened to this case? Did they die?)
    Still sick?
    Cured?
    (more)

Prior to the simulation process, a random number picker is used to set some of the parameters. The percentage of fatal cases is estimated (somewhere between 1 and 3.5 percent) and the duration of the sickness is estimated (somewhere between 9 and 19 days) in the non-fatal cases.

## Simulation

The program picks a start date (usually the beginning of the available data) and the end date (today) for the simulation. The simulation process is to touch each case in the list for each date in the simulation and, as the dates pass, one by one, the note the case status changes. Lists are kept noting the number of cured, still sick and dead for each day.

The simulation is run three times and the random number generator is used prior to each ‘run’ to pick new numbers.

When all is done, the saved lists are plotted.

## Adjusting the numbers

The program (actually a perl script) uses command line arguments to set the various simulation values. Enter the command help (“perl ByZip.pl help”) to get a display of the current command line options.

Some of the options are for debugging and are defaulted ‘off’.

## Mortality rates

[Our World in Data (OWID)] (https://ourworldindata.org/) publishes COVID-19 mortality rates for each day and each country. ByZip strips out the USA data and makes an array of mortality rates for the entire US. The simulator defaults to using this array (it changes day-by-day) but it can use a fixed rate entered from the keyboard. The day-by-day changes are pretty dramatic over time so it's suggested that they be used instrad of a fixed value.

# Error issues

## Data

It's been noted by several sources that generating new case data from daily reported totals is subject to error because the report date probably doesn't match the real case date or the reporting pipeline may not function on a daily basis. Making the assumption that the errors are somewhat consistant, it should not pose a problem over the time spans displayed. Anomolies will show up in the graphs if there are problems.

## Simulations

If the data for a particular zip starts out high and remains flat for some time, the graph display will show an almost straight line decline to some lower value. This is because the simulator has no way of knowing how many of the cases on the 1st day of reporting are actually still sick. Still working on resolving this issue.

# Credits

## Genreal data

[United States Zip Codes] (https://www.unitedstateszipcodes.org/zip-code-database/) makes
available a complete database of zip codes by state. Provided free to private, non-profit use like ByZip.
This isn't actually being used yet. The intent is to equate any input zip code to a state but since there are
so few states being reported at the moment, the lookup is just hard coded.

[Our World in Data] (https://covid.ourworldindata.org/data/owid-covid-data.csv) provides a daily database
that includes the death rate around the globe. B yZip strips out the US portion of it and computes a daily
mortality rate for the entire country.