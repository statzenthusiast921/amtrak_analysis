
#Fit models
message('Fit workflows using training data...')
tic()

df_ld_nest$.fit <- vector("list", nrow(df_ld_nest))
for (i in seq_len(nrow(df_ld_nest))) {
  df_ld_nest$.fit[[i]] <- fit(df_ld_nest$.wfl[[i]], df_ld_nest$data_train[[i]])
}

df_nc_nest$.fit <- vector("list", nrow(df_nc_nest))
for (i in seq_len(nrow(df_nc_nest))) {
  df_nc_nest$.fit[[i]] <- fit(df_nc_nest$.wfl[[i]], df_nc_nest$data_train[[i]])
}

df_ss_nest$.fit <- vector("list", nrow(df_ss_nest))
for (i in seq_len(nrow(df_ss_nest))) {
  df_ss_nest$.fit[[i]] <- fit(df_ss_nest$.wfl[[i]], df_ss_nest$data_train[[i]])
}

df_ot_nest$.fit <- vector("list", nrow(df_ot_nest))
for (i in seq_len(nrow(df_ot_nest))) {
  df_ot_nest$.fit[[i]] <- fit(df_ot_nest$.wfl[[i]], df_ot_nest$data_train[[i]])
}


#Calibrate models
message('Calibrate models using test data...')

df_ld_nest$.calib <- vector("list", nrow(df_ld_nest))
df_nc_nest$.calib <- vector("list", nrow(df_nc_nest))
df_ss_nest$.calib <- vector("list", nrow(df_ss_nest))
df_ot_nest$.calib <- vector("list", nrow(df_ot_nest))

# For Long Distance
for (i in seq_len(nrow(df_ld_nest))) {
  model_tbl <- modeltime_table(df_ld_nest$.fit[[i]])
  df_ld_nest$.calib[[i]] <- modeltime_calibrate(model_tbl, new_data = df_ld_nest$data_calib[[i]])
}

for (i in seq_len(nrow(df_nc_nest))) {
  model_tbl <- modeltime_table(df_nc_nest$.fit[[i]])
  df_nc_nest$.calib[[i]] <- modeltime_calibrate(model_tbl, new_data = df_nc_nest$data_calib[[i]])
}

for (i in seq_len(nrow(df_ss_nest))) {
  model_tbl <- modeltime_table(df_ss_nest$.fit[[i]])
  df_ss_nest$.calib[[i]] <- modeltime_calibrate(model_tbl, new_data = df_ss_nest$data_calib[[i]])
}

for (i in seq_len(nrow(df_ot_nest))) {
  model_tbl <- modeltime_table(df_ot_nest$.fit[[i]])
  df_ot_nest$.calib[[i]] <- modeltime_calibrate(model_tbl, new_data = df_ot_nest$data_calib[[i]])
}


#Refit models
message('Refit models using all data...')

df_ld_nest$.refit <- vector("list", nrow(df_ld_nest))
for (i in seq_len(nrow(df_ld_nest))) {
  df_ld_nest$.refit[[i]] <- modeltime_refit(df_ld_nest$.calib[[i]], data = df_ld_nest$data_full[[i]])
}

df_nc_nest$.refit <- vector("list", nrow(df_nc_nest))
for (i in seq_len(nrow(df_nc_nest))) {
  df_nc_nest$.refit[[i]] <- modeltime_refit(df_nc_nest$.calib[[i]], data = df_nc_nest$data_full[[i]])
}

df_ss_nest$.refit <- vector("list", nrow(df_ss_nest))
for (i in seq_len(nrow(df_ss_nest))) {
  df_ss_nest$.refit[[i]] <- modeltime_refit(df_ss_nest$.calib[[i]], data = df_ss_nest$data_full[[i]])
}

df_ot_nest$.refit <- vector("list", nrow(df_ot_nest))
for (i in seq_len(nrow(df_ot_nest))) {
  df_ot_nest$.refit[[i]] <- modeltime_refit(df_ot_nest$.calib[[i]], data = df_ot_nest$data_full[[i]])
}

toc()