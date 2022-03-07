library(data.table)

station_key <- fread('data/station_key.csv')

# import detections
de_dets <- fread('embargo/derived/de_tag_info_detections.csv')
de_dets <- unique(de_dets[, c('stationname', 'latitude', 'longitude')],
                  by = c('stationname', 'latitude', 'longitude'))

setorder(de_dets, stationname)

station_key_new <- merge(station_key, de_dets, all = T)

setorder(station_key_new, stationname, latitude)

fwrite(station_key_new, 'data/station_key.csv')

# Hand audit from here
