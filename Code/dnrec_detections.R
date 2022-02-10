library(readxl); library(data.table)

# Import tagging data ----
tag_data <- fread('EMBARGO/derived/dnrec_tag_info.csv')



# Import detection data ----
# Detection files have been split into a suite of XLSX files in sex-by-length groups.

# Find the location of all the files
de_dets <- list.files('embargo/raw/dnrec/de detection data',
                      full.names = T)

# Read all of the files into parts of a list
de_dets <- lapply(de_dets, read_excel)

# Convert the resulting list of tibbles into a list of data.tables
de_dets <- lapply(de_dets, setDT)

# Bind the list of data.tables into one big data.table
de_dets <- rbindlist(de_dets)

# Repair names
setnames(de_dets, function(.) tolower(gsub('and|UTC|[) ()]', '', .)))


# 53482 was re-used on 2017-04-28 (see tag_data), so have to do some gymnastics
#   to join with detections
# Bind detection data before the second time 53482 was deployed to the associated
#   tag data
first_half <- de_dets[datetime < as.POSIXct('2017-04-28 00:00:00', tz = 'UTC')]
first_53482 <- tag_data[!(grepl('53482', transmitter) & date == '2017-04-28')]

first_half <- first_half[first_53482, on = 'transmitter', nomatch = 0]

# Bind detection data after the second time 53482 was deployed to the associated
#   tag data
second_half <- de_dets[datetime >= as.POSIXct('2017-04-28 00:00:00', tz = 'UTC')]
second_53482 <- tag_data[!(grepl('53482', transmitter) & date < '2017-04-28')]

second_half <- second_half[second_53482, on = 'transmitter', nomatch = 0]


# Put them together
de_dets <- rbind(first_half, second_half)


# Repair station locations ----
# "LL# 3685 Upper DE River CB 9" station is reported to be at -40 N, 0 W.
#   Light list V2 lists this as 40-00-38.635N, 075-02-48.335W. Repair:
de_dets[stationname == "LL# 3685 Upper DE River CB 9"
        , ':='(latitude = 40 + 00 / 60 + 38.635 / 3600,
               longitude = -75 - 02 / 60 - 48.335 / 3600)]

# Some "NJDB004", "NJDB014", and "DE River Gate 1A" have positive longitudes.
#   Striper should not be in the eastern hemisphere, so make longitudes negative
de_dets[, longitude := fifelse(longitude > 0, -longitude, longitude)]


# Some stations have NA lat/longs.
#   Some of those are defined elsewhere in the data. Fix that here.
no_location <- de_dets[is.na(latitude) | is.na(longitude)]

not_missing <- de_dets[!(is.na(longitude) | is.na(latitude)) & stationname %in% unique(no_location)$stationname]
not_missing <- unique(not_missing, by = 'stationname')[, .(stationname, latitude, longitude)]

de_dets <- not_missing[de_dets, on = 'stationname']
de_dets[, ':='(latitude = fifelse(is.na(latitude), i.latitude, latitude),
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
## unique(umces[stationname %in% unique(de_dets[is.na(longitude)]$stationname)],
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

de_dets <- station_key[de_dets, on = 'stationname']
de_dets[, ':='(latitude = fifelse(is.na(latitude), i.latitude, latitude),
               longitude = fifelse(is.na(longitude), i.longitude, longitude),
               i.latitude = NULL,
               i.longitude = NULL)]

# Export data ----
# Rename "date" to "tagdate"
setnames(de_dets, 'date', 'tagdate')

# Write CSV
fwrite(de_dets, 'EMBARGO/derived/de_tag_info_detections.csv', dateTimeAs = 'write.csv')


