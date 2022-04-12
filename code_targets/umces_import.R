# Import UMCES tag metadata
#   Adapted from umces_tag_info.R

import_umces_tag_info <- function(raw_umces_asmfc_tags, raw_umces_boem_tags,
                                  raw_umces_hrf_tags){
  # Potomac 2014 - 2018 (ASMFC)
  asmfc <- fread(raw_umces_asmfc_tags,
                 na.strings = c('', 'NA'),
                 col.names = function(.) tolower(gsub('[) (,/]', '', .)))
  asmfc[, ':='(tagdate = as.Date(tagdate, '%m/%d/%Y'),
               tl = lengthtlmm,
               wgt = weightkg,
               exttag = floytagid,
               age = agescale)]
  asmfc[, ':='(location = fifelse(tagdate < '2014-05-01', 'Potomac, Newburg',
                                  'Potomac, Pt Lookout'),
               wgt = wgt * 1000)]
  asmfc <- asmfc[, .(tagdate, transmitter, exttag, tl, wgt, sex,
                     age, location)]
  
  # A69-1601-25465 reused
  
  # Potomac / MA Coast 2017 - (BOEM)
  boem <- fread(raw_umces_boem_tags,
                na.strings = '',
                col.names = function(.) tolower(gsub('\n|[) (,/]', '', .)))
  boem[, ':='(tagdate = as.Date(as.character(tagdate), '%Y%m%d'),
              tl = lengthtlmm,
              wgt = weightkg,
              transmitter = tagid,
              exttag = exttagid)]
  boem[, wgt := wgt * 1000]
  boem[grepl('\\d', location), ':='(location = 'MA Coast',
                                    lat = as.numeric(gsub(',.*', '', location)),
                                    lon = as.numeric(gsub('.*\\s', '', location)))]
  boem <- boem[, .(tagdate, transmitter, exttag, tl, wgt, sex, location, lat, lon)]
  
  
  # Hudson 2016 - 2019 (HRF)
  hrf <- fread(raw_umces_hrf_tags,
               na.strings = 'n/a',
               col.names = tolower)
  hrf[, ':='(tagdate = as.Date(tagdate, '%m/%d/%Y'),
             location = paste('Hudson,', location),
             wgt = weight,
             sex = fifelse(sex == 'Male', 'M', 'F'))]
  hrf <- hrf[, .(tagdate, transmitter, location, tl, wgt, sex)]
  
  
  tag_info <- rbind(asmfc, hrf, boem, fill = T)
  
  tag_info
  
}



# Import UMCES detection data
#   Adapted from umces_detections.R

import_umces_detections <- function(raw_umces_dets, umces_tags){
  all_files <- raw_umces_dets
  
  # Drop raw MATOS files (they start with proj)
  all_files <- all_files[!grepl('MATOS/proj', all_files)]
  
  
  # Make cluster for parallel import
  cl <- makeCluster(detectCores(logical = F))
  clusterEvalQ(cl, library(data.table))
  
  # Parallel import
  all_dets <- parLapply(cl, all_files, fread, fill = T)
  
  # Close cluster
  stopCluster(cl)
  
  
  # Name list with filenames (helps keep track when we get to rbindlist)
  names(all_dets) <- all_files
  
  # Remove empty datasets
  have_dets <- sapply(all_dets, nrow) > 0
  all_dets <- all_dets[have_dets]
  
  # Bind data into one data.table
  all_dets <- rbindlist(all_dets, fill = T, idcol = 'file')
  
  # Rename
  setnames(all_dets, function(.) tolower(gsub('and|UTC|[) ()]', '', .)))
  
  # Pick useful columns
  all_dets <- all_dets[, .(file, datetime, receiver, transmitter, sensorvalue,
                           stationname, latitude, longitude)]
  
  # Remove (some) redundant detections
  #   Note that MATOS/OTN time correct their files. This means that some detections are
  #   "redundant" but have different times
  all_dets <- unique(all_dets, by = c('datetime', 'receiver', 'transmitter'))
  
  
  # Import tag info
  tag_info <- umces_tags
  setnames(tag_info, c('lat', 'lon'), c('taglat', 'taglon'))
  
  # Transmitter A69-1601-25465 was returned to us on 2014-06-10 and reused on 
  #   2014-10-30. Separate out the tagging info accordingly and join onto the tagging
  #   data.
  no_25465 <- all_dets[!grepl('25465', transmitter)][tag_info, on = 'transmitter', nomatch = 0]
  
  first_25465 <- all_dets[grepl('25465', transmitter) & datetime <= '2014-06-10'][
    tag_info[tagdate < '2014-10-30'], on = 'transmitter', nomatch = 0]
  first_25465[, transmitter := paste0(transmitter, 'a')]
  
  second_25465 <- all_dets[grepl('25465', transmitter) & datetime >= '2014-10-30'][
    tag_info[tagdate >= '2014-10-30'], on = 'transmitter', nomatch = 0]
  second_25465[, transmitter := paste0(transmitter, 'b')]
  
  # Bind everything back together
  dets_info <- rbind(no_25465, first_25465, second_25465)
  
  dets_info
  
}
