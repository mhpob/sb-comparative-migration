library(data.table)

# Potomac 2014 - 2018 (ASMFC)
asmfc <- fread('embargo/raw/umces/taggingdata.csv',
               na.strings = c('', 'NA'),
               col.names = function(.) tolower(gsub('[) (,/]', '', .)))
asmfc[, ':='(tagdate = as.Date(tagdate, '%m/%d/%Y'),
             tl = lengthtlmm,
             wgt = weightkg,
             extag = floytagid,
             age = agescale)]
asmfc[, location := fifelse(tagdate < '2014-05-01', 'Potomac, Newburg',
                            'Potomac, Pt Lookout')]
asmfc <- asmfc[, .(tagdate, transmitter, extag, tl, wgt, sex,
                   age, location)]

# A69-1601-25465 reused

# Potomac / MA Coast 2017 - (BOEM)
boem <- fread('embargo/raw/umces/wea tagging data.csv',
              col.names = function(.) tolower(gsub('\n|[) (,/]', '', .)))
boem[, ':='(tagdate = as.Date(as.character(tagdate), '%Y%m%d'),
            tl = lengthtlmm,
            wgt = weightkg,
            transmitter = tagid,
            extag = exttagid)]
boem[grepl('\\d', location), ':='(location = 'MA Coast',
                                  lat = as.numeric(gsub(',.*', '', location)),
                                  lon = as.numeric(gsub('.*\\s', '', location)))]
boem <- boem[, .(tagdate, transmitter, extag, tl, wgt, sex, location, lat, lon)]


# Hudson 2016 - 2019 (HRF)
hrf <- fread('embargo/raw/umces/sb sonic tags 2016.csv',
             na.strings = 'n/a',
             col.names = tolower)
hrf[, ':='(tagdate = as.Date(tagdate, '%m/%d/%Y'),
           location = paste('Hudson,', location),
           wgt = weight,
           sex = fifelse(sex == 'Male', 'M', 'F'))]
hrf <- hrf[, .(tagdate, transmitter, location, tl, wgt, sex)]


tag_info <- rbind(asmfc, hrf, boem, fill = T)
View(tag_info)
