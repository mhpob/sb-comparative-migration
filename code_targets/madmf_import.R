# Import MA DMF tag metadata
#   Adapted from madmf_tag_info.R

import_madmf_tag_info <- function(raw_madmf_tags){
  tag_data <- read_xlsx(raw_madmf_tags)
  
  setDT(tag_data)
  setnames(tag_data, function(.) tolower(gsub('[#\\.)( ]', '', .)))
  
  
  
  tag_data[, ':='(date = as.Date(date),
                  transmitter = paste('A69-9001', actag, sep = '-'),
                  actag = NULL,
                  
                  # tlmm column is mislabeled -- units are cm, so convert to mm
                  tl = tlmm * 10,
                  tlmm = NULL,
                  
                  # combine all notes columns into one.
                  notes = fifelse(
                    !is.na(`12`),
                    gsub(', NA', '', paste(notes, `12`, `13`, sep = ', ')),
                    notes
                  ),
                  `12` = NULL,
                  `13` = NULL)]
  
  
  
  tag_data[grepl('\\d{2}', capturelocation),
           ':='(lat = gsub(' +\\d{2} \\d{2}.\\d{3}$', '', capturelocation),
                lon = gsub('^\\d{2} \\d{2}.\\d{3} +', '', capturelocation))]
  
  tag_data[grepl('\\d{2}', capturelocation),
           ':='(lat = as.numeric(gsub('.* ', '', lat)) / 60 +
                  as.numeric(gsub(' .*', '', lat)),
                lon = as.numeric(gsub('.* ', '', lon)) / 60 +
                  as.numeric(gsub(' .*', '', lon)))]
  
  tag_data
  
}
