function setup_gridgen_ext

  %% setup_gridgen_ext will download additional reference data for use with the 'ext' functions.

  fprintf('grid_gen extended installation!\n');

  % Define paths
  home = fileparts(which(mfilename)); % grid_gen directory

  % ETOPO 2022 60-second (1-minute, i.e. updated Etopo-1)
  %
  pth = 'https://www.ngdc.noaa.gov/thredds/fileServer/global/ETOPO2022/60s/60s_surface_elev_netcdf';
  fil = 'ETOPO_2022_v1_60s_N90W180_surface.nc';
  src = sprintf('%s/%s', pth, fil);
  dst = fullfile(home, sprintf('reference_data/%s', fil));
  fprintf('downloading %s...', dst);
  websave(dst, src);
  fprintf('done.\n');
  
  % ETOPO 2022 30-second (pretty big... maybe better to subset as required)
  %
  pth = 'https://www.ngdc.noaa.gov/thredds/fileServer/global/ETOPO2022/30s/30s_surface_elev_netcdf';
  fil = 'ETOPO_2022_v1_30s_N90W180_surface.nc';
  src = sprintf('%s/%s', pth, fil);
  dst = fullfile(home, sprintf('reference_data/%s', fil));
  fprintf('downloading %s...', dst);
  websave(dst, src);
  fprintf('done.\n');
