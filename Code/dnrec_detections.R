library(readxl); library(data.table)

# Import tagging data ----
de_tagging_data <- read_excel('embargo/raw/dnrec/de tag data.xlsx',
                              range = cell_cols('a:k'))
setDT(de_tagging_data)
setnames(de_tagging_data, function(.) tolower(gsub('[ #]', '', .)))

# At least two tags were re-used, so have to do some gymnastics to join with detections
# Going to use data.table::foverlaps to make sure that fish detections are matched
#   to the period of time that the tag was in a particular fish
# 53482, 53985 are the repeated transmitters

# Create run-length IDs for each transmitter. Transmitters only deployed once will
#   have only one run-length (a value of 1), those deployed 2 times will have two
#   IDs (1 and 2)
de_tagging_data[, enddate := rleid(date), by = 'acoustictag']

# If there are two groups, set the first deployment's end date to the deployment
#   date of the second time period. Else, set it to Jan 1, 2020.
de_tagging_data[, enddate := fifelse(max(enddate) > 1 & enddate == 1, max(date),
                                as.POSIXct('2020-01-01 00:00:00', tz = 'UTC')),
                by = 'acoustictag']

# Convert date-times to POSIX
de_tagging_data[, enddate := .POSIXct(enddate, tz = 'UTC')]

# Clean up age data
de_tagging_data[, age := as.integer(fifelse(age == '-', NA, age))]

# Convert the acoustic tag to character to match the class in the next data set
de_tagging_data[, acoustictag := as.character(acoustictag)]

# Tell data.table which columns are start and end dates (and that they're grouped
#   by acoustictag).
setkey(de_tagging_data, acoustictag, date, enddate)



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

# data.table::foverlaps needs a start and end time. Duplicate the time of detection
#   to make a dummy end time
de_dets[, endtime := datetime]

# Pull out transmitter "acoustic tag" flag
de_dets[, acoustictag := gsub('.*-', '', transmitter)]



# Conduct overlap join ----
de_dets <- foverlaps(de_dets, de_tagging_data,
                     by.x = c('acoustictag', 'datetime', 'endtime'))


# Export data ----
# Drop unneeded columns and rename "date" to "tagdate"
de_dets[, ':='(endtime = NULL,
               acoustictag = NULL,
               tagdate = date,
               date = NULL)]

# Write CSV
fwrite(de_dets, 'EMBARGO/derived/de_tag_info_detections.csv', dateTimeAs = 'write.csv')


