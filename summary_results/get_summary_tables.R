# This script processes the meta-analyses data to build comparative matrices
# 1) is there evidence of an effect for age range X?
# 2) how many effects were used for the point estimate?

library(tidyverse)
library(lme4)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
setwd('../r_scripts/ids_preference/')
source('./replication_analyses.R')
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
setwd('../r_scripts/vowel_discrimination/')
source('./replication_analyses.R')
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))


# Checkpoints 960 h of speech
months <- c(0:9) * 0.06 # 1.73
months <- c(months, c(1:18)*0.57) #* 17.3, 9 * 17.3 + 10.3)
checkpoints = data.frame(age_mo = months)

# IDS preference
ids_mo = 30.4375 # according to meta-analysis
# ds_zt_nae <- ds_zt_nae %>% mutate(age_days=age_mo*ids_mo)
ids_lm = lm(d_z~age_mo, data = ds_zt_nae)

ids_checkpoints = predict(ids_lm, checkpoints, interval = 'confidence')

# Vowel preference 
# age not significant, effect size = mean effect for all age ranges
vowel_mo = 30.42
vowelnat_checkpoints = matrix(
  rep(c(mean_es_nat, mean_es_nat_ci.lb, mean_es_nat_ci.ub),
      each=nrow(checkpoints)), 
  nrow=nrow(checkpoints))

vowelnonnat_checkpoints = matrix(
  rep(c(mean_es_nonnat, mean_es_nonnat_ci.lb, mean_es_nonnat_ci.ub),
      each=nrow(checkpoints)), 
  nrow=nrow(checkpoints))

# Number of effects used to calculate the point estimate
# centred within 3-mo range

# IDS preference & Vowel discrimination
ids_final = c()
vnat_final = c()
vnonnat_final = c()

df_lower_bound = data.frame(matrix(ncol=length(months)+1, nrow = 0))

column_names = c('Capability')
for (stage in months){
  column_names = c(column_names, as.character(stage))
}

colnames(df_lower_bound) <- column_names


for(i in 1:length(months)){
  checkpoint = months[i]
  # IDS preference
  ids_age_range = ds_zt_nae %>% 
    group_by() %>% 
    summarise(min=min(age_mo), max=max(age_mo))
  
  df_lower_bound[1,1] = 'IDS Preference'
  
  if(ids_age_range['min']> checkpoint || ids_age_range['max']<checkpoint){
    ids_final = c(ids_final, 'N/A') # Out of age range of the meta-analysis
    df_lower_bound[1,i+1] = 'N/A'
  }else if(sign(ids_checkpoints[i,2]) != sign(ids_checkpoints[i,3])){
    ids_final = c(ids_final, 'n.s.') # No significant effect
    df_lower_bound[1, i+1] = 'n.s.'
  }else{
    ids_final = c(ids_final, ids_checkpoints[i,1])
    if(ids_checkpoints[i,1]<0){
      df_lower_bound[1,i+1] = ids_checkpoints[i,3]  
    }else{
      df_lower_bound[1,i+1] = ids_checkpoints[i,2]  
    }
  }
  
  # Vowel disc. nat.
  vowel_nat_age_range = nat_vowels %>% 
    group_by() %>%
    summarise(min=min(mean_age_1/vowel_mo), max=max(mean_age_1/vowel_mo))
  
  df_lower_bound[2,1] = 'Vowel discr. (native)'
  
  if(vowel_nat_age_range['min']>checkpoint || 
     vowel_nat_age_range['max']<checkpoint){
    vnat_final = c(vnat_final, 'N/A')
    df_lower_bound[2, i+1] = 'N/A'
  }else if(sign(vowelnat_checkpoints[i,2]) != sign(vowelnat_checkpoints[i,3])){
    vnat_final = c(vnat_final, 'n.s.') 
    df_lower_bound[2, i+1] = 'n.s.'
  }else{
    vnat_final = c(vnat_final, vowelnat_checkpoints[i,1])
    if(vowelnat_checkpoints[i,1]<0){
      df_lower_bound[2, i+1] = vowelnat_checkpoints[i,3]  
    }else{
      df_lower_bound[2, i+1] = vowelnat_checkpoints[i,2]
    }
    
  }
  
  # Vowel disc. nonnat.
  vowel_nonnat_age_range = nonnat_vowels %>% 
    group_by() %>%
    summarise(min=min(mean_age_1/vowel_mo), max=max(mean_age_1/vowel_mo))
  
  df_lower_bound[3,1] = 'Vowel discr. (non-native)'
  
  if(vowel_nonnat_age_range['min']>checkpoint || 
     vowel_nonnat_age_range['max']<checkpoint){
    vnonnat_final = c(vnonnat_final, 'N/A')
    df_lower_bound[3, i+1] = 'N/A'
  }else if(sign(vowelnonnat_checkpoints[i,2]) != sign(vowelnonnat_checkpoints[i,3])){
    vnonnat_final = c(vnonnat_final, 'n.s.') 
    df_lower_bound[3, i+1] = 'n.s.'
  }else{
    vnonnat_final = c(vnonnat_final, vowelnonnat_checkpoints[i,1])
    if(vowelnonnat_checkpoints[i,1]<0){
      df_lower_bound[3, i+1] = vowelnonnat_checkpoints[i,3]  
    }else{
      df_lower_bound[3, i+1] = vowelnonnat_checkpoints[i,2]
    }
    
  }
}

ids_final = c('IDS Preference', ids_final)
vnat_final = c('Vowel discr. (native)', vnat_final)
vnonnat_final = c('Vowel discr. (non-native)', vnonnat_final)
final_matrix = rbind(ids_final, vnat_final, vnonnat_final)

# Formatting
colnames(final_matrix) <- column_names

write.csv(df_lower_bound, './summary_table_lb.csv', row.names = FALSE)
write.csv(final_matrix, './summary_table_es.csv', row.names = FALSE)

# Append APC results
apc_vowel = read.csv('../metaeval_experiments/r_scripts/vowel_discrimination/apc_large_results_vowel_discr.csv')
apc_ids = read.csv('../metaeval_experiments/r_scripts/ids_preference/apc_large_results_ids.csv')
apc_results = rbind(apc_ids, apc_vowel)
write_csv(apc_results, './apc_results.csv')

