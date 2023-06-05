# Analysis of attentional scores distribution for APC model.
# This script also includes sanity checks for the computational test

## Loading data
library(tidyverse)
library(ggplot2)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

apc_at_untrained <- read.csv("test_results_large_apc/apc/0/ids/attentional_preference_scores.csv", sep = ';')

transform_dv <- function(data){
  new_data = data %>% mutate(attentional_preference_score = log(data$attentional_preference_score))
}

# function to create plots for the different data
create_density_plots <- function(attentional_scores, model){
  attentonal_scores <- attentional_scores %>% filter_if(~is.numeric(.), all_vars(!is.infinite(.)))
  print(sum(is.infinite(attentonal_scores$attentional_preference_score)))
  b <- ggplot(attentional_scores, aes(x=attentional_preference_score, fill=trial_type)) + 
    geom_density(aes(group=trial_type), alpha=0.25) +
    geom_vline(aes(xintercept = mean(attentional_preference_score)), 
               linetype = "dashed", size = 0.6) + 
    ggtitle(paste('a(t) distribution per trial type: ',model)) 
  print(b)
  
  a <- ggplot(attentional_scores, aes(x=attentional_preference_score, fill=interaction(trial_type))) + 
    geom_density(aes(group=interaction(trial_type, file_name)), alpha=0.25) +
    geom_vline(aes(xintercept = mean(attentional_preference_score)), 
               linetype = "dashed", size = 0.6) +
    ggtitle(paste('a(t) distribution per recording:', model)) 
  print(a)
  
  # Distribution of means: trial responses
  alpha_scores <- attentional_scores %>% group_by(file_name, trial_type) %>%
    summarise(alpha = mean(attentional_preference_score))
  c <- ggplot(alpha_scores, aes(x=alpha, fill=trial_type)) +
    geom_density(aes(group=trial_type), alpha=0.25) +
    geom_vline(aes(xintercept= mean(alpha)), 
               linetype= "dashed", size=0.6) +
    ggtitle(paste('alpha_i distribution:', model))
  print(c)
}

create_density_plots(apc_at_untrained, 'Untrained APC')
create_density_plots(transform_dv(apc_at_untrained), 'Untrained APC (log)')


# Check for normality (https://www.sheffield.ac.uk/polopoly_fs/1.885202!/file/95_Normality_Check.pdf)
check_normality <- function(data, title){
  data <- data %>% 
    filter_if(~is.numeric(.), all_vars(!is.infinite(.)))
  print(sum(is.infinite(data$attentional_preference_score)))
  ads_data <- filter(data, trial_type=='ADS')$attentional_preference_score
  ids_data <- filter(data, trial_type=='IDS')$attentional_preference_score
  qqnorm(ads_data, pch=19, main=paste(title, ' ADS')) 
  qqline(ads_data)
  
  qqnorm(ids_data, pch=19, main=paste(title, ' IDS'))
  qqline(ids_data)
  
  # Test subset of 5000
  print(paste('Shapiro-Wilk test:', title, ' ADS'))
  print(shapiro.test(ads_data[1:5000]))
  print(paste('Shapiro-Wilk test:', title, ' IDS'))
  print(shapiro.test(ids_data[1:5000]))
}

check_normality(apc_at_untrained, 'Untrained APC')

# Test with log(attentional_score)
check_normality(transform_dv(apc_at_untrained), 'Untrained APC (log)')

# Sanity check of computational test
# We expect to have a null effect if the attentional preference scores comes
# from a random distribution for both IDS and ADS styles, and a large effect
# when they come from two different normal distributions


calculate_standardised_mean_gain <- function(measurements){
  # one effect size per paired trial
  trial_scores <- measurements %>%
    group_by(file_name, trial_type) %>%
    summarise(alpha = mean(attentional_preference_score, na.rm = TRUE)) 
  cond_statistics <- trial_scores %>% 
    group_by(trial_type) %>%
    summarise(mean = mean(alpha),
              sd = sd(alpha))
  ads = cond_statistics[cond_statistics$trial_type=='ADS',]
  ids = cond_statistics[cond_statistics$trial_type=='IDS',]
  d = (ids$mean - ads$mean) / sqrt((ids$sd^2 + ads$sd^2)/2)
  t_test <- t.test(trial_scores[trial_scores$trial_type=='IDS',]$alpha, 
                   trial_scores[trial_scores$trial_type=='ADS',]$alpha)
  ids_n <- nrow(trial_scores[trial_scores$trial_type=='IDS',])
  ads_n <- nrow(trial_scores[trial_scores$trial_type=='ADS',])
  
  d_var <- (ids_n+ads_n)/(ids_n*ads_n)+(d^2)/(2*(ids_n+ads_n))
  # 95% CI
  ci_lb <- d - 1.959964*sqrt(d_var)
  ci_ub <- d + 1.959964*sqrt(d_var)
  
  return(list('d'=d, 'trial_scores'=trial_scores, 'cond_statistics'= cond_statistics, 
              't'= t_test$statistic, 'p-value'=t_test$p.value, 'ci_lb'=ci_lb,
              'ci_ub'=ci_ub))
}

simulation <- function(){
  random_at <- read.csv("test_results_large_apc/apc/0/ids/attentional_preference_scores.csv", sep = ';')
  two_dist_at <- read.csv("test_results_large_apc/apc/0/ids/attentional_preference_scores.csv", sep = ';')
  file_names <- unique(random_at$file_name)
  
  
  for (wav in file_names){
    n_frames <- nrow(random_at[random_at$file_name == wav,])
    random_at[random_at$file_name == wav, ]$attentional_preference_score <- rnorm(n_frames, mean=0, sd=1)
    if (first(two_dist_at[two_dist_at$file_name == wav,]$trial_type) == 'ADS'){
      two_dist_at[two_dist_at$file_name == wav,]$attentional_preference_score <- rnorm(n_frames, mean=100, sd=15)  
    }else{  # IDS
      two_dist_at[two_dist_at$file_name == wav,]$attentional_preference_score <- rnorm(n_frames, mean=130, sd=15)  
    }
  }
  
  return(list('random' = calculate_standardised_mean_gain(random_at), 
              'two_distributions'=calculate_standardised_mean_gain(two_dist_at)))
}

