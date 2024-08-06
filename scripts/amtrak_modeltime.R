#Modeltime Framework for Amtrak Project
#Date: 2024-08-04
#----------------------#

#Load libraries ----
message('Loading packages...')
suppressPackageStartupMessages({
  library(readxl)
  library(tidyverse)
  library(tidymodels)
  library(modeltime)
  library(timetk)
  library(lubridate)
  library(timeDate)
  library(poissonreg)
  library(furrr)
  library(tictoc)
  library(tidyr)
  library(workflows)
})

#Load data ----
message('Loading data...')
df <- read_csv("/Users/jonzimmerman/Desktop/Data Projects/Amtrak/data/amtrak_df_v2.csv")

#Make sure each time series is complete - impute 0 for missing ----
message('Prepping the data...')

df <- df |>
  mutate(
    Rides = round(Rides, 0)
  )


df <- df |>
  group_by(station_name) |>
  pad_by_time(
    .date_var = year_month,
    .by = 'auto',
    .pad_value = 0,
    .start_date = min(df$year_month),
    .end_date = max(df$year_month)
  )

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

df_ld_nest <- df_ld_nest |>
  mutate(splits = map(data_full, .f = function(x) {
    time_series_split(x, assess = 18, cumulative = TRUE)
  }))

df_nc_nest <- df_nc_nest |>
  mutate(splits = map(data_full, .f = function(x) {
    time_series_split(x, assess = 18, cumulative = TRUE)
  }))

df_ss_nest <- df_ss_nest |>
  mutate(splits = map(data_full, .f = function(x) {
    time_series_split(x, assess = 18, cumulative = TRUE)
  }))

df_ot_nest <- df_ot_nest |>
  mutate(splits = map(data_full, .f = function(x) {
    time_series_split(x, assess = 18, cumulative = TRUE)
  }))

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

#Recipes ----
message('Define recipes (ie: model params)...')

rec_ld_list <- list()
rec_nc_list <- list()
rec_ss_list <- list()
rec_ot_list <- list()


num_of_ld_stations <- dim(df_ld_nest)[1]
num_of_nc_stations <- dim(df_nc_nest)[1]
num_of_ss_stations <- dim(df_ss_nest)[1]
num_of_ot_stations <- dim(df_ot_nest)[1]

for (i in 1:num_of_ld_stations){
  rec_ld_list[[i]] <- recipe(Rides ~ ., data = df_ld_nest$data_train[[i]])
} 

for (i in 1:num_of_nc_stations){
  rec_nc_list[[i]] <- recipe(Rides ~ ., data = df_nc_nest$data_train[[i]])
} 

for (i in 1:num_of_ss_stations){
  rec_ss_list[[i]] <- recipe(Rides ~ ., data = df_ss_nest$data_train[[i]])
} 

for (i in 1:num_of_ot_stations){
  rec_ot_list[[i]] <- recipe(Rides ~ ., data = df_ot_nest$data_train[[i]])
} 


#Workflows ----
message('Assign recipes to workflow...')


wfl_glm <- workflow() |>
  add_model(
    poisson_reg() |>
      set_engine(engine = 'glm')
  )


wfl_ld_list <-list()
wfl_nc_list <-list()
wfl_ss_list <-list()
wfl_ot_list <-list()


for (i in 1:num_of_ld_stations){
  wfl_ld_list[[i]] <- wfl_glm |>
    add_recipe(rec_ld_list[[i]]) |>
    add_case_weights(case_wts)
}

for (i in 1:num_of_nc_stations){
  wfl_nc_list[[i]] <- wfl_glm |>
    add_recipe(rec_nc_list[[i]]) |>
    add_case_weights(case_wts)
}

for (i in 1:num_of_ss_stations){
  wfl_ss_list[[i]] <- wfl_glm |>
    add_recipe(rec_ss_list[[i]]) |>
    add_case_weights(case_wts)
}

for (i in 1:num_of_ot_stations){
  wfl_ot_list[[i]] <- wfl_glm |>
    add_recipe(rec_ot_list[[i]]) |>
    add_case_weights(case_wts)
}

message('Assign workflows to groups in nested df...')

df_ld_nest$.wfl <- vector('list', nrow(df_ld_nest))
for(i in 1:num_of_ld_stations){
  df_ld_nest$.wfl[i] <- list(wfl_ld_list[[i]])
} 

df_nc_nest$.wfl <- vector('list', nrow(df_nc_nest))
for(i in 1:num_of_nc_stations){
  df_nc_nest$.wfl[i] <- list(wfl_nc_list[[i]])
} 

df_ss_nest$.wfl <- vector('list', nrow(df_ss_nest))
for(i in 1:num_of_ss_stations){
  df_ss_nest$.wfl[i] <- list(wfl_ss_list[[i]])
} 

df_ot_nest$.wfl <- vector('list', nrow(df_ot_nest))
for(i in 1:num_of_ot_stations){
  df_ot_nest$.wfl[i] <- list(wfl_ot_list[[i]])
} 



#Fit models
message('Fit workflows using training data...')

df_ld_nest <- df_ld_nest |>
  mutate(.fit = map2(.x = .wfl,
                     .y = data_train,
                     .f = ~fit(.x, .y)))

df_nc_nest <- df_nc_nest |>
  mutate(.fit = map2(.x = .wfl,
                     .y = data_train,
                     .f = ~fit(.x, .y)))

df_ss_nest <- df_ss_nest |>
  mutate(.fit = map2(.x = .wfl,
                     .y = data_train,
                     .f = ~fit(.x, .y)))

df_ot_nest <- df_ot_nest |>
  mutate(.fit = map2(.x = .wfl,
                     .y = data_train,
                     .f = ~fit(.x, .y)))

#Calibrate models
message('Calibrate models using test data...')

df_ld_nest <- df_ld_nest |>
  mutate(.calib = future_map2(.x = .fit,
                              .y = data_calib,
                              .f = ~modeltime_calibrate(modeltime_table(.x),new_data=.y),
                              .options = furrr_options(packages = c("timetk","purrr"))))


df_nc_nest <- df_nc_nest |>
  mutate(.calib = future_map2(.x = .fit,
                              .y = data_calib,
                              .f = ~modeltime_calibrate(modeltime_table(.x),new_data=.y),
                              .options = furrr_options(packages = c("timetk","purrr"))))



df_ss_nest <- df_ss_nest |>
  mutate(.calib = future_map2(.x = .fit,
                              .y = data_calib,
                              .f = ~modeltime_calibrate(modeltime_table(.x),new_data=.y),
                              .options = furrr_options(packages = c("timetk","purrr"))))



df_ot_nest <- df_ot_nest |>
  mutate(.calib = future_map2(.x = .fit,
                              .y = data_calib,
                              .f = ~modeltime_calibrate(modeltime_table(.x),new_data=.y),
                              .options = furrr_options(packages = c("timetk","purrr"))))


#Refit models
message('Refit models using all data...')

df_ld_nest <- df_ld_nest |>
  mutate(.refit = future_map2(.x = .calib,
                              .y = data_full,
                              .f = ~modeltime_refit(.x,data=.y)))

df_nc_nest <- df_nc_nest |>
  mutate(.refit = future_map2(.x = .calib,
                              .y = data_full,
                              .f = ~modeltime_refit(.x,data=.y)))
df_ss_nest <- df_ss_nest |>
  mutate(.refit = future_map2(.x = .calib,
                              .y = data_full,
                              .f = ~modeltime_refit(.x,data=.y)))
df_ot_nest <- df_ot_nest |>
  mutate(.refit = future_map2(.x = .calib,
                              .y = data_full,
                              .f = ~modeltime_refit(.x,data=.y)))

#Generate forecasts
message('Generate forecasts...')

df_ld_nest <- df_ld_nest |>
  mutate(
    .fc = future_pmap(
      .l = list(.refit,data_future,data_full),
      .f = ~modeltime_forecast(
        object = ..1,
        new_data = ..2,
        actual_data = ..3,
        keep_data = FALSE
        ),.options = furrr_options(packages = c("timetk","purrr"))
  )
)

df_nc_nest <- df_nc_nest |>
  mutate(
    .fc = future_pmap(
      .l = list(.refit,data_future,data_full),
      .f = ~modeltime_forecast(
        object = ..1,
        new_data = ..2,
        actual_data = ..3,
        keep_data = FALSE
      ),.options = furrr_options(packages = c("timetk","purrr"))
    )
  )

df_ss_nest <- df_ss_nest |>
  mutate(
    .fc = future_pmap(
      .l = list(.refit,data_future,data_full),
      .f = ~modeltime_forecast(
        object = ..1,
        new_data = ..2,
        actual_data = ..3,
        keep_data = FALSE
      ),.options = furrr_options(packages = c("timetk","purrr"))
    )
  )

df_ot_nest <- df_ot_nest |>
  mutate(
    .fc = future_pmap(
      .l = list(.refit,data_future,data_full),
      .f = ~modeltime_forecast(
        object = ..1,
        new_data = ..2,
        actual_data = ..3,
        keep_data = FALSE
      ),.options = furrr_options(packages = c("timetk","purrr"))
    )
  )


message('Testing out methods for looking at residuals...')
# Residuals for Long Distance

message('Make residuals dataset by pulling out residuals')
ld_resids_list <-list()

for (i in 1:num_of_ld_stations){
  ld_resids_list[[i]] <- df_ld_nest[[10]][[i]][[5]][[1]] |>
    mutate(station_name = df_ld_nest$station_name[[i]])
}

ld_resids_df = bind_rows(ld_resids_list)

ggplot(ld_resids_df |> filter(station_name == "Elkhart, IN"), aes(x = year_month , y = .residuals)) +
  geom_point() + geom_line()

message('Make predictions dataset by pulling out predictions')

ld_preds_list <-list()

for (i in 1:num_of_ld_stations){
  ld_preds_list[[i]] <- df_ld_nest[[11]][[i]] |>
    mutate(station_name = df_ld_nest$station_name[[i]])
}

ld_preds_df = bind_rows(ld_preds_list)
