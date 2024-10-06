# Amtrak Analysis


### Description

The purpose of this project was to:
- build a transferable approach to forecasting many statistical models at once 
- practice splitting out yearly data to a monthly grain


### Data

The data used for this analysis was scraped from [here](https://www.railpassengers.org/resources/ridership-statistics/).

### Application
- [Click here to view app](https://amtrak-fc-analysis-jz-app.onrender.com/)

### Challenges

- The data was only available at a yearly grain making a forecast catching seasonality difficult.  To fix this issue, I split the data out to a monthly grain including different ramp up and down rates depending on the time of year.
- Stations were often included in multiple cross-country routes making comparisons a little difficult.  If I were to compare routes, I didn't want any one station counting more than once.  Thus, for stations that were associated with multiple routes, I assigned them to a 'parent route' that had the largest ridership overall for any of the associated routes.

