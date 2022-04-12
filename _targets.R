library(targets)
library(tarchetypes)

source('code_targets/dnrec_import.R')
source('code_targets/umces_import.R')
source('code_targets/madmf_import.R')
source('code_targets/misc_import.R')

# Set target-specific options such as packages.
tar_option_set(packages = c("data.table", 'parallel', 'readxl', 'ggplot2'))

# End this file with a list of target objects.
list(
  # UMCES data
  ##  Tag metadata
  tar_target(raw_umces_asmfc_tags, 'embargo/raw/umces/taggingdata.csv', format = 'file'),
  tar_target(raw_umces_boem_tags, 'embargo/raw/umces/wea tagging data.csv', format = 'file'),
  tar_target(raw_umces_hrf_tags, 'embargo/raw/umces/sb sonic tags 2016.csv', format = 'file'),
  tar_target(umces_tags, import_umces_tag_info(raw_umces_asmfc_tags,
                                               raw_umces_boem_tags,
                                               raw_umces_hrf_tags)),
  
  ##  Detections
  tar_files_input(raw_umces_dets,
             list.files('p:/obrien/biotelemetry/detections', full.names = T,
                        recursive = T, pattern = '*.csv'), batches = 50,
             format = 'file'),
  tar_target(umces_dets, import_umces_detections(raw_umces_dets, umces_tags),
             format = 'feather'),

  
  
  # DNREC data
  ##  Tag metadata
  tar_target(raw_dnrec_tags, 'embargo/raw/dnrec/de tag data.xlsx', format = 'file'),
  tar_target(dnrec_tags, import_dnrec_tag_info(raw_dnrec_tags)),
  
  ##  Detections
  tar_target(raw_dnrec_river_dets_dir, 'embargo/raw/dnrec/de detection data', format = 'file'),
  tar_target(dnrec_river_dets, import_de_river_dets(raw_dnrec_river_dets_dir)),
  
  tar_target(raw_dnrec_coastal_dets_dir, 'embargo/raw/dnrec/coastal detections', format = 'file'),
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
  tar_target(combined_tags, combine_tag_info(dnrec_tags, umces_tags, madmf_tags))
  
  
  
  # Tag summaries
  
)
