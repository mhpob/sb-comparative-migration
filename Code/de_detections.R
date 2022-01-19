library(readxl); library(data.table)

# Import tagging data
de_tagging_data <- read_excel('embargo/raw/de tag data.xlsx',
                              range = cell_cols('a:k'))
setDT(de_tagging_data)
setnames(de_tagging_data, function(.) tolower(gsub('[ #]', '', .)))
setorder(de_tagging_data, date, acoustictag)

# At least two tags were re-used, so have to do some gymnastics to join with detections
#   53482, 53985
de_tagging_data[, enddate := rleid(date), by = 'acoustictag']
de_tagging_data[, enddate := fifelse(max(enddate) > 1 & enddate == 1, max(date),
                                as.POSIXct('2020-01-01 00:00:00', tz = 'UTC')),
                by = 'acoustictag']
de_tagging_data[, enddate := .POSIXct(enddate, tz = 'UTC')]


de_tagging_data[, age := as.integer(fifelse(age == '-', NA, age))]
de_tagging_data[, yr := as.factor(year(date))]
de_tagging_data[, acoustictag := as.character(acoustictag)]

setkey(de_tagging_data, acoustictag, date, enddate)




de_dets <- list.files('data/raw/embargo/de detection data',
                      full.names = T)

de_dets <- lapply(de_dets, read_excel)
de_dets <- lapply(de_dets, setDT)
de_dets <- rbindlist(de_dets)

setnames(de_dets, function(.) tolower(gsub('and|UTC|[) ()]', '', .)))

de_dets[, endtime := datetime]
de_dets[, acoustictag := gsub('.*-', '', transmitter)]


de_dets <- foverlaps(de_dets, de_tagging_data, by.x = c('acoustictag', 'datetime', 'endtime'))

de_dets[, ':='(endtime = NULL,
               acoustictag = NULL,
               tagdate = date,
               date = NULL)]

fwrite(de_dets, 'EMBARGO/derived/de_fish.csv', dateTimeAs = 'write.csv')

library(ggplot2)
ggplot(de_dets) +
  geom_density(aes(x = totallength, y = ..count.., color = sex))
