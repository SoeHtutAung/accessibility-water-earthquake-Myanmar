######################
# Topic: Accessibility map of TSBM water treatment plants
# Purpose: To map areas according to the walking distance to 5 TSBM water treatment plants
# Author: One Tech Agency
# Note: UTM zone 46N is used for the analysis
###################### 

# load libraries
library(dplyr)
library(osmdata) # to extract roads
library(sf)
library(terra)  # for faster rasterization of road lines
library(raster) # gdistance doesn't work with terra
library(gdistance) # for cost distance analysis
library(mapview)
library(leaflet)
library(exactextractr)

# load datasets
# # ward and township boundaries from MIMU v9.4
# # population density from WorldPop https://data.worldpop.org/GIS/Population_Density/Global_2000_2020_1km/2020/MMR/mmr_pd_2020_1km.tif
# # road network from OSM
# # location and capacity of water treatment plants from TSBM
# # Intensity from USGS ShakeMap - Modified Mercalli Intensity Scale mean
ward <- st_read("data/ward.geojson")
township <- st_read("data/township_raw.geojson")
wtp <- read.csv("data/water_treatment_plants.csv")
pop <- rast("data/mmr_pd_2020_1km_UNadj.tif") # population density raster
intensity <- rast("data/mmi_mean.flt") 

### 1. create required datasets ###

# 1.1 create layer of water treatment plants
# # create sf object for water treatment plants
wtp <- vect(wtp, geom = c("lon", "lat"), crs = "EPSG:4326") # convert to terra object
wtp <- project(wtp, "EPSG:32646") # project to UTM zone 46N for Myanmar

# 1.2 create layer of roads
# # create extent boundary for analysis - 10km radius from wtps
extent <- buffer(wtp, width = 10000) # buffer the extent by 10km to include more roads
extent_proj <- project(extent, "EPSG:4326") # project to WGS84 latlong so that bbox can be used
bbox <- as.numeric(c(ext(extent_proj)[1], ext(extent_proj)[2], ext(extent_proj)[3], ext(extent_proj)[4])) # extracting max and min for x,y
bbox_osm <- c(bbox[1], bbox[3], bbox[2], bbox[4]) # create named vector for osmdata package 
# # get road data from OSM
roads <- opq(bbox = bbox_osm) %>%
  add_osm_feature(key = "highway") %>%
  osmdata_sf()
# # convert to linestring
roads_lines <- roads$osm_lines
# st_write(roads_lines, "data/roads_lines.geojson", delete_dsn = TRUE) # save to file
# # covert to spatvector and reproject
roads_lines <- vect(roads_lines)
roads_lines_proj <- terra::project(roads_lines, "EPSG:32646")

# 1.3 create travel time layer
# 1.3.1 create a raster layer with 100m grids
# # create a raster gird for the area
r <- rast(extent, resolution = 100) # 100m resolution
# 1.3.2 rasterize the road lines
# # value 1 to grid with road and NA without road
roads_r <- terra::rasterize(roads_lines_proj, r, field = 1, background = NA) 
# terra::writeRaster(roads_r, "data/roads_raster.tif", overwrite = TRUE)
# # assign travel cost - time (in minutes) to cross a cell
res_m <- res(r)[1]  # resolution in meters cell resolution / speed
speed_mpm <- 5000 / 60  # 5 km/h in m/min = 83.33 m/min for roads same as global friction surface for walking
speed_mpm_nonr <- 1000 / 60 # 1 km/h in m/min = 16.67 m/min for non-roads and water same as water in friction surface

# # create a cost surface for the roads     
friction <- roads_r
friction[!is.na(friction)] <- speed_mpm #travel_time_r # assign travel time to road cells
friction[is.na(friction)] <- speed_mpm_nonr #travel_time_nonr # high cost 1 hour for non-road cells
# terra::writeRaster(friction, "data/friction_walking.tif", overwrite = TRUE)

# 1.4 create travel time to water treatment plants layer
# # convert to raster object from terra for gdistance package
fric <- raster(friction) # convert to terra object
# # create transition layer using gdistance package
tr <- transition(fric, transitionFunction = mean, directions = 8)
tr <- geoCorrection(tr, type = "c")
# # get coordinates of WTP points
wtp_coords <- crds(wtp)
# # compute cost distance (travel time) from each WTP to all other points in the raster
tt <- accCost(tr, SpatialPoints(wtp_coords))
tt <- rast(tt) # convert to terra object
crs(tt) <- crs(friction) # set the same CRS as the friction layer
# terra::writeRaster(tt, "data/travel_time.tif", overwrite = TRUE)

# 1.5 population adjustment as 54,133,798 in 2023 by World Bank 
## set parameters
scale_factor <- (54133798 - as.numeric(global(pop, sum, na.rm = TRUE)[1])) / as.numeric(global(pop, sum, na.rm = TRUE)[1]) 
growth_rate <- 0.007  # average population growth rate (2021-23) from Worldbank data
## apply rescaling to each raster cell
pop_23 <- pop * (1 + scale_factor)  # rescale to 2023
pop_24 <- pop_23 * (1 + growth_rate)  # estimate population for 2024
pop_24[is.na(pop_24)] <- 0  # Replace NAs with zero
# # crop for the extent of the analysis
pop_24 <- terra::project(pop_24, "EPSG:32646") # project to UTM zone 46N for Myanmar
pop_final <- crop(pop_24, extent) 

### 2. Visualize catchment areas ###
# 2.1 create travel time contours and zones
# # create contour line for travel time
contours <- as.contour(tt, levels = c(5,15,30))
# terra::writeVector(contours, "data/tt_contours.geojson", filetype = "GeoJSON", overwrite = TRUE)
# # create maps
contour_map <- mapview(contours, layer.name = "Walking time (minutes)") # contour map
wtp$cap <- factor(wtp$capacity, levels = c(500, 750, 3000))
# wtp_map <- mapview(wtp, zcol = "cap", layer.name = "Capacity", cex = 2)
wtp_map <- mapview(wtp, zcol = "cap", cex = 2, legend =F)
contour_map + wtp_map
# 2.2 create intensity map
# #crop for the extent of the analysis
intensity <- terra::project(intensity, "EPSG:32646") # project to UTM zone 46N for Myanmar
intense_final <- crop(intensity, extent) 
# # create map
leaflet() %>%
  #add background
  addProviderTiles("CartoDB.Positron") %>%
  # add raster
  addRasterImage(intense_final, opacity = 0.5, colors = colorRampPalette(c("green", "orange", "red"))(100)) %>%
  # add legend
  addLegend(
    position = "topleft",
    pal = colorNumeric(
      palette = c("green", "orange", "red"),
      domain = values(intense_final),   # ✅ use actual values!
      na.color = "transparent"
    ),
    values = values(intense_final),
    title = "Intensity (USGS-MMI)",
    opacity = 1
  )

### 3. Analyze population coverage ###
# 3.1 create polygons for each travel time zone
contours_poly <- st_as_sf(contours) %>% st_polygonize()  
# # create non-overlapping polygons (donuts) for each travel time zone
contours_poly <- contours_poly %>%
  st_make_valid() %>%
  st_collection_extract("POLYGON") %>% # extract polygons from collection
  st_cast("POLYGON")
# # split into individual layers by travel time
poly_5  <- contours_poly %>% filter(level == 5)
poly_15 <- contours_poly %>% filter(level == 15)
poly_30 <- contours_poly %>% filter(level == 30)
# # create rings by subtracting inner polygons
poly_15_ring <- st_difference(poly_15, st_union(poly_5))
poly_30_ring <- st_difference(poly_30, st_union(st_union(poly_5, poly_15)))
# # combine into final cleaned layer
contours_rings <- bind_rows(
  poly_5,
  poly_15_ring %>% mutate(level = 15),
  poly_30_ring %>% mutate(level = 30)
)
# st_write(st_as_sf(contours_rings), "data/contours_rings.geojson", delete_dsn = TRUE)

# 3.2 Sagaing
# # create ward polygons for Sagaing
wards_sgg <- ward %>% filter(TS == "Sagaing") %>% st_transform(crs = crs(wtp)) # ward boundaries
contours_sgg <- st_intersection(wards_sgg, contours_rings) # intersect ward and travel time zones
# # extract Population by Travel Time Zone and Ward
cov_sgg <- list()
# # loop through each ward and extract population
for (i in 1:nrow(contours_sgg)) {
  # extract the current ward boundary
  area <- contours_sgg[i, ]
  # exact_extract to get the population in this ward-contour area
  pop <- exact_extract(pop_final, area, fun = "sum")
  # store the results
  cov_sgg[[length(cov_sgg) + 1]] <- data.frame(
    ward = area$WARD,  # ward name
    travel_time_zone = area$level,  # travel time zone level
    population = round(pop,0)  # population in this area
  )
  }
# # combine all the results into a single data frame
cov_sgg_df <- do.call(rbind, cov_sgg)
# # display a table
sgg_tbl <- cov_sgg_df %>%
  group_by(travel_time_zone, ward) %>%
  summarise(population = sum(population)) %>%
  arrange(travel_time_zone, desc(population))
# write.csv(sgg_tbl, "data/sgg_population_coverage.csv", row.names = FALSE)

# 3.3 Amarapura
# # create ward polygons for Amarapura
tsp_amp <- township %>% filter(TS == "Amarapura") %>% st_transform(crs = crs(wtp)) # ward boundaries
contours_amp <- st_intersection(tsp_amp, contours_rings) # intersect ward and travel time zones
# # extract Population by Travel Time Zone and Ward
cov_amp <- list()
# # loop through each ward and extract population
for (i in 1:nrow(contours_amp)) {
  # extract the current area boundary
  area <- contours_amp[i, ]
  # exact_extract to get the population in this ward-contour area
  pop <- exact_extract(pop_final, area, fun = "sum")
  # store the results
  cov_amp[[length(cov_amp) + 1]] <- data.frame(
    ward = area$TS,  # ward name
    travel_time_zone = area$level,  # travel time zone level
    population = round(pop,0)  # population in this area
  )
}
# # combine all the results into a single data frame
cov_amp_df <- do.call(rbind, cov_amp)
# # display a table
amp_tbl <- cov_amp_df %>%
  group_by(travel_time_zone) %>%
  summarise(population = sum(population)) %>%
  arrange(travel_time_zone, desc(population))
# write.csv(amp_tbl, "data/amp_population_coverage.csv", row.names = FALSE)

# 3.4 Mandalay
# # create ward polygons for Mandalay
wards_mdy <- ward %>% filter(DT == "Mandalay") %>% st_transform(crs = crs(wtp)) # ward boundaries
contours_mdy <- st_intersection(wards_mdy, contours_rings) # intersect ward and travel time zones
# # extract Population by Travel Time Zone and Ward
cov_mdy <- list()
# # loop through each ward and extract population
for (i in 1:nrow(contours_mdy)) {
  # extract the current ward boundary
  area <- contours_mdy[i, ]
  # exact_extract to get the population in this ward-contour area
  pop <- exact_extract(pop_final, area, fun = "sum")
  # store the results
  cov_mdy[[length(cov_mdy) + 1]] <- data.frame(
    township = area$TS,  # township name
    ward = area$WARD,  # ward name
    travel_time_zone = area$level,  # travel time zone level
    population = round(pop,0)  # population in this area
  )
}
# # combine all the results into a single data frame
cov_mdy_df <- do.call(rbind, cov_mdy)
# # display a table
mdy_tbl <- cov_mdy_df %>%
  group_by(travel_time_zone, township, ward) %>%
  summarise(population = sum(population)) %>%
  arrange(travel_time_zone, township, desc(population))
# write.csv(mdy_tbl, "data/mdy_population_coverage.csv", row.names = FALSE)

# 3.5 Tada-U
# unique(township$TS[grepl("^Ta", township$TS)]) # check exact name of Tada-U in dataframe
# # create ward polygons for Tada-U
tsp_tdu <- township %>% filter(TS == "Tada-U") %>% st_transform(crs = crs(wtp)) # ward boundaries
contours_tdu <- st_intersection(tsp_tdu, contours_rings) # intersect ward and travel time zones
# # extract Population by Travel Time Zone and Ward
cov_tdu <- list()
# # loop through each ward and extract population
for (i in 1:nrow(contours_tdu)) {
  # extract the current area boundary
  area <- contours_tdu[i, ]
  # exact_extract to get the population in this ward-contour area
  pop <- exact_extract(pop_final, area, fun = "sum")
  # store the results
  cov_tdu[[length(cov_tdu) + 1]] <- data.frame(
    ward = area$TS,  # ward name
    travel_time_zone = area$level,  # travel time zone level
    population = round(pop,0)  # population in this area
  )
}
# # combine all the results into a single data frame
cov_tdu_df <- do.call(rbind, cov_tdu)
# # display a table
tdu_tbl <- cov_tdu_df %>%
  group_by(travel_time_zone) %>%
  summarise(population = sum(population)) %>%
  arrange(travel_time_zone, desc(population))
# write.csv(tdu_tbl, "data/tdu_population_coverage.csv", row.names = FALSE)
