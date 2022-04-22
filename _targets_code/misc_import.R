combine_tag_info <- function(dnrec_tags, umces_tags, madmf_tags){
  de_t <- copy(dnrec_tags)
  um_t <- copy(umces_tags)
  ma_t <- copy(madmf_tags)
  
  # Align desired column names
  setnames(de_t,
           c('date', 'totallength', 'tagginglocation', 'tbartag', 'fish'),
           c('tagdate', 'tl', 'taglocation', 'exttag', 'fishid'))
  setnames(ma_t,
           c('date', 'capturelocation'), 
           c('tagdate', 'taglocation'))
  setnames(um_t, 'location', 'taglocation')
  
  
  de_t[, system := 'DE']
  ma_t[, system := 'MA Coast']
  um_t[, system := fcase(grepl('Pot|Pt', taglocation), 'Potomac',
                          grepl('Hud', taglocation), 'Hudson',
                          grepl('MA', taglocation), 'MA Coast')]
  
  all_info <- rbind(de_t, ma_t, um_t, fill = T)
  
  all_info 
}

combine_detections <- function(umces_dets, dnrec_dets, station_key){
  library(data.table); library(lubridate)
  umces <- copy(umces_dets)
  
  # At this point, it seems that all of the MA-tagged fish are Hudson in origin
  umces <- umces[location == 'MA Coast', group := 'HR']
  umces[location != 'MA Coast', group := fifelse(grepl('1303', transmitter), 'HR', 'PR')]
  
  dnrec <- copy(dnrec_dets)
  dnrec[, group := 'DE']
  dnrec[, tl := totallength]
  
  dets <- rbind(umces, dnrec, fill = T)
  
  dets <- dets[datetime %between% c('2016-01-01', '2020-01-01')]
  
  station_key <- station_key[complete.cases(station_key[, c('array', 'stationname')])]
  dets <- station_key[, c('array', 'stationname')][dets, on = 'stationname']
  dets <- dets[array != 'FALSE_DET',]
  dets <- dets[!is.na(latitude)]
  
  dets[, ':='(hr = floor_date(datetime, 'hour'),
              day = floor_date(datetime, 'day'),
              year = year(datetime),
              yday = yday(datetime))]
  
  dets
}

make_station_key <- function(original_station_key, dnrec_dets){
  # import detections
  de_dets <- dnrec_dets
  de_dets <- unique(de_dets[, c('stationname', 'latitude', 'longitude')],
                    by = c('stationname', 'latitude', 'longitude'))
  
  setorder(de_dets, stationname)
  
  station_key <- fread(original_station_key)
  station_key_new <- merge(station_key, de_dets, all = T)
  
  setorder(station_key_new, stationname, latitude)
  
  station_key_new
  
  # Hand audit from here
}


file_batcher <- function(dirs){
  det_files <- list.files(dirs, full.names = T,
                          recursive = T, pattern = '*.csv')
  det_files <- data.table::data.table(file = det_files, mtime = file.mtime(det_files))

  data.table::setorder(det_files, mtime)

  # n <- nrow(det_files)
  # det_files <- det_files$file
  # det_files <- split(det_files, rep(1:ceiling(n / 50), each = 50)[1:n])
  
  det_files$file
}
