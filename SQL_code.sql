
-- Create spatial index
CREATE INDEX neighbourhoods_geom_index
  ON Neighbourhoods_geo
  USING GIST (geom);

-- check geometry validity
select area_name, ST_Astext(n.geom)
from neighbourhoods_geo n
where ST_IsValid(ST_Transform(n.geom, 4326)) = false

-- Spatial join
DROP TABLE IF EXISTS SJ;

CREATE TABLE SJ
AS(
	SELECT area_id, array_agg(station_id order by station_id) as station_id, 
	area_name, array_agg(name order by station_id) as name, 
	land_area, sum(num_bikes) as num_bikes, 
	sum(num_scooters) as num_scooters,
	count(b.geom) as bike_pods,
	population, number_of_dwellings, number_of_businesses
	FROM Neighbourhoods_geo AS n
	LEFT OUTER JOIN Bikesharingpods AS b
	ON ST_Contains(ST_Transform(n.geom, 4326), b.geom)
	GROUP BY area_id
);

-- create index on area_id
CREATE INDEX area_id_index
ON SJ (area_id);

-- join SJ with business_stats and number_of_vehicles as combined
CREATE TABLE combined AS(

	SELECT sj.area_id, area_name,land_area, num_bikes, num_scooters, bike_pods, value, population, number_of_dwellings, 
	number_of_businesses, retail_trade,accommodation_and_food_services,
	health_care_and_social_assistance, education_and_training, arts_and_recreation_services, servicebalance

	FROM sj
	FULL OUTER JOIN Businessstatistics bs on (sj.area_id = bs.area_id)
	FULL OUTER JOIN numberOfVehicles nv on (sj.area_id = nv.area_id)
);


-- join combined with census_stats as compute_corr
create table compute_corr AS(
	select c.area_id, area_name, land_area, num_bikes,num_scooters, bike_pods, value, population,
	number_of_dwellings, number_of_businesses, retail_trade, accommodation_and_food_services,
	health_care_and_social_assistance, education_and_training, arts_and_recreation_services,
	cs.median_annual_household_income, avg_monthly_rent, servicebalance
	from combined c
	FULL OUTER JOIN censusstatistics cs on (c.area_id = cs.area_id)
);

-- change column name 'value' to 'vehicle_number'
ALTER TABLE "compute_corr"
RENAME COLUMN "value" TO "vehicle_number";

--population_density
ALTER TABLE compute_corr
ADD population_density FLOAT NULL;

UPDATE compute_corr 
SET population_density = population/land_area;

--dwelling density
ALTER TABLE compute_corr
ADD dwelling_density FLOAT NULL;

UPDATE compute_corr 
SET dwelling_density = number_of_dwellings/land_area;

--bike density
ALTER TABLE compute_corr
ADD bike_density FLOAT NULL;

UPDATE compute_corr 
SET bike_density = num_bikes + num_scooters/land_area;

-- pods density
ALTER TABLE compute_corr
ADD pods_density FLOAT NULL;

UPDATE compute_corr 
SET pods_density = bike_pods/land_area;

-- vehicle density
ALTER TABLE compute_corr
ADD vehicle_density FLOAT NULL;

UPDATE compute_corr 
SET vehicle_density = vehicle_number/land_area;

--print output
SELECT *
FROM compute_corr;
