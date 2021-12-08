# IDS preference test
# Calculation of effect size based on attentional preference scores 
# from APC and CPC models. 

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

apc_d <- calculate_standardised_mean_gain("Model_Results/apc_attentional_preference_scores.csv")
apc_untrained_d <- calculate_standardised_mean_gain("Model_Results/apc_untrained_attentional_preference_scores.csv")
cpc_d <- calculate_standardised_mean_gain("Model_Results/cpc_attentional_preference_scores.csv")
cpc_untrained_d <- calculate_standardised_mean_gain("Model_Results/cpc_untrained_attentional_preference_scores.csv")

# effect sizes plots

significant_p = 0.05
apc_0 = if (apc_untrained_d$'p-value' <= significant_p) 's.' else 'n.s.'
apc_100 = if (apc_d$'p-value' <= significant_p) 's.' else 'n.s.'
cpc_0 = if (cpc_untrained_d$'p-value' <= significant_p) 's.' else 'n.s.'
cpc_100 = if (cpc_d$'p-value' <= significant_p) 's.' else 'n.s.'

# ES comparison with infants' ES
labels_significance = c('n.s.'="", 's.'="*")
es_data <- data.frame(d = c(apc_d$d, cpc_d$d, 0.43),
                      source = c('APC', 'CPC', 'Infants'),
                      lb = c(NA, NA, 0.33),
                      ub = c(NA, NA, 0.53),
                      significance = factor(c(apc_100, cpc_100, 's.'), labels=labels_significance))
lb_infants = es_data[es_data$source=='Infants']$lb

q=ggplot(es_data, aes(y=d, x=source, ymin=lb, ymax=ub, label = significance)) +
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
  #Add a vertical dashed line indicating an effect size of zero, for reference
  geom_hline(yintercept=lb_infants, color='red', linetype='dashed') + 
  # Red region: umcompatible region
  geom_rect(mapping = aes(xmin=-Inf, xmax=Inf, ymin=-Inf, ymax=lb_infants), 
            fill='red', alpha=0.2)

q + theme(legend.position = "none", text = element_text(size=18), 
          axis.line = element_line(color='black', size=1))

# Development of ES (0-100 h training)

es_dev <- data.frame(hours = c('0', '100', '0', '100'),
                     d = c(apc_untrained_d$d, apc_d$d, cpc_untrained_d$d, cpc_d$d),
                     significance = factor(c(apc_0, apc_100, cpc_0, cpc_100), labels=labels_significance),
                     pos_label_x = c(-0.1,0.08,-0.1, 0.08),
                     pos_label_y = c(-0.1,0.02,0.01, 0.02),
                     model = c('APC', 'APC', 'CPC', 'CPC'))
pos_label_x <- es_dev$pos_label_x
pos_label_y <- es_dev$pos_label_y
p=ggplot(es_dev, aes(y=d, x=hours, group=model, colour=model, 
                     linetype=model, label=significance)) +
  #Add data points and color them black
  geom_point(colour = 'black', size=3, shape=16) +
  geom_text(size=10, nudge_x = pos_label_x, nudge_y = pos_label_y, show.legend = FALSE) +
  scale_y_continuous(expand = c(0, 0), limits = c(-1, 2.3),
                       breaks = seq(-1, 2.3, 1)) +
  coord_cartesian(clip = "off") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey") +
  #Give y-axis a meaningful label
  xlab('\nInput duration (hours)') +
  ylab('Effect size\n') +
  geom_smooth(se=FALSE, method=lm)

p + theme(legend.position = c(0.2, 0.8), text = element_text(size=18), 
          axis.line = element_line(color='black', size=1)) +
  labs(colour='Model', linetype='Model')


