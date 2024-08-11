#Generate forecasts
message('Generate forecasts...')
tic()

df_ld_nest$.fc <- vector("list", nrow(df_ld_nest))
for (i in seq_len(nrow(df_ld_nest))) {
  df_ld_nest$.fc[[i]] <- modeltime_forecast(
    object = df_ld_nest$.refit[[i]],
    new_data = df_ld_nest$data_future[[i]],
    actual_data = df_ld_nest$data_full[[i]],
    keep_data = FALSE
  )
}

df_nc_nest$.fc <- vector("list", nrow(df_nc_nest))
for (i in seq_len(nrow(df_nc_nest))) {
  df_nc_nest$.fc[[i]] <- modeltime_forecast(
    object = df_nc_nest$.refit[[i]],
    new_data = df_nc_nest$data_future[[i]],
    actual_data = df_nc_nest$data_full[[i]],
    keep_data = FALSE
  )
}

df_ss_nest$.fc <- vector("list", nrow(df_ss_nest))
for (i in seq_len(nrow(df_ss_nest))) {
  df_ss_nest$.fc[[i]] <- modeltime_forecast(
    object = df_ss_nest$.refit[[i]],
    new_data = df_ss_nest$data_future[[i]],
    actual_data = df_ss_nest$data_full[[i]],
    keep_data = FALSE
  )
}

df_ot_nest$.fc <- vector("list", nrow(df_ot_nest))
for (i in seq_len(nrow(df_ot_nest))) {
  df_ot_nest$.fc[[i]] <- modeltime_forecast(
    object = df_ot_nest$.refit[[i]],
    new_data = df_ot_nest$data_future[[i]],
    actual_data = df_ot_nest$data_full[[i]],
    keep_data = FALSE
  )
}

toc()