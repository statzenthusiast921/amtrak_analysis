
#Recipes ----
tic()
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
  rec_ld_list[[i]] <- recipe(Rides ~ ., data = df_ld_nest$data_train[[i]])|>
    step_date(year_month, features = c("month", "year"))       
  
  
} 

for (i in 1:num_of_nc_stations){
  rec_nc_list[[i]] <- recipe(Rides ~ ., data = df_nc_nest$data_train[[i]])|>
    step_date(year_month, features = c("month", "year"))
  
} 

for (i in 1:num_of_ss_stations){
  rec_ss_list[[i]] <- recipe(Rides ~ ., data = df_ss_nest$data_train[[i]])|>
    step_date(year_month, features = c("month", "year"))
} 

for (i in 1:num_of_ot_stations){
  rec_ot_list[[i]] <- recipe(Rides ~ ., data = df_ot_nest$data_train[[i]])|>
    step_date(year_month, features = c("month", "year"))
  
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


toc()