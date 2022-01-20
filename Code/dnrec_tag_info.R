library(readxl); library(data.table)

tag_data <- read_excel('embargo/raw/dnrec/de tag data.xlsx',
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


fwrite(tag_data, 'EMBARGO/derived/dnrec_tag_info.csv', dateTimeAs = 'write.csv')
