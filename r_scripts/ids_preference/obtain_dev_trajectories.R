# This script calculates the developmental IDS preference trajectory of the 
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
    }else if(step<100 & step<19) { # we discard the last epoch (2 hours)
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

obtain_ids_effects_for_all_epochs <- function(folder, model) {
  es_epochs <- list()
  # identifier of first 10 h speech checkpoints
  # steps = c(0, 562, 1125, 1688, 2251, 2814, 3377, 3940, 4503, 5066)
  # steps = c(steps, 1:10) # identifiers of 100 h speech checkpoints
  
  steps_info = obtain_steps(folder, model)
  steps = steps_info[['steps']]
  batch_steps = steps_info[['batch_steps']]
  epoch_steps = steps_info[['epoch_steps']]
  
  for (epoch in steps) {
    results_path = paste(
      folder,
      model,
      '/',
      as.character(epoch),
      '/ids/attentional_preference_scores.csv',
      sep = ''
    )
    es_epoch = calculate_standardised_mean_gain(results_path)
    es_epochs <- append(es_epochs, list(es_epoch))
  }
  return(list('es_epochs'=es_epochs, 'batch_steps'=batch_steps, 'epoch_steps'=epoch_steps))
}

get_ids_effects_dataframe <- function(folder, model, alpha, batch_age, epoch_age) {
  effects_info <- obtain_ids_effects_for_all_epochs(folder, model)
  effects_list <- effects_info[['es_epochs']]
  batch_steps = effects_info[['batch_steps']]
  epoch_steps = effects_info[['epoch_steps']]
  
  ds <- c()
  p_values <- c()
  total_steps <- length(effects_list)
  for (epoch in 1:total_steps) {
    ds <- c(ds, effects_list[[epoch]]$d)
    p_values <- c(p_values, effects_list[[epoch]]$'p-value')
  }
  
  age <- c(0:(batch_steps-1)) * batch_age # 1.73  # days represented by 10 hours of speech
  age <-
    c(age, c(1:epoch_steps) * epoch_age) # 17.3, 9 * 17.3 + 10.3) # total days represented by 960 hours of speech. last chunk only contains 60 hours of speech
  
  checkpoint <- rep("batch", batch_steps-1)
  checkpoint <- c("epoch", checkpoint, rep("epoch", epoch_steps))
  
  df <- data.frame(
    age = age,
    d = ds,
    significant = p_values <= alpha,
    checkpoint = checkpoint
  )
  return (df)
}


plot_developmental_trajectories <- function(folder, model, alpha, batch_age, epoch_age) {
  model_effects <- get_ids_effects_dataframe(folder, model, alpha, batch_age, epoch_age)
  model_effects <- model_effects %>% filter(checkpoint!='batch')
  #ds_zt_nae <- ds_zt_nae %>% mutate(age_days=age_mo*30.4375) # according to scale used in the original data
  
  p = ggplot(ds_zt_nae,
             aes(x = age_mo, y = d_z)) +
    geom_point(aes(size = n), alpha = .3) +
    geom_hline(yintercept = 0,
               linetype = "dashed",
               color = "grey") +
    geom_smooth(
      method = "lm",
      #colour = "blue",
      size = 0.9,
      se = TRUE,
      fill = "grey70",
      aes(color="blue")
    ) +
    # model
    # geom_smooth(
    #   method = "lm",
    #   colour = "#F8766D",
    #   se = FALSE,
    #   data = model_effects,
    #   aes(x= age, y = d, color="#F8766D")
    # ) + 
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
    scale_size_continuous(guide = "none") +
    scale_y_continuous(
      expand = c(0, 0),
      limits = c(-1, 2.3),
      breaks = seq(-1, 2.3, 1)
    ) +
    coord_cartesian(clip = "off") +
    xlab("\nSimulated Model Age / Real Infant Age (Months)") +
    ylab("Effect Size\n") +
    theme(
      legend.position =  c(0.2,0.8),
      text = element_text(size = 20),
      axis.line = element_line(color = 'black', size = 1)
    ) 
  p
}

# Results APC trained on Librispeech
plot_developmental_trajectories("Model_Dev_Results/", "apc", 0.05, 0.06, 0.57)
apc_resutls = get_ids_effects_dataframe("Model_Dev_Results/", "apc", 0.05, 0.06, 0.57)
apc_resutls['capability'] = 'IDS Preference'
write_csv(apc_resutls, 'apc_results_ids.csv')

# Results APC trained on LibriSpeech and Spoken COCO
plot_developmental_trajectories("test_results_large_apc/", "apc", 0.05, 0.06, 0.57)
apc_resutls = get_ids_effects_dataframe("test_results_large_apc/", "apc", 0.05, 0.06, 0.57)
apc_resutls['capability'] = 'IDS Preference'
write_csv(apc_resutls, 'apc_large_results_ids.csv')
