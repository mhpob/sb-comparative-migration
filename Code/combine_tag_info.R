library(data.table)

dnrec <- fread('embargo/derived/dnrec_tag_info.csv')
madmf <- fread('embargo/derived/madmf_tag_info.csv')
umces <- fread('embargo/derived/umces_tag_info.csv',
               na.strings = '')

# Align desired column names
setnames(dnrec,
         c('date', 'totallength', 'tagginglocation', 'tbartag', 'fish'),
         c('tagdate', 'tl', 'taglocation', 'exttag', 'fishid'))
setnames(madmf,
         c('date', 'tlmm', 'capturelocation'), 
         c('tagdate', 'tl', 'taglocation'))
setnames(umces, 'location', 'taglocation')


dnrec[, system := 'DE']
madmf[, system := 'MA Coast']
umces[, system := fcase(grepl('Pot|Pt', taglocation), 'Potomac',
                       grepl('Hud', taglocation), 'Hudson',
                       grepl('MA', taglocation), 'MA Coast')]

all_info <- rbind(dnrec, madmf, umces, fill = T)

fwrite(all_info, 'embargo/derived/combined_tag_info.csv',
       dateTimeAs = 'write.csv')
