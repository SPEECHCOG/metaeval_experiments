# Sanity checks of computational test (orthogonal and random representations)

library(tidyverse)
library(ggplot2)

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
  
  total_contrasts <- condition_statistics  %>% group_by(contrast, language) %>% 
    select(contrast, language) %>% filter(row_number()==1)
  
  effect_sizes_contrasts <- condition_statistics %>% 
    group_by(contrast, language) %>% 
    summarise(d=(mean[condition=='different']-mean[condition=='same'])/
                sqrt((sd[condition=='different']^2+sd[condition=='same']^2)/2),
              n1 = n[condition=='different'], n2=n[condition=='same'])
  effect_sizes_contrasts <- effect_sizes_contrasts %>% 
    mutate(g = d * (1 - 3/(4*(n1+n2-2) - 1)))
  effect_sizes_contrasts$t <- 0
  effect_sizes_contrasts$p_value <- 0
  
  for(i in 1:nrow(total_contrasts)){
    contrast_tmp = total_contrasts[i, ]$contrast
    language_tmp = total_contrasts[i, ]$language
    
    contrast_measurements <- measurements %>% filter(contrast == contrast_tmp, language == language_tmp)
    t_test_contrast <- get_t_statistics(contrast_measurements)
    
    effect_sizes_contrasts[effect_sizes_contrasts$contrast==contrast_tmp & effect_sizes_contrasts$language==language_tmp,]$t = t_test_contrast$statistic
    effect_sizes_contrasts[effect_sizes_contrasts$contrast==contrast_tmp & effect_sizes_contrasts$language==language_tmp,]$p_value = t_test_contrast$p.value
  }
  
  return(effect_sizes_contrasts)
}

calculate_mean_effect <- function(effect_sizes_per_contrast, effect){
  mean_es = mean(effect_sizes_per_contrast[[effect]])
  sd_es = sd(effect_sizes_per_contrast[[effect]])
  return(list('mean_es'=mean_es, 'sd_es'=sd_es))
}

# Sanity check
# we expect to have a null effect when the encoded stimuli vectors are random and
# a large effect when they correspond to orthogonal vectors. 

es = 'g'

# Random
random_ivc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_random_ivc_native.csv')
random_hc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Hillenbrands_Corpus/dtw_distances_random_hc_native.csv')
random_nat <- rbind(random_ivc_nat, random_hc_nat)

random_d_nat <- calculate_mean_effect(random_nat, es)

random_ivc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_random_ivc_non_native.csv')
random_oc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/OLLO_Corpus/dtw_distances_random_oc_non_native.csv')
random_nonnat <- rbind(random_ivc_nonnat, random_oc_nonnat)

random_d_nonnat <- calculate_mean_effect(random_nonnat, es)

# Orthogonal
ortho_ivc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_ortho_ivc_native.csv')
ortho_hc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Hillenbrands_Corpus/dtw_distances_ortho_hc_native.csv')
ortho_nat <- rbind(ortho_ivc_nat, ortho_hc_nat)

ortho_d_nat <- calculate_mean_effect(ortho_nat, es)
ortho_es_ivc_nat <- calculate_mean_effect(ortho_ivc_nat, es)
ortho_es_hc_nat <- calculate_mean_effect(ortho_hc_nat, es)

ortho_ivc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_ortho_ivc_non_native.csv')
ortho_oc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/OLLO_Corpus/dtw_distances_ortho_oc_non_native.csv')
ortho_nonnat <- rbind(ortho_ivc_nonnat, ortho_oc_nonnat)

ortho_d_nonnat <- calculate_mean_effect(ortho_nonnat, es)
ortho_es_ivc_nonnat <- calculate_mean_effect(ortho_ivc_nonnat, es)
ortho_es_oc_nonnat <- calculate_mean_effect(ortho_oc_nonnat, es)

