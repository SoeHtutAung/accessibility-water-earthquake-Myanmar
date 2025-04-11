# Catchment area and population coverage of water treatment plants
The purpose is to support post-disaster humanitarian assistance by estimating catchment area and population coverage of water treatment plants, donated by TSBM as response to 2025 Myanmar earthquake. In this analysis, we emphasize on wards in Sagaing township and selected townships of Mandalay region, and at township-level in Amarapura and Tada-U townships. Public version of the outputs could be seen in this [Canva](https://soehtutaung.my.canva.site/tsbm-wtp-access) site.

## 1. Data extraction
Following data are extracted
| Name | Description |
| ---- | ---- |
| ward.geojson </br> township_raw.geojson | Spatial dataset from the [MIMU](https://geonode.themimu.info/layers/) |
| mmi_mean.flt </br> mmi_mean.hdr | Raster surface from [USGS](https://earthquake.usgs.gov/earthquakes/eventpage/us7000pn9s/shakemap/metadata)|
| mmr_pd_2020_1km_UNadj.tif | Population density raster surface (2020 UN adjusted) from [Worldpop](https://hub.worldpop.org/geodata/listing?id=77)|
| water_treatment_plants.csv | Location of water treatment plants by [TSBM](https://www.facebook.com/people/TSBM-The-Spirit-of-Brotherhood-Mission/100067464211453/)|

## 2. Analysis workflow
### 2.1 Producing accessibility dataset for catchment areas
Firstly, a raster layer of travel time (in minutes) to nearest water treatment plant is created using the following workflow: <br/>
<img src=https://github.com/user-attachments/assets/9e12009c-7268-4e5e-bbe9-e65ac5ce2b69 title="wf1" width="350"> 

### 2.2 Extracting population coverage
Then, population coverage in each ward and township is estimated using the administrative boundaries and population density surfaces as per this workflow: <br/>
<img src=https://github.com/user-attachments/assets/001f484b-5219-474a-8f1a-48de384740ee title="wf2" width="400"> 

## 3. Results
### 3.1 Catchment area
Catchment area of 6 TSBM's water treatment plants could be observed in this [map](https://www.google.com/maps/d/u/0/edit?mid=1OfoKXAPGzb6lspwxFQUrIj-C3eKRaSY&ll=21.92921926643306%2C96.02845706318978&z=12) <br/>
<img src=https://github.com/user-attachments/assets/558c59fc-5581-4a3c-9574-3280b7c38440 title="catchment" width="500"> 

### 3.2 Population coverage
The results were displayed in Canva site ([Click Here!](https://soehtutaung.my.canva.site/tsbm-wtp-access)) using Flourish. <br/>
***Example:** Estimated population according to walking distance to TSBM's water treatment plant in Sagaing township* <br/>
<img src=https://github.com/user-attachments/assets/24ff7720-865f-442c-87ea-79eb67e32b19 title="pg1" width="500">
