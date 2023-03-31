close all;
clearvars;
clc;

addpath('../bin');

% generate using etopo1 and GSHHS polys
tic;
lon = (105.60 : 0.2 : 135.20);
lat = (  3.20 : 0.2 :  44.00);
[lon, lat] = meshgrid(lon, lat);
ext_create_grid('taiwan_12min',lon,lat);
toc;

% Lake	Chart Datum 
% Erie	173.5
% Ontario	74.2
% Superior	183.2
% Michigan	176
% StClair	174.4
% Huron	176

% generate using custom topo and polys
% tic;
% lon = (276.50 : 0.02 : 281.16);
% lat = ( 41.36 : 0.02 :  42.92);
% [lon, lat] = meshgrid(lon, lat);
% ext_create_grid('lake_erie_72sec',lon,lat, ...
%   'ref_grid','erie_MSL','vars',{'lon','lat','Band1'},'land_val',173.5, ...
%   'boundary','erie','bound_flag',3);
% toc;
% 
