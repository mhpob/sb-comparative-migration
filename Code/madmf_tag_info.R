library(readxl); library(data.table)

tag_data <- read_xlsx(
  file.path('embargo/raw/madmf',
            'dmf releases for ds coastal migrations 1_22.xlsx')
  )

setDT(tag_data)
setnames(tag_data, function(.) tolower(gsub('[#\\.)( ]', '', .)))

names(tag_data)

tag_data[, ':='(date = as.Date(date),
                transmitter = paste('A69-9001', actag, sep = '-'),
                notes = fifelse(!is.na(`12`),
                                gsub(', NA', '', paste(notes, `12`, `13`, sep = ', ')),
                                notes),
                actag = NULL,
                `12` = NULL,
                `13` = NULL)]



tag_data[grepl('\\d{2}', capturelocation),
         ':='(lat = gsub(' +\\d{2} \\d{2}.\\d{3}$', '', capturelocation),
              lon = gsub('^\\d{2} \\d{2}.\\d{3} +', '', capturelocation))]

tag_data[grepl('\\d{2}', capturelocation),
         ':='(lat = as.numeric(gsub('.* ', '', lat)) / 60 +
                as.numeric(gsub(' .*', '', lat)),
              lon = as.numeric(gsub('.* ', '', lon)) / 60 +
                as.numeric(gsub(' .*', '', lon)))]

fwrite(tag_data, 'EMBARGO/derived/madmf_tag_info.csv', dateTimeAs = 'write.csv')
