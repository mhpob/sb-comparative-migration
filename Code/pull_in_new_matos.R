library(data.table)

files <- list.files('c:/users/darpa2/desktop/matos updates apr22', full.names = T, pattern = '.csv')

files <- lapply(files, fread)

files <- rbindlist(files, fill = T)

files[, ':='(transmittername = NA, transmitterserial = NA)]

k <- files[, .(datecollected, receiver, tagname, transmittername, transmitterserial, sensorraw, sensorunit, station, latitude, longitude)]


setnames(k, c('Date and Time (UTC)', 'Receiver', 'Transmitter', 'Transmitter Name',
              'Transmitter Serial', 'Sensor Value', 'Sensor Unit', 'Station Name',
              'Latitude', 'Longitude'))

k <- unique(k, by = c('Date and Time (UTC)', 'Transmitter', 'Latitude', 'Longitude'))

fwrite(k, 'p:/obrien/biotelemetry/detections/received/matos/matos_20220421.csv',
       dateTimeAs = 'write.csv', row.names = F)

k[, `Station Name` := toupper(`Station Name`)]
