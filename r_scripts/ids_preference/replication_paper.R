# Replication analysis "Quantifying Sources of Variability in Infancy Research 
# Using the Infant-Directed-Speech Preference", Frank, Alcock, Arias-Trejo et al., 2020
# THe code has been extracted from https://github.com/manybabies/mb1-analysis-public/blob/master/paper/mb1-paper.Rmd

library("papaja")
library(ggthemes)
library(lme4)
library(tidyverse)
library(here)
library(knitr)
library(kableExtra)
library(ggpubr)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# Basic meta-analysis to obtain mean effect size

d <- read_csv("MB1_data/03_data_trial_main.csv", 
              na = c("NA", "N/A")) %>%
  mutate(method = case_when(
    method == "singlescreen" ~ "Central fixation",
    method == "eyetracking" ~ "Eye tracking",
    method == "hpp" ~ "HPP",
    TRUE ~ method)) 
diffs <- read_csv("MB1_data/03_data_diff_main.csv",
                  na = c("NA", "N/A")) %>%
  mutate(method = case_when(
    method == "singlescreen" ~ "Central fixation",
    method == "eyetracking" ~ "Eye tracking",
    method == "hpp" ~ "HPP",
    TRUE ~ method)) 

ordered_ages <- c("3-6 mo", "6-9 mo", "9-12 mo", "12-15 mo")
d$age_group <- fct_relevel(d$age_group, ordered_ages)
diffs$age_group <- fct_relevel(diffs$age_group, ordered_ages)
source("MB1_data/helper/ma_helper.R")
ages <- d %>%
  group_by(lab, age_group, method, nae, subid) %>%
  summarise(age_mo = mean(age_mo)) %>%
  summarise(age_mo = mean(age_mo))
ds_zt <- diffs %>%
  group_by(lab, age_group, method, nae, subid) %>%
  summarise(d = mean(diff, na.rm = TRUE)) %>%
  group_by(lab, age_group, method, nae) %>%
  summarise(d_z = mean(d, na.rm = TRUE) / sd(d, na.rm = TRUE), 
            n = length(unique(subid)), 
            d_z_var = d_var_calc(n, d_z)) %>%
  filter(n >= 10) %>%
  left_join(ages) %>%
  filter(!is.na(d_z)) # CHECK THIS 

# Random-Effect Model 
intercept_mod <- metafor::rma(d_z ~ 1, 
                              vi = d_z_var, slab = lab, data = ds_zt, 
                              method = "REML") 

# Random-Effects Model (k = 108; tau^2 estimator: REML)
# 
# tau^2 (estimated amount of total heterogeneity): 0.0145 (SE = 0.0153)
# tau (square root of estimated tau^2 value):      0.1202
# I^2 (total heterogeneity / total variability):   12.39%
# H^2 (total variability / sampling variability):  1.14
# 
# Test for Heterogeneity:
#   Q(df = 107) = 122.0012, p-val = 0.1524
# 
# Model Results:
#   
#   estimate      se     zval    pval   ci.lb   ci.ub 
# 0.3535  0.0331  10.6671  <.0001  0.2885  0.4184  *** 
#   
#   ---
#   Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

# Funnel plot
metafor::funnel(intercept_mod, level=c(90, 95, 99), shade=c("white", "gray75", "gray55"), digits=2L, xlab = "Effect Size", cex.lab=1.3, cex.axis=1.3)
# Eeger's test
reg_nat <- metafor::regtest(intercept_mod)
se <- seq(0, 1.8, length=100)
lines(coef(reg_nat$fit)[1] + coef(reg_nat$fit)[2]*se, se, lwd=1, col="red", lty=2)

# Forest plot as in paper

ds_zt$age_mo_centered <- scale(ds_zt$age_mo, scale = FALSE)[,1]
age_mod <- metafor::rma(d_z ~ age_mo_centered, 
                        vi = d_z_var, slab = lab, data = ds_zt, method = "REML") 
lang_mod <- metafor::rma(d_z ~ nae, vi = d_z_var, 
                         slab = lab, data = ds_zt, method = "REML") 
method_mod <- metafor::rma(d_z ~ method, vi = d_z_var, 
                           slab = lab, data = ds_zt, method = "REML") 
# get fitted estimates for all labs
f <- fitted(intercept_mod)
p <- predict(intercept_mod)
alpha <- .05
forest_data <- data.frame(effects = as.numeric(intercept_mod$yi.f),
                          variances = intercept_mod$vi.f) %>%
  mutate(effects.cil = effects -
           qnorm(alpha / 2, lower.tail = FALSE) * sqrt(variances),
         effects.cih = effects +
           qnorm(alpha / 2, lower.tail = FALSE) * sqrt(variances),
         estimate = as.numeric(f),
         lab = factor(names(f)),
         estimate.cil = p$ci.lb,
         estimate.cih = p$ci.ub,
         inverse_vars = 1/variances,
         identity = 1, 
         lab = str_replace(lab, "\\.[1-9]",""), 
         index = 1:n()) %>%
  bind_cols(ungroup(ds_zt) %>% select(lab, method))

# Fix: For some reason, there is a rename of lab to lab..6 and lab..12 which causes problems
# for the plot. 
forest_data$lab <- forest_data$lab...6
drop <- c('lab...6', 'lab...12') 
forest_data <- forest_data[, !(names(forest_data) %in% drop)]
forest_data$lab <- as.factor(forest_data$lab)

# predict MA means for methods
mf <- fitted(method_mod)
mp <- predict(method_mod,
              newmods = t(cbind(c(0,0), # intercept - central fixation
                                c(1,0), # eye-tracking
                                c(0,1))), # HPP
              intercept = TRUE)
# Add meta-analytic estimate
forest_data <- bind_rows(forest_data,
                         data_frame(lab = "Meta-analytic estimate",
                                    method = "",
                                    effects = summary(intercept_mod)$b[1],
                                    effects.cil = summary(intercept_mod)$ci.lb,
                                    effects.cih = summary(intercept_mod)$ci.ub),
                         data_frame(lab = "Meta-analytic estimate",
                                    method = c("Central fixation","Eye tracking",
                                               "HPP"),
                                    effects = mp$pred,
                                    effects.cil = mp$ci.lb,
                                    effects.cih = mp$ci.ub)) %>%
  mutate(method = fct_rev(fct_relevel(method, "")),
         lab = fct_relevel(lab, "Meta-analytic estimate")) 
# plot
ggplot(forest_data, aes(x = lab, y = effects)) + 
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey") +
  geom_linerange(aes(ymin = effects - sqrt(variances)*1.96,
                     ymax = effects + sqrt(variances)*1.96, 
                     group = index),
                 alpha = .5,
                 position = position_dodge(width = .5)) +
  geom_point(data = filter(forest_data, lab != "Meta-analytic estimate"),
             aes(y = effects, size = inverse_vars, col = method, 
                 group = index), 
             alpha = .5, 
             position = position_dodge(width = .5)) +
  geom_point(data = filter(forest_data, lab == "Meta-analytic estimate"),
             pch = 5) +
  geom_linerange(data = filter(forest_data, lab == "Meta-analytic estimate"),
                 aes(ymin = effects.cil, ymax = effects.cih), 
                 alpha = .5) +
  facet_grid(method ~ ., scales = "free", space = "free") +
  coord_flip() +
  scale_size_continuous(guide = "none") +
  scale_colour_ptol(guide = "none") +
  xlab("Lab") +
  ylab("Effect Size") +
  theme(axis.text.y = element_text(size = 6))


# Native vs Non-native language plot as in paper
ds_zt$english <- factor(ds_zt$nae, levels = c(TRUE, FALSE), 
                        labels = c("North American English", "Non-North American English")) 
ggplot(ds_zt, 
       aes(x = age_mo, y = d_z)) + 
  geom_point(aes(size = n, col = method), alpha = .3) + 
  geom_linerange(aes(ymin = d_z - 1.96 * sqrt(d_z_var), 
                     ymax = d_z + 1.96 * sqrt(d_z_var), col = method)) + 
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey") +
  geom_smooth(method = "lm") + 
  facet_grid(~english) + 
  scale_colour_ptol(name = "Method") +
  scale_size_continuous(guide = "none") +
  xlab("Mean Age (Months)") +
  ylab("Effect Size") + 
  theme(legend.position = "bottom")

# Linear Mixed-Effect model as in paper
library(lmerTest)
d_lmer <- d %>%
  filter(trial_type != "train") %>%
  mutate(log_lt = log(looking_time),
         age_mo = scale(age_mo, scale = FALSE),
         trial_num = trial_num, 
         item = paste0(stimulus_num, trial_type)) %>%
  filter(!is.na(log_lt), !is.infinite(log_lt))

mod_lmer <- lmer(log_lt ~ trial_type * method +
                   trial_type * trial_num +
                   age_mo * trial_num +
                   trial_type * age_mo * nae +
                   (1 | subid_unique) +
                   (1 | item) + 
                   (1 | lab), 
                 data = d_lmer)

coefs <- summary(mod_lmer)$coef %>%
  as_tibble %>%
  mutate_at(c("Estimate","Std. Error","df", "t value", "Pr(>|t|)"), 
            function (x) signif(x, digits = 3)) %>%
  rename(SE = `Std. Error`, 
         t = `t value`,
         p = `Pr(>|t|)`) %>%
  select(-df)


rownames(coefs) <- c("Intercept", "IDS", "Eye-tracking", "HPP", 
                     "Trial #", "Age", "NAE", "IDS * Eye-tracking", 
                     "IDS * HPP", 
                     "IDS * Trial #", "Trial # * Age", "IDS * Age", "IDS * NAE", 
                     "Age * NAE", "IDS * Age * NAE")
papaja::apa_table(coefs, 
                  caption = "Coefficient estimates from a linear mixed effects model predicting log looking time.", 
                  format.args = list(digits = 3),
                  col.names =c("","Estimate","$SE$","$t$","$p$"),
                  align=c("l","l","c","c","c"))


# Simple trends of IDS preference by age (diff as a function of age)
mss_diffs <- diffs %>%
  group_by(lab, method, nae, subid) %>%
  summarise(n = sum(!is.na(diff)),  # Trials per infant
            age_mo = mean(age_mo), 
            diff = mean(diff, na.rm=TRUE))

mss_diffs_plot_b <- ggplot(mss_diffs, aes(x = age_mo, y = diff, col = method, lty = nae)) + 
  geom_smooth(method = "lm", se=FALSE) + 
  geom_hline(yintercept = 0, lty = 2) + 
  ylab("IDS preference (s)") + 
  scale_color_ptol(name = "Method") + 
  scale_linetype(name = "North American English") + 
  xlab("Age (Months)") +
  theme(legend.title=element_text(size=10),legend.text=element_text(size=8))

mss_diffs_plot_a <-mss_diffs_plot_b +
  geom_point(data = filter(mss_diffs, n == 8), alpha = .1) 

ggarrange(mss_diffs_plot_a, mss_diffs_plot_b, labels = c("A", "B"), ncol = 2, nrow = 1, legend = "bottom", common.legend = TRUE)


# Developmental curve 
ds_zt_nae <- filter(ds_zt, english=='North American English')

# Basic linear model d ~ 1 + age
# For reference to comparison with models (computational evaluation paper)
ggplot(ds_zt_nae, 
       aes(x = age_mo, y = d_z)) + 
  geom_point(aes(size = n), alpha = .3) + 
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey") +
  geom_smooth(method = "lm", colour="blue", size=0.9, se=TRUE, fill="grey70") + 
  scale_size_continuous(guide = "none") +
  scale_y_continuous(expand = c(0, 0), limits = c(-1, 2.3),
                       breaks = seq(-1, 2.3, 1)) +
  coord_cartesian(clip = "off") +
  xlab("\nMean Age (Months)") +
  ylab("Effect Size\n") + 
  theme(legend.position = "right", text = element_text(size=18), 
        axis.line = element_line(color='black', size=1)) +
  labs(colour="")















