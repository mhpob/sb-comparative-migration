library(targets)
job::job({tar_make_future(workers = parallel::detectCores(logical = F))})
