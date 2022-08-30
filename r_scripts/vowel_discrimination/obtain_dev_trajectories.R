# This script calculates the developmental vowel discrimination trajectory of the 
# model and overlaps it with the infant trajectory.

library(tidyverse)
library(ggplot2)

options(dplyr.summarise.inform = FALSE)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

source('obtain_effect_sizes.R')
source('replication_analyses.R')


obtain_vowel_effects_for_all_epochs <- function(folder, model, contrasts_type, es, alpha){
  es_epochs <- list()
  steps = c(0, 562, 1125, 1688, 2251, 2814, 3377, 3940, 4503, 5066)
  steps = c(steps, 1:10)
  for (epoch in steps) {
    if (contrasts_type=='native') {
      results_path_c = paste(folder, model, '/', as.character(epoch), '/vowel_disc/dtw_distances_hc_native.csv', sep='')
      results_path_ivc = paste(folder, model, '/', as.character(epoch), '/vowel_disc/dtw_distances_ivc_native.csv', sep='')
    }else{
      results_path_c = paste(folder, model, '/', as.character(epoch), '/vowel_disc/dtw_distances_oc_non_native.csv', sep='')
      results_path_ivc = paste(folder, model, '/', as.character(epoch), '/vowel_disc/dtw_distances_ivc_non_native.csv', sep='')
    }
    
    es_contrasts_c <- calculate_standardised_mean_gain_per_contrast(results_path_c)
    es_contrasts_ivc <- calculate_standardised_mean_gain_per_contrast(results_path_ivc)
    es_contrasts_c$corpus <- 'natural'
    es_contrasts_ivc$corpus <- 'synthetic'
    es_all_contrasts <- rbind(es_contrasts_c, es_contrasts_ivc)
    write.csv(es_all_contrasts, paste("./",model,"_vowel_results/", model, "_", contrasts_type, "_", as.character(epoch), ".csv", sep=""))
    
    es_epoch <- calculate_mean_effect(es_all_contrasts, es, alpha)
    es_epochs <- append(es_epochs, list(es_epoch))
  }
  
  return(es_epochs)
}

test_distributions <- function(folder, model, contrasts_type){
  steps = c(0, 562, 1125, 1688, 2251, 2814, 3377, 3940, 4503, 5066)
  steps = c(steps, 1:10)
  
  measurments = data.frame()
  
  for (epoch in steps) {
    if (contrasts_type=='native') {
      results_path_c = paste(folder, model, '/', as.character(epoch), '/vowel_disc/dtw_distances_hc_native.csv', sep='')
      results_path_ivc = paste(folder, model, '/', as.character(epoch), '/vowel_disc/dtw_distances_ivc_native.csv', sep='')
    }else{
      results_path_c = paste(folder, model, '/', as.character(epoch), '/vowel_disc/dtw_distances_oc_non_native.csv', sep='')
      results_path_ivc = paste(folder, model, '/', as.character(epoch), '/vowel_disc/dtw_distances_ivc_non_native.csv', sep='')
    }
    
    tmp1 = read.csv(results_path_c, sep=';')
    tmp2 = read.csv(results_path_ivc, sep=';')
    
    tmp1$epoch = epoch
    tmp2$epoch = epoch
    tmp1$corpus = 'natural'
    tmp2$corpus = 'synthesised'
    
    measurments = rbind(measurments, tmp1, tmp2)
  }
  
  measurments %>% 
    filter(epoch < 11) %>%
    ggplot(aes(x=distance))+
    geom_density(aes(fill=condition), alpha=0.4) +
    facet_wrap(~epoch)
  
}

get_vowel_disc_effects_dataframe <- function(folder, model, contrasts_type, es, alpha){
  effects_list <- obtain_vowel_effects_for_all_epochs(folder, model, contrasts_type, es, alpha)
  ds <- c()
  significant <- c()
  total_steps <- length(effects_list)
  for (epoch in 1:total_steps){
    ds <- c(ds, effects_list[[epoch]]$mean_es)
    significant <- c(significant, effects_list[[epoch]]$significant)
  }
  
  days <- c(0:9)*1.73  # days represented by 10 hours of speech
  days <- c(days, c(1:9)*17.3, 9*17.3 + 10.3) # total days represented by 960 hours of speech. last chunk only contains 60 hours of speech
  
  checkpoint <- rep("batch", 9)
  checkpoint <- c("epoch", checkpoint, rep("epoch",10))
  
  df <- data.frame(
    days = days,
    d = ds,
    significant = significant,
    checkpoint = checkpoint
  )
  return (df)
}

plot_developmental_trajectories <- function(folder, model, contrast_type, es, alpha) {
  model_effects <- get_vowel_disc_effects_dataframe(folder, model, contrast_type, es, alpha)
  
  lm_fit = lm(d~days, model_effects)
  age_significance <- summary(lm_fit)$coefficients[2,4]
  model_mean_es <- summary(lm_fit)$coefficients[1,1]
  
  if(age_significance>alpha){
    model_effects <- model_effects %>% mutate(predicted = model_mean_es)
  }else{
    model_effects <- model_effects %>% mutate(predicted = predict(lm_fit, model_effects))
  }
  
  if(contrast_type=="native"){
    inf_data = nat_vowels_mod
    mean_es = mean_es_nat 
    lb_es = mean_es_nat_ci.lb 
    ub_es = mean_es_nat_ci.ub
    lb_y =  -1.5
    ub_y = 2.5
    min_age = 3
    max_age = 445
  }else{
    inf_data = nonnat_vowels_mod
    mean_es = mean_es_nonnat
    lb_es = mean_es_nonnat_ci.lb 
    ub_es = mean_es_nonnat_ci.ub
    lb_y =  -1 
    ub_y = 3.2
    min_age = 106
    max_age = 411
  }
  
  p <- inf_data %>%
    ggplot(aes(x=mean_age_1, y=g_calc)) +
    geom_point(aes(size = n_1), alpha = .3) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey") +
    scale_size_continuous(guide="none") +
    xlab("\nSimulated Model Age / Real Infant Age (Days)") + 
    ylab("Effect Size (g)\n")
  
  if(is.na(mean_es)){
    # age moderator is significant
    p <- p + geom_smooth(aes(weight=1/g_var_calc, color="blue"), method = "lm", 
                         size=0.9, se=TRUE, fill="grey70")
  } else{
    # age moderator is non-significant. effect size does not change with age
    p <- p +annotate('ribbon', x = c(min_age, max_age), ymin = lb_es, ymax = ub_es, 
                     alpha = 0.5, fill = 'grey70') +
      geom_segment(aes(y = mean_es, yend= mean_es, x=min_age, xend=max_age), 
                   linetype='solid', colour="blue", size=0.9)
  }
  
  if(!is.na(lb_y) & !is.na(ub_y)){
    p <- p + scale_y_continuous(expand = c(0, 0), limits = c(lb_y, ub_y),
                                breaks = seq(lb_y, ub_y, 1)) +
      #xlim(0, 15) +
      coord_cartesian(clip = "off")
  }
  
  p <- p + theme(legend.position =  c(0.8,0.8), 
                 text = element_text(size=20), 
            axis.line = element_line(color='black', size=1)) +
    labs(colour="")
  
  p <- p +
    # model
    geom_line(
      data=model_effects, 
      size = 0.9,
      aes(y=predicted, x=days, colour="#F8766D")
    ) + 
    geom_point(
      colour = '#F8766D', 
      size = 2, 
      data = model_effects,
      aes(x= days, y = d, shape = significant)
    ) +
    guides("shape"="none") +
    scale_shape_manual(
      values = c(1,8)
    ) +
    scale_colour_manual(
      name = NULL, 
      values =c('#F8766D'='#F8766D','blue'='blue'), 
      labels = c('APC','Infants')
    )
  p
  
}

plot_developmental_trajectories("Model_Dev_Results/", "apc", "native", "g", 0.05)
apc_results_nat = get_vowel_disc_effects_dataframe("Model_Dev_Results/", "apc", "native", "g", 0.05)
apc_results_nat['capability'] = 'Vowel discr. (native)'

plot_developmental_trajectories("Model_Dev_Results/", "apc", "non_native", "g", 0.05)
apc_results_nonnat = get_vowel_disc_effects_dataframe("Model_Dev_Results/", "apc", "non_native", "g", 0.05)
apc_results_nonnat['capability'] = 'Vowel discr. (non-native)'

apc_results = rbind(apc_results_nat, apc_results_nonnat)
write_csv(apc_results, 'apc_results_vowel_discr.csv')

