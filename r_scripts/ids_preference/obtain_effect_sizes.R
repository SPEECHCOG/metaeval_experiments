# IDS preference test
# Calculation of effect size based on attentional preference scores 
# from APC models.

library(tidyverse)
library(ggplot2)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

get_trial_response <-function(measurements){
  trial_scores <- measurements %>%
    group_by(file_name, trial_type) %>%
    summarise(alpha = mean(attentional_preference_score, na.rm = TRUE)) 
  return(trial_scores)
}

get_t_statistics <- function(trial_scores){
  t_test <- t.test(trial_scores[trial_scores$trial_type=='IDS',]$alpha, 
                   trial_scores[trial_scores$trial_type=='ADS',]$alpha)
  return(t_test)
}

get_d_var <- function(d, trial_scores){
  ids_n <- nrow(trial_scores[trial_scores$trial_type=='IDS',])
  ads_n <- nrow(trial_scores[trial_scores$trial_type=='ADS',])
  
  d_var <- (ids_n+ads_n)/(ids_n*ads_n)+(d^2)/(2*(ids_n+ads_n))
  return(d_var)
}

calculate_standardised_mean_gain <- function(score_file_path){
  # one effect size per paired trial
  measurements <- read.csv(score_file_path, sep = ';')
  
  trial_scores <- get_trial_response(measurements)
  
  cond_statistics <- trial_scores %>% 
    group_by(trial_type) %>%
    summarise(mean = mean(alpha),
              sd = sd(alpha))
  ads = cond_statistics[cond_statistics$trial_type=='ADS',]
  ids = cond_statistics[cond_statistics$trial_type=='IDS',]
  
  d = (ids$mean - ads$mean) / sqrt((ids$sd^2 + ads$sd^2)/2)
  
  t_test <- get_t_statistics(trial_scores)
  d_var <- get_d_var(d, trial_scores)
  
  # 95% CI
  ci_lb <- d - 1.959964*sqrt(d_var)
  ci_ub <- d + 1.959964*sqrt(d_var)
  
  return(list('d'=d, 't'= t_test$statistic, 'p-value'=t_test$p.value, 
              'ci_lb'=ci_lb, 'ci_ub'=ci_ub))
}


