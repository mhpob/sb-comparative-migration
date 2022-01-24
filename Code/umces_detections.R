library(parallel); library(data.table)

# List detection records
all_files <- list.files('p:/obrien/biotelemetry/detections',
                        pattern = '*.csv', recursive = T, full.names = T)
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
tag_info <- fread('embargo/derived/umces_tag_info.csv')
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

# Export
fwrite(dets_info, 'embargo/derived/umces_tag_info_detections.csv', dateTimeAs = 'write.csv')
