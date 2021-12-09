# Vowel discrimination test
# Calculation of effect size based on DTW distances (using encoded stimuli)
# from APC and CPC models. 

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
  # print(condition_statistics)
  
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
    # print(t_test_contrast)
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

# Calculate effect sizes for Native and Non-native contrasts
es = 'g'

# APC Native contrasts
apc_ivc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_apc_ivc_native.csv')
apc_hc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Hillenbrands_Corpus/dtw_distances_apc_hc_native.csv')
apc_nat <- rbind(apc_ivc_nat, apc_hc_nat)
apc_es_nat <- calculate_mean_effect(apc_nat, es)

apc_untrained_ivc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_apc_untrained_ivc_native.csv')
apc_untrained_hc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Hillenbrands_Corpus/dtw_distances_apc_untrained_hc_native.csv')
apc_untrained_nat <- rbind(apc_untrained_ivc_nat, apc_untrained_hc_nat)
apc_untrained_es_nat <- calculate_mean_effect(apc_untrained_nat, es)

# APC Non-native contrasts
apc_ivc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_apc_ivc_non_native.csv')
apc_oc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/OLLO_Corpus/dtw_distances_apc_oc_non_native.csv')
apc_nonnat <- rbind(apc_ivc_nonnat, apc_oc_nonnat)
apc_es_nonnat <- calculate_mean_effect(apc_nonnat, es)

apc_untrained_ivc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_apc_untrained_ivc_non_native.csv')
apc_untrained_oc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/OLLO_Corpus/dtw_distances_apc_untrained_oc_non_native.csv')
apc_untrained_nonnat <- rbind(apc_untrained_ivc_nonnat, apc_untrained_oc_nonnat)
apc_untrained_es_nonnat <- calculate_mean_effect(apc_untrained_nonnat, es)

# CPC Native contrasts
cpc_ivc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_cpc_ivc_native.csv')
cpc_hc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Hillenbrands_Corpus/dtw_distances_cpc_hc_native.csv')
cpc_nat <- rbind(cpc_ivc_nat, cpc_hc_nat)
cpc_es_nat <- calculate_mean_effect(cpc_nat, es)

cpc_untrained_ivc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_cpc_untrained_ivc_native.csv')
cpc_untrained_hc_nat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Hillenbrands_Corpus/dtw_distances_cpc_untrained_hc_native.csv')
cpc_untrained_nat <- rbind(cpc_untrained_ivc_nat, cpc_untrained_hc_nat)
cpc_untrained_es_nat <- calculate_mean_effect(cpc_untrained_nat, es)

# CPC Non-native contrasts
cpc_ivc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_cpc_ivc_non_native.csv')
cpc_oc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/OLLO_Corpus/dtw_distances_cpc_oc_non_native.csv')
cpc_nonnat <- rbind(cpc_ivc_nonnat, cpc_oc_nonnat)
cpc_es_nonnat <- calculate_mean_effect(cpc_nonnat, es)

cpc_untrained_ivc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/Isolated_Vowels_Corpus/dtw_distances_cpc_untrained_ivc_non_native.csv')
cpc_untrained_oc_nonnat <- calculate_standardised_mean_gain_per_contrast('Model_Results/OLLO_Corpus/dtw_distances_cpc_untrained_oc_non_native.csv')
cpc_untrained_nonnat <- rbind(cpc_untrained_ivc_nonnat, cpc_untrained_oc_nonnat)
cpc_untrained_es_nonnat <- calculate_mean_effect(cpc_untrained_nonnat, es)


# ES comparison with infants' ES
get_es_plot <- function(es_data, lb_infants){
  q=ggplot(es_data, aes(y=es, x=source, ymin=lb, ymax=ub, label=significance))+
    #Add data points and color them black
    geom_point(colour = 'black', size=3) +
    geom_text(size=10, nudge_x = -0.1, nudge_y = 0.02, show.legend = FALSE) +
    #Add 'special' points for the summary estimates, by making them diamond shaped
    #add the CI error bars
    geom_errorbar(width=.1)+
    #Specify the limits of the x-axis and relabel it to something more meaningful
    #Give y-axis a meaningful label
    xlab('Source') +
    ylab('Effect size') +
    ylim(0, 2.5) +
    #Add a vertical dashed line indicating an effect size of zero, for reference
    geom_hline(yintercept=lb_infants, color='red', linetype='dashed') + 
    # Red region: umcompatible region
    geom_rect(mapping = aes(xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=lb_infants), 
              fill='red', alpha=0.2)
  
  q + theme(legend.position = "none", text = element_text(size=18), 
            axis.line = element_line(color='black', size=1))
}

# TODO Update Infants' ES! 

# Native contrasts
labels_significance = c('n.s.'="", 's.'="*")
es_data_nat <- data.frame(es = c(apc_es_nat$mean_es, cpc_es_nat$mean_es, 0.42),
                      source = c('APC', 'CPC', 'Infants'),
                      lb = c(NA, NA, 0.33),
                      ub = c(NA, NA, 0.51),
                      significance = factor(c('s.', 's.', 's.'), labels=labels_significance, levels=c('n.s.', 's.')))

lb_infants_nat = es_data_nat[es_data_nat$source=='Infants']$lb

get_es_plot(es_data_nat, lb_infants_nat)

# Non-native contrasts
es_data_nonnat <- data.frame(es = c(apc_es_nonnat$mean_es, cpc_es_nonnat$mean_es, 0.46),
                          source = c('APC', 'CPC', 'Infants'),
                          lb = c(NA, NA, 0.21),
                          ub = c(NA, NA, 0.72),
                          significance = factor(c('s.', 's.', 's.'), labels=labels_significance, levels=c('n.s.', 's.')))

lb_infants_nonnat = es_data_nonnat[es_data_nonnat$source=='Infants']$lb

get_es_plot(es_data_nonnat, lb_infants_nonnat)

# Development of ES (0-100 h training)
get_es_change_plot <- function(es_dev, lb_y=NA, ub_y=NA, pos_legend=NA){
  pos_label_x <- es_dev$pos_label_x
  pos_label_y <- es_dev$pos_label_y
  p=ggplot(es_dev, aes(y=es, x=hours, group=model, colour=model, 
                       linetype=model, label=significance)) +
    #Add data points and color them black
    geom_point(colour = 'black', size=3, shape=16) +
    geom_text(size=10, nudge_x = pos_label_x, nudge_y = pos_label_y, show.legend = FALSE) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey") +
    #Give y-axis a meaningful label
    xlab('\nInput duration (hours)') +
    ylab('Effect size\n') +
    geom_smooth(se=FALSE, method=lm)
  
  if(!is.na(lb_y) & !is.na(ub_y)){
    p <- p + scale_y_continuous(expand = c(0, 0), limits = c(lb_y, ub_y),
                                breaks = seq(lb_y, ub_y, 1)) +
      coord_cartesian(clip = "off")
  }
  if (is.na(pos_legend)){
    pos_legend = c(0.8, 0.2)
  }
  p + theme(legend.position = pos_legend, text = element_text(size=18), 
            axis.line = element_line(color='black', size=1)) +
    labs(colour='Model:', linetype='Model:', label="")
}

# Native contrasts
es_dev_nat <- data.frame(hours = c('0', '100', '0', '100'),
                     es = c(apc_untrained_es_nat$mean_es, apc_es_nat$mean_es, cpc_untrained_es_nat$mean_es, cpc_es_nat$mean_es),
                     significance = factor(c('s.', 's.', 's.', 's.'), labels=labels_significance, levels=c('n.s.', 's.')),
                     pos_label_x = c(-0.1,0.05,-0.1, 0.05),
                     pos_label_y = c(-0.1,0.02,0.01, 0.02),
                     model = c('APC', 'APC', 'CPC', 'CPC'))

get_es_change_plot(es_dev_nat, -1.5,2.5)

# Non-native contrasts
es_dev_nonnat <- data.frame(hours = c('0', '100', '0', '100'),
                         es = c(apc_untrained_es_nonnat$mean_es, apc_es_nonnat$mean_es, cpc_untrained_es_nonnat$mean_es, cpc_es_nonnat$mean_es),
                         significance = factor(c('s.', 's.', 's.', 's.'), labels=labels_significance, levels=c('n.s.', 's.')),
                         pos_label_x = c(-0.1,0.08,-0.1, 0.08),
                         pos_label_y = c(0.01,0.02,0.01, 0.02),
                         model = c('APC', 'APC', 'CPC', 'CPC'))

get_es_change_plot(es_dev_nonnat, -1, 3.2, c(0.2, 0.8))

