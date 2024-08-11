#Modeltime Framework for Amtrak Project
#Date: 2024-08-04
#----------------------#

#Load libraries ----
message('Loading packages...')
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyverse)
  library(tidymodels)
  library(modeltime)
  library(timetk)
  library(lubridate)
  library(poissonreg)
  library(workflows)
  library(tictoc)
})

tic()

#Load data ----
message('Loading data...')
path <-"/Users/jonzimmerman/Desktop/Data Projects/Amtrak/data/"
df <- suppressMessages(read_csv(paste0(path,"amtrak_df_v2.csv")))

#Make sure each time series is complete - impute 0 for missing ----
message('Prepping the data...')

df <- df |>
  mutate(
    Rides = round(Rides, 0)
  )


df <- suppressMessages(df |>
  group_by(station_name) |>
  pad_by_time(
    .date_var = year_month,
    .by = 'auto',
    .pad_value = 0,
    .start_date = min(df$year_month),
    .end_date = max(df$year_month)
  ))

# #Create case weights - more recent month gets more weight ----
df <- df |>
  group_by(station_name) |>
  mutate(dec_month = lubridate::decimal_date(year_month),
         case_wts = exp(max(dec_month) - dec_month)) |>
  group_by(station_name, year_month) |>
  mutate(case_wts = max(case_wts)) |>
  ungroup() |>
  mutate(case_wts = importance_weights(case_wts)) |>
  select(-dec_month)

#Extend each time series into the future ----
df_ext <- df |>
  group_by(station_name) |>
  future_frame(
    .date_var = year_month,
    .length_out = '24 months',
    .bind_data = TRUE
  )

message('Make 4 partitions of data by business line...')
df_ext_long_dist <- df_ext |>
  tidyr::fill(c(business_line), .direction = 'downup') |>
  filter(business_line == "Long Distance") |>
  select(station_name, year_month, Rides, case_wts)


df_ext_ne_corr <- df_ext |>
  tidyr::fill(c(business_line), .direction = 'downup') |>
  filter(business_line == "Northeast Corridor") |>
  select(station_name, year_month, Rides, case_wts)

df_ext_state_sup <- df_ext |>
  tidyr::fill(c(business_line), .direction = 'downup') |>
  filter(business_line == "State Supported") |>
  select(station_name, year_month, Rides, case_wts)

df_ext_other <- df_ext |>
  tidyr::fill(c(business_line), .direction = 'downup') |>
  filter(is.na(business_line) == TRUE) |>
  select(station_name, year_month, Rides, case_wts)


#Split into full training data and future data that will be forecasted ----
message('Make 2 partitions of data (full, future)...')

#--------- 1/4: Long Distance
df_ld_full_data <- df_ext_long_dist |> 
  drop_na() |>
  tidyr::nest(data_full = c(-station_name))

df_ld_future_data <- df_ext_long_dist |>
  filter(is.na(Rides)==TRUE) |>
  tidyr::nest(data_future = c(-station_name))

#--------- 2/4: Northeast Corridor
df_nc_full_data <- df_ext_ne_corr |> 
  drop_na() |>
  tidyr::nest(data_full = c(-station_name))

df_nc_future_data <- df_ext_ne_corr |>
  filter(is.na(Rides)==TRUE) |>
  tidyr::nest(data_future = c(-station_name))

#--------- 3/4: State Supported
df_ss_full_data <- df_ext_state_sup |> 
  drop_na() |>
  tidyr::nest(data_full = c(-station_name))

df_ss_future_data <- df_ext_state_sup |>
  filter(is.na(Rides)==TRUE) |>
  tidyr::nest(data_future = c(-station_name))

#--------- 4/4: Other
df_ot_full_data <- df_ext_other |> 
  drop_na() |>
  tidyr::nest(data_full = c(-station_name))

df_ot_future_data <- df_ext_other |>
  filter(is.na(Rides)==TRUE) |>
  tidyr::nest(data_future = c(-station_name))


#Join data all together ----
message('Join full and future data together in nested df...')

df_ld_nest <- inner_join(
  df_ld_full_data,
  df_ld_future_data,
  by = 'station_name'
)

df_nc_nest <- inner_join(
  df_nc_full_data,
  df_nc_future_data,
  by = 'station_name'
)

df_ss_nest <- inner_join(
  df_ss_full_data,
  df_ss_future_data,
  by = 'station_name'
)

df_ot_nest <- inner_join(
  df_ot_full_data,
  df_ot_future_data,
  by = 'station_name'
)

#Create training and calibration (test) data ----
message('Make 2 partitions of data (train, test)...')

df_ld_nest <- suppressMessages(df_ld_nest |>
  mutate(splits = map(data_full, .f = function(x) {
    time_series_split(x, assess = 18, cumulative = TRUE)
  })))

df_nc_nest <- suppressMessages(df_nc_nest |>
  mutate(splits = map(data_full, .f = function(x) {
    time_series_split(x, assess = 18, cumulative = TRUE)
  })))

df_ss_nest <- suppressMessages(df_ss_nest |>
  mutate(splits = map(data_full, .f = function(x) {
    time_series_split(x, assess = 18, cumulative = TRUE)
  })))

df_ot_nest <- suppressMessages(df_ot_nest |>
  mutate(splits = map(data_full, .f = function(x) {
    time_series_split(x, assess = 18, cumulative = TRUE)
  })))

message('Slice out training and calibration datasets...')
df_ld_nest <- df_ld_nest |>
  mutate(data_train = map(.x = data_full, .f = ~slice_head(.x, n = -18)),
         data_calib = map(.x = data_full, .f = ~slice_tail(.x, n = 18))) |>
  relocate(data_train,.after=data_full) |>
  relocate(data_calib,.after=data_train)

df_nc_nest <- df_nc_nest |>
  mutate(data_train = map(.x = data_full, .f = ~slice_head(.x, n = -18)),
         data_calib = map(.x = data_full, .f = ~slice_tail(.x, n = 18))) |>
  relocate(data_train,.after=data_full) |>
  relocate(data_calib,.after=data_train)


df_ss_nest <- df_ss_nest |>
  mutate(data_train = map(.x = data_full, .f = ~slice_head(.x, n = -18)),
         data_calib = map(.x = data_full, .f = ~slice_tail(.x, n = 18))) |>
  relocate(data_train,.after=data_full) |>
  relocate(data_calib,.after=data_train)


df_ot_nest <- df_ot_nest |>
  mutate(data_train = map(.x = data_full, .f = ~slice_head(.x, n = -18)),
         data_calib = map(.x = data_full, .f = ~slice_tail(.x, n = 18))) |>
  relocate(data_train,.after=data_full) |>
  relocate(data_calib,.after=data_train)

toc()