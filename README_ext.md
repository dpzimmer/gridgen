This fork of NOAA-EMC/gridgen comprises experimental code provided as-is and placed into the public domain.

The repository extends the original package by the addition of functions using the 'ext_' prefix, as well as 
applies any required adjustments or patches to the existing code... the main new function being 'ext_create_grid'.

## Status

2023-04-04 - basic testing clomplete.
           - TODO: document approaches taken in the extended functions.

## Notes

**setup_gridgen_ext.m** will download ETOPO 2022 (both 60-second and 30-second) to the reference_data folder. 

**ext_read_refgrid.m** will extract from NetCDF DEMs in a flexible manner to cover a requested region.
Longitude signedness and wrapping is accounted for and the returned DEM coordinates are suitably aligned 
for direct interpolation to the target.

