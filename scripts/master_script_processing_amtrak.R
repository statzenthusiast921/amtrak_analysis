#Run scripts to generate ridership forecasts

generate_ridership_reports <- function(proceed = TRUE){
  path <- '/Users/jonzimmerman/Desktop/Data Projects/Amtrak/scripts/'
  source(paste0(path,'step1_amtrak_data_prep.R'))
  source(paste0(path,'step2_amtrak_define_recipes_workflows.R'))
  source(paste0(path,'step3_amtrak_fit_models.R'))
  source(paste0(path,'step4_amtrak_generate_forecasts.R'))
  
  if (proceed) {
    message('Step 5 not ready yet')
    #source(paste0(path,'step5b_generate_reports.R'))
  }
}


generate_ridership_reports(TRUE)
