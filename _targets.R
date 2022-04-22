library(targets)
library(tarchetypes)
library(future)

source('_targets_code/dnrec_import.R')
source('_targets_code/umces_import.R')
source('_targets_code/madmf_import.R')
source('_targets_code/misc_import.R')
source('_targets_code/summary_stats_plots.R')

# Set target-specific options such as packages.
tar_option_set(packages = c("data.table", 'readxl', 'ggplot2',
                            'emmeans', 'lubridate'))


plan(
  multisession,
  workers = availableCores(logical = F)
)

# End this file with a list of target objects.
list(
  # UMCES data
  ##  Tag metadata
  tar_target(raw_umces_asmfc_tags, 'embargo/raw/umces/taggingdata.csv',
             format = 'file'),
  tar_target(raw_umces_boem_tags, 'embargo/raw/umces/wea tagging data.csv',
             format = 'file'),
  tar_target(raw_umces_hrf_tags, 'embargo/raw/umces/sb sonic tags 2016.csv',
             format = 'file'),
  tar_target(raw_umces_hrf_ages, 'embargo/raw/umces/2016_Hudson_SB_consensus ages.xlsx',
             format = 'file'),
  tar_target(umces_tags, import_umces_tag_info(raw_umces_asmfc_tags,
                                               raw_umces_boem_tags,
                                               raw_umces_hrf_tags,
                                               raw_umces_hrf_ages)),
  
  ##  Detections
  tar_files_input(raw_umces_dets, file_batcher('p:/obrien/biotelemetry/detections'),
                  batches = 50,
                  format = 'file',
                  resources = tar_resources(
                    future = tar_resources_future(
                      plan = plan(
                        multisession,
                        workers = availableCores(logical = F)
                      )
                    )
                  )
  ),
  
  tar_target(umces_dets_all, import_umces_detections(raw_umces_dets, umces_tags),
             pattern = map(raw_umces_dets), format = 'feather',
             resources = tar_resources(
               future = tar_resources_future(
                 plan = plan(
                   multisession,
                   workers = availableCores(logical = F)
                   )
                 )
               )
             ),
  tar_target(umces_dets_trim,
             unique(umces_dets_all, by = c('stationname', 'datetime', 'transmitter'))),
  
  # DNREC data
  ##  Tag metadata
  tar_target(raw_dnrec_tags, 'embargo/raw/dnrec/de tag data.xlsx', format = 'file'),
  tar_target(dnrec_tags, import_dnrec_tag_info(raw_dnrec_tags)),
  
  ##  Detections
  tar_target(raw_dnrec_river_dets_dir, 'embargo/raw/dnrec/de detection data',
             format = 'file'),
  tar_target(dnrec_river_dets, import_de_river_dets(raw_dnrec_river_dets_dir)),
  
  tar_target(raw_dnrec_coastal_dets_dir, 'embargo/raw/dnrec/coastal detections',
             format = 'file'),
  tar_target(dnrec_coastal_dets, import_de_coastal_dets(raw_dnrec_coastal_dets_dir)),
  
  ##  All
  tar_target(dnrec_dets, import_dnrec_detections(dnrec_tags, dnrec_river_dets,
                                                 dnrec_coastal_dets),
             format = 'feather'),
  
  
  
  # MADMF data
  ##  Tag metadata
  tar_target(raw_madmf_tags, 'embargo/raw/madmf/dmf releases for ds coastal migrations 1_22.xlsx',
             format = 'file'),
  tar_target(madmf_tags, import_madmf_tag_info(raw_madmf_tags)),
  
  
  
  # Other
  ##  Combined tag info
  tar_target(combined_tags, combine_tag_info(dnrec_tags, umces_tags, madmf_tags)),
  
  ## station key
  tar_target(original_station_key, 'data/station_key.csv', format = 'file'),
  tar_target(station_key, make_station_key(original_station_key, dnrec_dets)),
  
  ## Combined detection info
  tar_target(combined_dets, combine_detections(umces_dets_trim,
                                               dnrec_dets, station_key),
             format = 'feather'),
  
  # Reports
  tar_render(first_data_comparisons, '_targets_Notebooks/initial_comparison.rmd'),
  tar_render(second_data_comparisons, '_targets_Notebooks/comparisons_continued.rmd'),
  tar_render(MA_arrival_timing, '_targets_Notebooks/arrival-timing.rmd')
  
)
