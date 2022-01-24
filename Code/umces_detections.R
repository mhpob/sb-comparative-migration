all_files <- list.files('p:/obrien/biotelemetry/detections',
                        pattern = '*.csv', recursive = T, full.names = T)
# Drop raw MATOS files (they start with proj)
all_files <- all_files[!grepl('MATOS/proj', all_files)]


library(parallel); library(data.table)

cl <- makeCluster(detectCores(logical = F))

clusterEvalQ(cl, library(data.table))

all_dets <- parLapply(cl, all_files, fread, fill = T)

stopCluster(cl)

names(all_dets) <- all_files

# Remove empty datasets

have_dets <- sapply(all_dets, nrow) > 0
all_dets <- all_dets[have_dets]

all_dets <- rbindlist(all_dets, fill = T, idcol = 'file')


setnames(all_dets, function(.) tolower(gsub('and|UTC|[) ()]', '', .)))

all_dets <- all_dets[, .(file, datetime, receiver, transmitter, sensorvalue,
                         stationname, latitude, longitude)]

all_dets <- unique(all_dets, by = c('datetime', 'receiver', 'transmitter'))


tag_info <- fread('embargo/derived/umces_tag_info.csv')
setnames(tag_info, c('lat', 'lon'), c('taglat', 'taglon'))

no_25465 <- all_dets[!grepl('25465', transmitter)][tag_info, on = 'transmitter', nomatch = 0]

first_25465 <- all_dets[grepl('25465', transmitter) & datetime <= '2014-06-10'][
  tag_info[tagdate < '2014-10-30'], on = 'transmitter', nomatch = 0]
first_25465[, transmitter := paste0(transmitter, 'a')]

second_25465 <- all_dets[grepl('25465', transmitter) & datetime >= '2014-10-30'][
  tag_info[tagdate >= '2014-10-30'], on = 'transmitter', nomatch = 0]
second_25465[, transmitter := paste0(transmitter, 'b')]

dets_info <- rbind(no_25465, first_25465, second_25465)

fwrite(dets_info, 'embargo/derived/umces_tag_info_detections.csv', dateTimeAs = 'write.csv')
