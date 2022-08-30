# This script calculates the developmental IDS preference trajectory of the 
# model and overlaps it with the infant trajectory.


library(tidyverse)
library(ggplot2)

options(dplyr.summarise.inform = FALSE)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

source('obtain_effect_sizes.R')
source('replication_analyses.R')

obtain_ids_effects_for_all_epochs <- function(folder, model) {
  es_epochs <- list()
  # identifier of first 10 h speech checkpoints
  steps = c(0, 562, 1125, 1688, 2251, 2814, 3377, 3940, 4503, 5066)
  steps = c(steps, 1:10) # identifiers of 100 h speech checkpoints
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
  return (es_epochs)
}

get_ids_effects_dataframe <- function(folder, model, alpha) {
  effects_list <- obtain_ids_effects_for_all_epochs(folder, model)
  ds <- c()
  p_values <- c()
  total_steps <- length(effects_list)
  for (epoch in 1:total_steps) {
    ds <- c(ds, effects_list[[epoch]]$d)
    p_values <- c(p_values, effects_list[[epoch]]$'p-value')
  }
  
  days <- c(0:9) * 1.73  # days represented by 10 hours of speech
  days <-
    c(days, c(1:9) * 17.3, 9 * 17.3 + 10.3) # total days represented by 960 hours of speech. last chunk only contains 60 hours of speech
  
  checkpoint <- rep("batch", 9)
  checkpoint <- c("epoch", checkpoint, rep("epoch", 10))
  
  df <- data.frame(
    days = days,
    d = ds,
    significant = p_values <= alpha,
    checkpoint = checkpoint
  )
  return (df)
}


plot_developmental_trajectories <- function(folder, model, alpha) {
  model_effects <- get_ids_effects_dataframe(folder, model, alpha)
  ds_zt_nae <- ds_zt_nae %>% mutate(age_days=age_mo*30.4375) # according to scale used in the original data
  
  p = ggplot(ds_zt_nae,
             aes(x = age_days, y = d_z)) +
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
    geom_smooth(
      method = "lm",
      colour = "#F8766D",
      se = FALSE,
      data = model_effects,
      aes(x= days, y = d, color="#F8766D")
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
    ) +
    scale_size_continuous(guide = "none") +
    scale_y_continuous(
      expand = c(0, 0),
      limits = c(-1, 2.3),
      breaks = seq(-1, 2.3, 1)
    ) +
    coord_cartesian(clip = "off") +
    xlab("\nSimulated Model Age / Real Infant Age (Days)") +
    ylab("Effect Size (d)\n") +
    theme(
      legend.position =  c(0.2,0.8),
      text = element_text(size = 20),
      axis.line = element_line(color = 'black', size = 1)
    ) 
  p
}

plot_developmental_trajectories("Model_Dev_Results/", "apc", 0.05)
apc_resutls = get_ids_effects_dataframe("Model_Dev_Results/", "apc", 0.05)
apc_resutls['capability'] = 'IDS Preference'
write_csv(apc_resutls, 'apc_results_ids.csv')
