# Import DNREC tag metadata
#   Adapted from dnrec_tag_info.R

import_dnrec_tag_info <- function(raw_dnrec_tags){
  tag_data <- read_excel(raw_dnrec_tags,
                         range = cell_cols('a:k'))
  setDT(tag_data)
  setnames(tag_data, function(.) tolower(gsub('[ #]', '', .)))
  
  
  # Clean up dates and age data
  tag_data[, ':='(age = as.integer(fifelse(age == '-', NA, age)),
                  date = as.Date(date))]
  
  
  # 53482 is listed twice as it was returned and re-implanted
  # 53985 is listed twice in error. The deployment on 2018-05-08 should be 53905
  #   (Communication with I Park, 2022-01-20)
  tag_data[acoustictag == 53985 & date == '2018-05-08', acoustictag := 53905]
  
  
  
  # Acoustic tags that start with 5 are 1601, those that start with 2 are 1602
  tag_data[, transmitter := fcase(
    grepl('^5', acoustictag), paste('A69-1601', acoustictag, sep = '-'),
    grepl('^2', acoustictag), paste('A69-1602', acoustictag, sep = '-')
  )]
  
  
  # Remove acoustictag and sizegroup columns
  tag_data[, ':='(acoustictag = NULL,
                  sizegroup = NULL)]
  
  
  # fwrite(tag_data, 'EMBARGO/derived/dnrec_tag_info.csv', dateTimeAs = 'write.csv')
  tag_data
}



# Import river detections
#   Adapted from a section of dnrec_detections.R

import_de_river_dets <- function(raw_dnrec_river_dets_dir){
  dnrec_dets <- list.files(raw_dnrec_river_dets_dir,
                        full.names = T)
  
  # Read all of the files into parts of a list
  dnrec_dets <- lapply(dnrec_dets, read_excel)
  
  # Convert the resulting list of tibbles into a list of data.tables
  dnrec_dets <- lapply(dnrec_dets, setDT)
  
  # Bind the list of data.tables into one big data.table
  dnrec_dets <- rbindlist(dnrec_dets)
  
  # Repair names
  setnames(dnrec_dets, function(.) tolower(gsub('and|UTC|[) ()]', '', .)))
  
  dnrec_dets
}



# Import coastal detections
#   Adapted from a section of dnrec_detections.R

import_de_coastal_dets <- function(raw_dnrec_coastal_dets_dir){
  # Bring in coastal detections
  xl_dets <- list.files(raw_dnrec_coastal_dets_dir,
                        full.names = T, pattern = 'xlsx')
  csv_dets <- list.files(raw_dnrec_coastal_dets_dir,
                         full.names = T, pattern = 'csv')
  
  vue_names <- c('datetime', 'receiver', 'transmitter', 'transmittername',
                 'transmitterserial','sensorvalue', 'sensorunit',
                 'stationname', 'latitude', 'longitude')
  
  # MATOS detections
  matos_dets <- xl_dets[grepl('proj', xl_dets)]
  matos_dets <- read_excel(matos_dets)
  setDT(matos_dets)
  
  matos_dets <- matos_dets[grepl('[Ss]triped', commonname)]
  matos_dets <- matos_dets[receiver != 'release']
  
  matos_dets <- matos_dets[, .(datecollected, receiver, tagname, sensorvalue,
                               sensorunit, station, latitude, longitude)]
  setnames(matos_dets, vue_names[c(1:3, 6:10)])
  
  
  # Received Excel detections
  xl_dets <- xl_dets[!grepl('proj', xl_dets)]
  xl_dets <- lapply(xl_dets, read_excel)
  
  xl_dets <- lapply(xl_dets, setDT)
  
  xl_dets <- rbindlist(xl_dets, fill = T)
  setnames(xl_dets, vue_names)
  
  
  # Received CSV detections
  csv_dets <- lapply(csv_dets, fread)
  csv_dets <- rbindlist(csv_dets)
  setnames(csv_dets, vue_names)
  
  coastal_dets <- rbindlist(list(matos_dets, xl_dets, csv_dets), fill = T)
  
  coastal_dets
}



# Join detection info and tag metadata together
#   Adapted from dnrec_detections.R

import_dnrec_detections <- function(dnrec_tags, dnrec_river_dets,
                                    dnrec_coastal_dets){
  
  # Bind river and coastal detections
  dnrec_dets <- rbindlist(list(dnrec_river_dets, dnrec_coastal_dets), fill = T)
  
  # 53482 was re-used on 2017-04-28 (see tag_data), so have to do some gymnastics
  #   to join with detections
  # Bind detection data before the second time 53482 was deployed to the associated
  #   tag data
  first_half <- dnrec_dets[datetime < as.POSIXct('2017-04-28 00:00:00', tz = 'UTC')]
  first_53482 <- dnrec_tags[!(grepl('53482', transmitter) & date == '2017-04-28')]
  
  first_half <- first_half[first_53482, on = 'transmitter', nomatch = 0]
  
  # Bind detection data after the second time 53482 was deployed to the associated
  #   tag data
  second_half <- dnrec_dets[datetime >= as.POSIXct('2017-04-28 00:00:00', tz = 'UTC')]
  second_53482 <- dnrec_tags[!(grepl('53482', transmitter) & date < '2017-04-28')]
  
  second_half <- second_half[second_53482, on = 'transmitter', nomatch = 0]
  
  
  # Put them together
  dnrec_dets <- rbind(first_half, second_half)
  
  
  # Repair station locations ----
  # "LL# 3685 Upper DE River CB 9" station is reported to be at -40 N, 0 W.
  #   Light list V2 lists this as 40-00-38.635N, 075-02-48.335W. Repair:
  dnrec_dets[stationname == "LL# 3685 Upper DE River CB 9"
          , ':='(latitude = 40 + 00 / 60 + 38.635 / 3600,
                 longitude = -75 - 02 / 60 - 48.335 / 3600)]
  
  # Some "NJDB004", "NJDB014", and "DE River Gate 1A" have positive longitudes.
  #   Striper should not be in the eastern hemisphere, so make longitudes negative
  dnrec_dets[, longitude := fifelse(longitude > 0, -longitude, longitude)]
  
  dnrec_dets[, latitude := abs(latitude)]
  
  # Some stations have NA lat/longs.
  #   Some of those are defined elsewhere in the data. Fix that here.
  no_location <- dnrec_dets[is.na(latitude) | is.na(longitude)]
  
  not_missing <- dnrec_dets[!(is.na(longitude) | is.na(latitude)) &
                           stationname %in% unique(no_location)$stationname]
  not_missing <- unique(not_missing, by = 'stationname')[, .(stationname, latitude, longitude)]
  
  dnrec_dets <- not_missing[dnrec_dets, on = 'stationname']
  dnrec_dets[, ':='(latitude = fifelse(is.na(latitude), i.latitude, latitude),
                 longitude = fifelse(is.na(longitude), i.longitude, longitude),
                 i.latitude = NULL,
                 i.longitude = NULL)]
  
  # Others have to be input manually
  ##  Provided by I Park on 2022-01-25; Hal Brundage receivers
  station_key <- data.table(
    stationname = c('Yardley Shoreline Structure', 'Scudders Falls Bridge West Channel',
                    'Scudders Falls Bridge East Channel', 'LL# 3255 Chester Range LB 6C',
                    'LL# 3315 Tinicum Island Range 3T'),
    latitude = c(40.2521, 40.2575, 40.2585, 39.8415, 39.85003),
    longitude = c(-74.8419, -74.8482, -74.8461, -75.34751, -75.29652)
  )
  
  ##  Looked up on UMCES tag returns. Light List numbers are no longer reliable
  ##    LL before 2018 are not available and NAVAIDS have changed since then.
  ## umces <- fread('embargo/derived/umces_tag_info_detections.csv')
  ## unique(umces[stationname %in% unique(dnrec_dets[is.na(longitude)]$stationname)],
  ##        by = c('stationname', 'latitude', 'longitude'))[, .(stationname, latitude, longitude)]
  station_key <- rbind(
    station_key,
    data.table(
      stationname = c('LL# 3030 Cherry Island Range Red 4C',
                      'LL# 3160 Marcus Hook Range LB 6M',
                      'LL# 3130 Marcus Hook Range LBB 2M',
                      'LL# 3255 Delaware River Lighted Buoy 52',
                      'LL# 3310 Delaware River Lighted Buoy 57',
                      'LL# 3105 Bellevue Range Buoy 4B',
                      'LL# 3180 Marcus Hook Anchorage Buoy B'),
      latitude = c(39.72789, 39.79545, 39.78186, 39.84130694, 39.85003194, 39.75653, 39.80326),
      longitude = c(-75.50123, -75.43331, -75.4575, -75.31914389, -75.2964675, -75.4827, -75.40299)
    )
  )
  
  ## Grabbed from the 2018 LL. Reasonably sure these are the same locations.
  station_key <- rbind(
    station_key,
    data.table(
      stationname = c('LL# 3920 Upper DE River CLB 36',
                      'LL# 4120 Upper DE River CB 66',
                      'LL# 4275 Upper DE River CB 92',
                      'LL# 3775 Upper DE River CLB 18'),
      latitude = c(40 + 4 / 60 + 27.399 / 3600,
                   40 + 7 / 60 + 10.096 / 3600,
                   40 + 9 / 60 + 39.595 / 3600,
                   40 + 1 / 60 + 42.102 / 3600),
      longitude = c(-74 - 53 / 60 - 51.098 / 3600,
                    -74 - 47 / 60 - 22.384 / 3600,
                    -74 - 43 / 60 - 17.176 / 3600,
                    -75 - 0 / 60 - 4.112 / 3600)
    )
  )
  
  ## Still missing "LL# 3255 Chester Range LB 6C"     "LL# 3315 Tinicum Island Range 3T"
  # N 39° 50' 59.307"	W 075° 15' 53.463
  # N 39° 51' 00.115"	W 075° 17' 47.283"	tinicum 3t
  
  # Buoy L is missing location data -- found it in the UMCES data.
  station_key <- rbind(
    station_key,
    data.table(
      stationname = 'Buoy L (Sandy Point)',
      latitude = 39.44099,
      longitude = -76.05331
    )
  )
  
  dnrec_dets <- station_key[dnrec_dets, on = 'stationname']
  dnrec_dets[, ':='(latitude = fifelse(is.na(latitude), i.latitude, latitude),
                 longitude = fifelse(is.na(longitude), i.longitude, longitude),
                 i.latitude = NULL,
                 i.longitude = NULL)]
  
  # Export data ----
  # Rename "date" to "tagdate"
  setnames(dnrec_dets, 'date', 'tagdate')
  
  
  dnrec_dets
}
