# This script calculates the developmental vowel discrimination trajectory of the 
# model and overlaps it with the infant trajectory.

library(tidyverse)
library(ggplot2)

options(dplyr.summarise.inform = FALSE)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

source('obtain_effect_sizes.R')
source('replication_analyses.R')

obtain_steps <- function(folder, model){
  # Get name of steps
  tmp_steps = c()
  dirs_steps = list.dirs(paste(folder, model, sep=""), recursive=FALSE)
  for (dir_step in dirs_steps){
    tmp_steps = c(tmp_steps, as.integer(basename(dir_step)))
  }
  # Order in increasing order
  tmp_steps = sort(tmp_steps)
  # Select batch and epoch correctly
  batch_steps = c()
  epoch_steps = c()
  for (step in tmp_steps){
    if (step==0){
      batch_steps = c(batch_steps, step)
    }else if(step<100 & step<19) { # discard last epoch (2 hours only)
      # arbitrary value, batch starts by ~500
      epoch_steps = c(epoch_steps, step)
    } else{
      batch_steps = c(batch_steps, step)
    }
  }
  steps = c(batch_steps, epoch_steps)
  return(list('steps'=steps, 'batch_steps'=length(batch_steps), 
              'epoch_steps'=length(epoch_steps)))
}

obtain_vowel_effects_for_all_epochs <- function(folder, model, contrasts_type, es, alpha){
  es_epochs <- list()
  steps_info = obtain_steps(folder, model)
  steps = steps_info[['steps']]
  batch_steps = steps_info[['batch_steps']]
  epoch_steps = steps_info[['epoch_steps']]

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
    write.csv(es_all_contrasts, paste("./","apc_large_vowel_results/", model, "_", contrasts_type, "_", as.character(epoch), ".csv", sep=""))
    
    es_epoch <- calculate_mean_effect(es_all_contrasts, es, alpha)
    es_epochs <- append(es_epochs, list(es_epoch))
  }

  return(list('es_epochs'=es_epochs, 'batch_steps'=batch_steps, 'epoch_steps'=epoch_steps))
}

test_distributions <- function(folder, model, contrasts_type){
  steps_info = obtain_steps(folder, model)
  steps = steps_info[['steps']]
  batch_steps = steps_info[['batch_steps']]
  epoch_steps = steps_info[['epoch_steps']]
  
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

get_vowel_disc_effects_dataframe <- function(folder, model, contrasts_type, es, alpha, batch_age, epoch_age){
  
  effects_info = obtain_vowel_effects_for_all_epochs(folder, model, contrasts_type, es, alpha)
  effects_list <- effects_info[['es_epochs']]
  batch_steps = effects_info[['batch_steps']]
  epoch_steps = effects_info[['epoch_steps']]
  
  ds <- c()
  significant <- c()
  total_steps <- length(effects_list)
  for (epoch in 1:total_steps){
    ds <- c(ds, effects_list[[epoch]]$mean_es)
    significant <- c(significant, effects_list[[epoch]]$significant)
  }
  
  age <- c(0:(batch_steps-1))* batch_age # days represented by 10 hours of speech
  age <- c(age, c(1:epoch_steps)* epoch_age) # total days represented by 100 hours of speech
  
  checkpoint <- rep("batch", batch_steps-1)
  checkpoint <- c("epoch", checkpoint, rep("epoch",epoch_steps))
  
  df <- data.frame(
    age = age,
    d = ds,
    significant = significant,
    checkpoint = checkpoint
  )
  return (df)
}

plot_developmental_trajectories <- function(folder, model, contrast_type, es, alpha, batch_age, epoch_age) {
  model_effects <- get_vowel_disc_effects_dataframe(folder, model, contrast_type, es, alpha, batch_age, epoch_age)
  model_effects <- model_effects %>% filter(checkpoint!='batch')

  vowel_mo = 30.42
  if(contrast_type=="native"){
    inf_data = nat_vowels_mod
    mean_es = mean_es_nat 
    lb_es = mean_es_nat_ci.lb 
    ub_es = mean_es_nat_ci.ub
    min_age = 3/vowel_mo
    max_age = 445/vowel_mo
  }else{
    inf_data = nonnat_vowels_mod
    mean_es = mean_es_nonnat
    lb_es = mean_es_nonnat_ci.lb 
    ub_es = mean_es_nonnat_ci.ub
    min_age = 106/vowel_mo
    max_age = 411/vowel_mo
  }
  
  lb_y = -1.5
  ub_y = 3.2

  inf_data <- inf_data %>% mutate(mean_age_1 = mean_age_1 /vowel_mo)
  
  p <- inf_data %>%
    ggplot(aes(x=mean_age_1, y=g_calc)) +
    geom_point(aes(size = n_1), alpha = .3) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey") +
    scale_size_continuous(guide="none") +
    xlab("\nSimulated Model Age / Real Infant Age (Months)") + 
    ylab("Effect Size\n")
  
  if(is.na(mean_es)){
    # age moderator is significant
    p <- p + geom_smooth(aes(weight=1/g_var_calc, color="blue"), method = "lm", 
                         size=0.9, se=TRUE, fill="grey70")
  } else{
    # age moderator is non-significant. effect size does not change with age
    p <- p +annotate('ribbon', x = c(min_age, max_age), ymin = lb_es, ymax = ub_es, 
                     alpha = 0.5, fill = 'grey70') +
      geom_segment(aes(y = mean_es, yend= mean_es, x=min_age, xend=max_age, colour="blue"), 
                   linetype='solid', size=0.9)
  }
  
  if(!is.na(lb_y) & !is.na(ub_y)){
    p <- p + scale_y_continuous(expand = c(0, 0), limits = c(lb_y, ub_y),
                                breaks = seq(lb_y, ub_y, 1)) +
      coord_cartesian(clip = "off")
  }
  p <- p +
    geom_point(
      colour = '#F28C28',
      size = 2, 
      data = model_effects,
      aes(x= age, y = d, shape = significant)
    ) +
    guides("shape"="none") +
    scale_shape_manual(
      values = c(1,8), 
      limits = c(FALSE, TRUE)
    ) +
    scale_colour_manual(
      name = NULL, 
      values =c('#F28C28'='#F28C28','blue'='blue'), 
      labels = c('APC','Infants')
    ) + 
    theme(legend.position =  c(0.85,0.9), 
                 text = element_text(size=20), 
                 axis.line = element_line(color='black', size=1))
  p
  
}

## Results APC trained with LibriSpeech and Spoken COCO
plot_developmental_trajectories("test_results_large_apc/", "apc", "native", "g", 0.05, 0.06, 0.57)
apc_large_results_nat = get_vowel_disc_effects_dataframe("test_results_large_apc/", "apc", "native", "g", 0.05, 0.06, 0.57)
apc_large_results_nat['capability'] = 'Vowel discr. (native)'

plot_developmental_trajectories("test_results_large_apc/", "apc", "non_native", "g", 0.05, 0.06, 0.57)
apc_large_results_nonnat = get_vowel_disc_effects_dataframe("test_results_large_apc/", "apc", "non_native", "g", 0.05, 0.06, 0.57)
apc_large_results_nonnat['capability'] = 'Vowel discr. (non-native)'

apc_large_results = rbind(apc_large_results_nat, apc_large_results_nonnat)
write_csv(apc_large_results, 'apc_large_results_vowel_discr.csv')

## Results for MFCCs
es_hc <- calculate_standardised_mean_gain_per_contrast('./test_results_large_apc/mfcc/dtw_distances_hc_native_mfcc.csv')
es_ivc_nat <- calculate_standardised_mean_gain_per_contrast('./test_results_large_apc/mfcc/dtw_distances_ivc_native_mfcc.csv')
mean_es_native <- calculate_mean_effect(rbind(es_hc,es_ivc_nat), 'g', 0.05)

es_oc <- calculate_standardised_mean_gain_per_contrast('./test_results_large_apc/mfcc/dtw_distances_oc_non_native_mfcc.csv')
es_ivc_nonnat <- calculate_standardised_mean_gain_per_contrast('./test_results_large_apc/mfcc/dtw_distances_ivc_non_native_mfcc.csv')
mean_es_nonnative <- calculate_mean_effect(rbind(es_oc,es_ivc_nonnat), 'g', 0.05)
