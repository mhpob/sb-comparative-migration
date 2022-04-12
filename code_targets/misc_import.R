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



make_station_key <- function(station_key){
  # import detections
  de_dets <- fread('embargo/derived/de_tag_info_detections.csv')
  de_dets <- unique(de_dets[, c('stationname', 'latitude', 'longitude')],
                    by = c('stationname', 'latitude', 'longitude'))
  
  setorder(de_dets, stationname)
  
  station_key_new <- merge(station_key, de_dets, all = T)
  
  setorder(station_key_new, stationname, latitude)
  
  station_key_new
  
  # Hand audit from here
}
