close all;
clearvars;
clc;


addpath('../bin');

% tests = {   ...
%   'simple', ...
%   'custom', ...
%   'global', ...
%   'span',   ...
%  };

tests = {   ...
  'span',   ...
 };


%%
% generate regional grid using etopo1 and GSHHS polys
%
if any(strcmp(tests, 'simple'))

  tic;
  lon = (105.60 : 0.2 : 135.20);
  lat = (  3.20 : 0.2 :  44.00);
  [mlon, mlat] = meshgrid(lon, lat);
  ext_create_grid('taiwan_12min',mlon,mlat,'out_dir','./output');
  toc;

end


%%
% generate regional grid using custom topo and polys (DISABLED: reference_data not yet incorporated into fork)
%
if any(strcmp(tests, 'custom'))

  % Lake	    Chart Datum 
  % ========  ===========
  % Ontario	         74.2
  % Erie	          173.5
  % StClair	        174.4
  % Huron	          176.0
  % Michigan	      176.0
  % Superior	      183.2
  
  % tic;
  % lon = (276.50 : 0.02 : 281.16);
  % lat = ( 41.36 : 0.02 :  42.92);
  % [mlon, mlat] = meshgrid(lon, lat);
  % ext_create_grid('lake_erie_72sec',mlon,mlat, ...
  %   'ref_grid','erie_MSL','vars',{'lon','lat','Band1'},'land_val',173.5, ...
  %   'boundary','erie','bound_flag',3);
  % toc;
  % 

end


%%
% generate global grid for both positive and signed longitude conventions (USE ETOPO 2022)
%
if any(strcmp(tests, 'global'))

  % global 0.8-degree positive longitudes
  lon = (  0.00 : 0.8 : 359.20);
  lat = ( -78.00: 0.8 :  78.00);
  
  % global 0.8-degree signed longitude split indexes
  west = (lon >= 180);
  east = (lon  < 180);
  
  % global 0.8-degree positive grid using ETOPO 2022
  [mlon, mlat] = meshgrid(lon, lat);
  ext_create_grid('global_48min_pos', mlon, mlat, 'out_dir', './output', ...
    'ref_grid', 'ETOPO_2022_v1_60s_N90W180_surface', 'vars', {'lon','lat','z'});
  
  % reorder global 0.8-degree for signed grid
  inp = './output/global_48min_pos';
  out = './output/global_48min_sgn';
  
  wad = readmatrix([inp '.bot'], 'FileType', 'text');
  wad = horzcat(wad(:,west), wad(:,east));
  write_ww3file([out '.bot'], wad);
  
  wad = readmatrix([inp '.msk'], 'FileType', 'text');
  wad = horzcat(wad(:,west), wad(:,east));
  write_ww3file([out '.msk'], wad);
  
  wad = readmatrix([inp '.obs'], 'FileType', 'text');
  wad = horzcat(wad(:,west), wad(:,east));
  [ny, nx] = size(wad); %#ok<ASGLU>
  split = ny/2;
  write_ww3obstr([out '.obs'], wad(1:split,:), wad(split+1:end,:)); 
  
  fprintf('Manually adjust signed grid longitude origin from 0 to -180 in .meta file\n');

  % show it
  lon = (-180.00 : 0.8 : 179.20);
  lat = ( -78.00:  0.8 :  78.00);
  wad = readmatrix([out '.bot'], 'FileType', 'text');
  wad(wad >= 0) = NaN;
  ext_plot_grid(2, lon, lat, wad, 'Bathymetry', 'global_48min_sgn', 'depth', './output');
  
end


%%
% generate regional grid that spans the prime meridian
%
if any(strcmp(tests, 'span'))

  % British Isles
  lon = (-16 : 0.05 :  7);
  lat = ( 47:  0.05 : 63);

  west = (lon <  0);
  east = (lon >= 0);
  
  lon_west = mod(lon(west), 360);
  lon_east = lon(east);

  [mlon, mlat] = meshgrid(lon_west, lat);
  ext_create_grid('british_isles_03min_west',mlon,mlat,'out_dir','./output');

  [mlon, mlat] = meshgrid(lon_east, lat);
  ext_create_grid('british_isles_03min_east',mlon,mlat,'out_dir','./output');

  % merge
  wst = './output/british_isles_03min_west';
  est = './output/british_isles_03min_east';
  out = './output/british_isles_03min_sgn';
  
  lo = readmatrix([wst '.bot'], 'FileType', 'text');
  hi = readmatrix([est '.bot'], 'FileType', 'text');
  wad = horzcat(lo, hi);
  write_ww3file([out '.bot'], wad);
  wad(wad > 0) = 0;
  ext_write_grid(lon, lat, wad, 'british_isles_03min_sgn', 'bathy', './output'); % in-house format

  lo = readmatrix([wst '.msk'], 'FileType', 'text');
  hi = readmatrix([est '.msk'], 'FileType', 'text');
  wad = horzcat(lo, hi);
  write_ww3file([out '.msk'], wad);
  ext_write_grid(lon, lat, wad, 'british_isles_03min_sgn', 'mask', './output'); % in-house format
  
  lo = readmatrix([wst '.obs'], 'FileType', 'text');
  hi = readmatrix([est '.obs'], 'FileType', 'text');
  wad = horzcat(lo, hi);
  [ny, nx] = size(wad); %#ok<ASGLU>
  split = ny/2;
  write_ww3obstr([out '.obs'], wad(1:split,:), wad(split+1:end,:)); 
  
  fprintf('Manually adjust signed grid longitude origin from 344 to -16 in .meta file\n');

  % show it
  wad = readmatrix([out '.bot'], 'FileType', 'text');
  wad(wad >= 0) = NaN;
  ext_plot_grid(1, lon, lat, wad, 'Bathymetry', 'british_isles_03min_sgn', 'depth', './output');

end


%%


