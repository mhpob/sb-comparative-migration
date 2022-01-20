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


# 53482 was re-used, so have to do some gymnastics to join with detections
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



# Export data ----
# Rename "date" to "tagdate"
setnames(de_dets, 'date', 'tagdate')

# Write CSV
fwrite(de_dets, 'EMBARGO/derived/de_tag_info_detections.csv', dateTimeAs = 'write.csv')


