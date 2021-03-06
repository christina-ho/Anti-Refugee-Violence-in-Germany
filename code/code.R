############################## REPLICATED CODE ###############################
#### Refugees Welcome: A Dataset on Anti-refugee Violence in Germany" ######## ###########################################################################################################################################################

# The replicated code for "Refugees welcome? A dataset on anti-refugee violence in Germany" was available on Harvard Dataverse, and was readily available as an R file. The raw dataset was available within a custom-created package on R, which was extremely convenient and made the data easy to download.

# In order to successfully run the code provided to us, certain R packages were required, some of which had not been listed. Therefore, some trial and error was necessary, as we had to go ahead and determine what packages we did not have loaded and/or installed. All of the R packages that were ultimately required are listed in the code down below. 

# Reproducing the results would have also been made easier if the code had been more extensively commented. Although the code was labeled according to its corresponding table/graph from the paper, perhaps some additional notes would have made perusing and understand the code a little less difficult.   
# Other than that, the code ran smoothly -- there were no issues and ultimately, we were able to reproduce all the tables, graphs, and maps displayed in the paper.  

#################################################
# Replication code for figures and tables
#                                         
# Refugees welcome? 
# A dataset on anti-refugee violence in Germany
#
# by
#
# David Bencek and Julia Strasheim
#################################################

# Required packages -------------------------------------------------------
library(gpclib)
library(maptools)
library(rgeos)
library(lubridate)
library(plyr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggthemes)
library(devtools)
library(broom)
library(rgdal)
library(mapproj)

# Data --------------------------------------------------------------------
devtools::install_github("davben/arvig", ref = "v16.1.0")
data(arvig, package = "arvig")

# separate multi-category events
## construct a helper function for separating events
separate_events <- function(x) {
  if (is.na(x$category_en[1])) return(x)
  splits_group <- stringi::stri_count_fixed(x$category_en[1], "&")
  if (splits_group==1) {
    two <- x %>%
      separate(category_en, c("cat1", "cat2"), sep = " & ") %>%
      gather(helper, category_en, c(cat1, cat2)) %>%
      select(date, location, state, community_id, longitude, latitude, 
             category_de, category_en, description, `source`)
    return(two)
  }
  if (splits_group==2) {
    three <- x %>%
      separate(category_en, c("cat1", "cat2", "cat3"), sep = " & ") %>%
      gather(helper, category_en, c(cat1, cat2, cat3)) %>%
      select(date, location, state, community_id, longitude, latitude, 
             category_de, category_en, description, `source`)
    return(three)
  }
  x
}

## run the function on the dataset, splitting multi-category events into multiple rows
arvig_separated <- ddply(arvig, .(category_en), separate_events) %>%
  arrange(date)

------------------------------------------------------------------------------
  
# Load a shapefile for creating maps
## Source: Geodatenzentrum, GeoBasis-DE / BKG 2016
src = "http://sg.geodatenzentrum.de/web_download/vg/vg1000-ew_3112/utm32s/shape/vg1000-ew_3112.utm32s.shape.ebenen.zip"
lcl <- "./germany_shape.zip"

if (!file.exists(lcl)) {
  download.file("http://sg.geodatenzentrum.de/web_download/vg/vg1000-ew_3112/utm32s/shape/vg1000-ew_3112.utm32s.shape.ebenen.zip", lcl)
}
unzip(lcl, exdir = "./germany_shape")

germany <- readOGR(dsn = "./germany_shape/vg1000-ew_3112.utm32s.shape.ebenen/vg1000-ew_ebenen", 
                   layer = "VG1000_KRS")
germany <- spTransform(germany, CRS("+proj=longlat +ellps=GRS80 +datum=WGS84 +no_defs"))


# Table 1 -----------------------------------------------------------------

str(arvig)


frequency_table_data <- arvig %>%
  count(category_en) %>%
  rename(Category = category_en, 
         N = n) %>%
  replace_na(list(Category = "other"))

frequency_table_data

# Figure 1 ----------------------------------------------------------------
# shapefile as data frame
germany_df <- tidy(germany, region="RS")
arvig_separated = arvig_separated %>% filter(category_en != '')

# plot events on map
events_plot <- ggplot(germany_df) + 
  geom_map(map = germany_df, aes(long, lat, map_id = id), 
           colour = "#f2f2f2", fill ="#d9d9d9", size = 0.1) + 
  geom_point(data = arvig_separated, 
             aes(longitude, latitude, colour = factor(category_en)), alpha=0.7, size=1) +
  scale_color_manual(values = c("#e69f00", "#d55e00", "#0072b2", "#009e73"), name=NULL,
                     labels = c("Arson", "Assault", "Demonstration", "Misc. Attack")) +
  guides(colour = guide_legend(ncol = 1, override.aes = list(size = 6))) +
  coord_map("vandergrinten") + 
  theme_map() +
  theme(legend.position = c(0.99,0.99),
        legend.justification = c(0, 1),
        legend.key = element_blank()) + ggtitle('Where are the Attacks Taking Place?')

print(events_plot)


# Figure 2 ----------------------------------------------------------------
day_histogram <- arvig_separated %>% 
  count(date) %>%
  right_join(data.frame(date=seq(dmy("01.01.2014"), dmy("31.12.2015"), by="day")), by = "date") %>%
  replace_na(list(n = 0))


day_histogram_plot <- ggplot(day_histogram, aes(n)) +
  geom_histogram(binwidth = 1, boundary = -0.5, fill="#E69F00", colour = "black") +
  xlab("Events per day") +
  ylab("Count") +
  theme_bw()
print(day_histogram_plot)


# Figure 3 ----------------------------------------------------------------
state_counts <- arvig_separated %>%
  mutate(state_nr = as.numeric(substr(community_id, 1, 2))) %>%
  filter(!is.na(category_en)) %>%
  count(state_nr, category_en) %>%
  arrange(desc(n))

inhabitants <- germany@data %>%
  select(RS, EWZ) %>%
  filter(EWZ > 0) %>%
  mutate(state_nr = as.numeric(substr(RS, 1, 2))) %>%
  group_by(state_nr) %>%
  summarise(inhabitants = sum(EWZ))

states <- arvig %>%
  mutate(state_nr = as.numeric(substr(community_id, 1, 2))) %>%
  dplyr::select(state, state_nr) %>%
  distinct(state, state_nr)

state_counts <- state_counts %>%
  left_join(inhabitants, "state_nr") %>%
  mutate(per_100k = n/inhabitants*100000) %>%
  left_join(states, "state_nr") %>%
  mutate(east = state_nr > 10,
         state_label = ifelse(east, paste0(state, "*"), state),
         state_label = reorder(state_label, state_nr)) %>%
  arrange(state, category_en)

state_counts_plot <- ggplot(state_counts, aes(state_label, per_100k, fill=category_en)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(values = c("#e69f00", "#d55e00", "#0072b2", "#009e73"), 
                    labels = c("Arson", "Assault", "Demonstration", "Misc. Attack")) +
  xlab("") +
  ylab("Events per 100 000 inhabitants") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 60, hjust = 1),
        legend.title = element_blank(),
        legend.position=c(0.04, 0.99), 
        legend.justification=c(0,1),
        legend.key = element_rect(colour = NA),
        legend.background = element_rect(colour = "grey", size = .5))
print(state_counts_plot)


# Figure 4 ----------------------------------------------------------------
district_counts <- arvig_separated %>%
  mutate(id = substr(community_id, 1, 5)) %>%
  count(id)

district_data <- germany@data %>%
  select(RS, EWZ) %>%
  filter(EWZ > 0) %>%
  rename(id = RS,
         population = EWZ) %>%
  mutate(id = as.character(id)) %>%
  left_join(district_counts, "id") %>%
  mutate(per_100k = ifelse(is.na(n), 0, n/population * 100000),
         per_100k_f = cut(per_100k, c(0, 5, 10, 15, 20, 25,30), ordered_result = TRUE)) %>%
  right_join(germany_df, "id")



holes <- unique(district_data[district_data$hole == TRUE,]$id)


intensity_map_district <- ggplot(district_data, aes(long, lat, group = id, fill = per_100k_f)) +
  geom_map(map = district_data, aes(map_id = id)) +
  geom_map(map = filter(district_data, id %in% holes), 
           data = filter(district_data, id %in% holes),
           aes(map_id = id), colour = "#f2f2f2", size = 0.1) +
  geom_map(map = filter(district_data, !id %in% holes), 
           data = filter(district_data, !id %in% holes),
           aes(map_id = id), colour = "#f2f2f2", size = 0.1) +
  scale_fill_brewer(name="", palette = "YlOrRd", na.value="#d9d9d9") +
  coord_map("vandergrinten") + 
  theme_map() +
  theme(legend.position = c(0.05, 0.95), 
        legend.justification = c(0, 1))
print(intensity_map_district)


# Figure 5 ----------------------------------------------------------------
weekdays <- arvig_separated %>% 
  filter(!is.na(category_en)) %>%
  mutate(day_of_week = wday((date), label = TRUE),
         day_of_week = substr(as.character(day_of_week), 1, 3)) %>%
  count(category_en, day_of_week) %>%
  mutate(day_of_week = ordered(day_of_week, levels = c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")))

weekdays_plot <- ggplot(weekdays, aes(day_of_week, n, fill=category_en)) +
  geom_bar(stat = "identity") +
  scale_x_discrete(name="") +
  scale_y_continuous(name="Count") +
  scale_fill_manual(values = c("#e69f00", "#d55e00", "#0072b2", "#009e73"), guide=FALSE) +
  facet_wrap(~ category_en, 
             labeller = labeller(category_en = c(arson = "Arson", assault = "Assault",
                                                 demonstration = "Demonstration", `miscellaneous attack` = "Misc. Attack"))) +
  theme_bw()
print(weekdays_plot)

# Table 2 -----------------------------------------------------------------
sample_table <- filter(arvig, date==dmy("06.03.2015"), location=="Freital") %>%
  colwise(function(x)as.character(x))(.) %>%
  gather(Variable, Sample)

