# Vowel discrimination test
# Calculation of effect size based on DTW distances (using encoded stimuli)
# from APC models.

library(tidyverse)
library(ggplot2)
library(metafor)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

get_condition_mean <- function(measurements){
  mean_per_condition <- measurements %>% 
    group_by(contrast, language, condition) %>%
    summarise(mean = mean(distance, na.rm = TRUE),
              sd = sd(distance, na.rm = TRUE),
              n = n())
  return(mean_per_condition)
}

get_t_statistics <- function(contrast_measurements){
  tryCatch(
    expr = {
      t_test <- t.test(contrast_measurements[contrast_measurements$condition=='different',]$distance,
                       contrast_measurements[contrast_measurements$condition=='same',]$distance)
      return(t_test)
    },
    error = function(e){
      t_test <- data.frame(statistic=c(NA), p.value=c(NA))
      return(t_test)
    }
  )
}

calculate_standardised_mean_gain_per_contrast <- function(dtw_distances_file_path){
  # one effect size per paired trial
  measurements <- read.csv(dtw_distances_file_path, sep = ';')

  condition_statistics <- get_condition_mean(measurements)
  # print(condition_statistics)
  
  total_contrasts <- condition_statistics  %>% group_by(contrast, language) %>% 
    select(contrast, language) %>% filter(row_number()==1)
  
  effect_sizes_contrasts <- condition_statistics %>% 
    group_by(contrast, language) %>% 
    summarise(d=(mean[condition=='different']-mean[condition=='same'])/
                sqrt((sd[condition=='different']^2+sd[condition=='same']^2)/2),
              n1 = n[condition=='different'], n2=n[condition=='same'])
  effect_sizes_contrasts <- effect_sizes_contrasts %>% 
    mutate(g = d * (1 - 3/(4*(n1+n2-2) - 1)), 
           se_d =  sqrt(((n1+n2)/(n1*n2)) + (d^2/(2*n1*n2))),
           se_g = sqrt(((n1+n2)/(n1*n2)) + (g^2/(2*n1*n2))),
           w_d = 1/(se_d^2),
           w_g = 1/(se_g^2))
  effect_sizes_contrasts$t <- 0
  effect_sizes_contrasts$p_value <- 0
  
  for(i in 1:nrow(total_contrasts)){
    contrast_tmp = total_contrasts[i, ]$contrast
    language_tmp = total_contrasts[i, ]$language
    
    contrast_measurements <- measurements %>% filter(contrast == contrast_tmp, language == language_tmp)
    t_test_contrast <- get_t_statistics(contrast_measurements)
    # print(t_test_contrast)
    effect_sizes_contrasts[effect_sizes_contrasts$contrast==contrast_tmp & effect_sizes_contrasts$language==language_tmp,]$t = t_test_contrast$statistic
    effect_sizes_contrasts[effect_sizes_contrasts$contrast==contrast_tmp & effect_sizes_contrasts$language==language_tmp,]$p_value = t_test_contrast$p.value
  }
  
  return(effect_sizes_contrasts)
}

calculate_mean_effect <- function(effect_sizes_per_contrast, effect, alpha){
  # Equations from Practical Meta-analysis (Lipsey and Wilson, 2001; pp 114)
  if(effect=='g'){
    tmp_es <- effect_sizes_per_contrast %>% mutate(weight = w_g*g)
    weighted_es = sum(tmp_es$weight)/sum(tmp_es$w_g)
    se_weighted_es = sqrt(1/(sum(tmp_es$w_g)))
    
  }else{
    # d
    tmp_es <- effect_sizes_per_contrast %>% mutate(weight = w_d*d)
    weighted_es = sum(tmp_es$weight)/sum(tmp_es$w_d)
    se_weighted_es = sqrt(1/(sum(tmp_es$w_d)))
  }
  
  mean_es = weighted_es
  se_es = se_weighted_es
  z = qnorm(p=alpha/2, lower.tail = FALSE)
  ci.lb = mean_es - (z*se_es)
  ci.ub = mean_es + (z*se_es)
  
  if((abs(mean_es)/se_es) > z){
    significant = TRUE
  }else{
    significant = FALSE
  }
  
  return(list('mean_es'=mean_es, 'significant'=significant, 
              'se_es'=se_es, 'ci.lb'=ci.lb, 'ci.ub'=ci.ub))
}





