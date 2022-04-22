function(combined_tags){
  
  
  summary(xtabs(~ yr + age, data = de_tagging_data[yr != 2017]))
  
  library(ggplot2)
  ggplot(data = de_tagging_data) +
    geom_bar(aes(x = sex, fill = yr))
  
  ggplot(data = de_tagging_data) +
    geom_histogram(aes(x = totallength)) +
    facet_wrap(~ yr)
  
  ggplot(data = de_tagging_data) +
    geom_histogram(aes(x = age)) +
    facet_wrap(~ yr)
  
  
  
  library(ggplot2)
  ggplot(de_dets) +
    geom_density(aes(x = totallength, y = ..count.., color = sex))
}
