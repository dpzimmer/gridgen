function [lon, lat, dep] = ext_read_refgrid(x,y,fname_base,var_x,var_y,var_z,off_x,off_y)

  %% ext_read_refgrid() extracts a region from base grid covering given domain
  %  longitudes are shifted to be in the same reference as supplied coordinates
  %  the extracted region extends beyond the coordinate domain by off_x and off_y
  %  longitdues and latitudes are extended beyond their normal range as required 
  %  so that no index wrapping or range checking is required for averaging or 
  %  interpolating any source cell. target grid points that are not covered by the 
  %  base grid are set to NaN (by design).

  % support for Octave
  vers=ver;
  for i1=1:1:length(vers)
    if strcmpi (vers(i1).Name, 'Octave')
      pkg load netcdf;
      import_netcdf;
    end
  end
  
  % initialize and validate grid domain
  latS = min(min(y));
  lonW = min(min(x));
  latN = max(max(y));
  lonE = max(max(x));
  if (latS < -90) || (latN > 90)
    error('grid latitudes must be in the range -90 to 90');
  end
  
  % Expand domain to include beyond grid extents (allow coordinates to extend rather than wrap/clamp)
  latS = latS - off_y;
  latN = latN + off_y;
  lonW = lonW - off_x;
  lonE = lonE + off_x;
  
  % determine dimensions and ranges of base bathymetry coords
  f = netcdf.open(fname_base,'nowrite');
  varid_lon = netcdf.inqVarID(f,var_x);
  varid_lat = netcdf.inqVarID(f,var_y);
  varid_dep = netcdf.inqVarID(f,var_z);

  % load all coordinates, handle 2D coordinate axes if regularly spaced
  lon_base = netcdf.getVar(f,varid_lon,'double');
  lat_base = netcdf.getVar(f,varid_lat,'double'); 
  if min(size(lat_base)) > 1
    lon_base = lon_base(1,:);
    lat_base = lat_base(:,1);
  end
  nx_base = length(lon_base); 
  ny_base = length(lat_base);
  dx_base = (lon_base(end) - lon_base(1))/(nx_base-1);
  dy_base = abs(lat_base(end) - lat_base(1))/(ny_base-1);

  % check regular spacing
  if (abs(lon_base(2) - lon_base(1) - dx_base) > eps('single')) || ...
     (abs(lat_base(2) - lat_base(1) - dy_base) > eps('single'))
    error('reference topography must have regularly spaced axes');
  end

  % flag upside-down N->S latitude axis
  is_flipped_base = lat_base(end) < lat_base(1); 

  % remove duplicate longitude for wrapped base grids
  if abs(lon_base(end) - lon_base(1) - 360) <= eps('single')
    lon_base(end) = [];
    nx_base = nx_base - 1; %#ok<NASGU>
  end
  
  % determine base coordinate origins assuming S->N order
  south_base = min(lat_base);
  west_base = min(lon_base);

  % Align domain with base grid spacing
  latS = south_base + (dy_base * floor((latS - south_base)/dy_base));
  latN = south_base + (dy_base *  ceil((latN - south_base)/dy_base));
  lonW = west_base  + (dx_base * floor((lonW -  west_base)/dx_base));
  lonE = west_base  + (dx_base *  ceil((lonE -  west_base)/dx_base));
  
  % create target extraction grid
  nx = 1 + round((lonE - lonW)/dx_base);
  ny = 1 + round((latN - latS)/dy_base);
  lon = linspace(lonW, lonE, nx);
  lat = linspace(latS, latN, ny);
  dep = NaN(ny, nx);
  
  % done with these here
  clear latS latN lonW lonE south_base west_base;
  
  % generate index mapping from base grid to target grid
  lon_base_norm = mod(lon_base, 360);
  lon_map = zeros(size(lon));
  for idx=1:nx
    slot = find(abs(lon_base_norm - mod(lon(idx), 360)) <= eps('single'));
    if ~isempty(slot)
      lon_map(idx) = slot;
    end
  end
  
  lat_map = zeros(size(lat));
  for idx=1:ny
    slot = find(abs(lat_base - lat(idx)) <= eps('single'));
    if ~isempty(slot)
      if is_flipped_base
        lat_map(idx) = 1 + ny_base - slot;
      else
        lat_map(idx) = slot;
      end
    end
  end
  
  % done with these here
  clear lon_base lat_base nx_base ny_base dx_base dy_base;
  
  % determine chunks to read from netcdf
  lat_used = lat_map > 0;
  assert(numel(lat_used) > 0, 'latitude range not covered by reference topography'); 
  lat_extr = lat_map(lat_used);
  lat_start = min(lat_extr);
  lat_count = numel(lat_extr);
  
  lon_used = lon_map > 0;
  assert(numel(lon_used) > 0, 'longitude range not covered by reference topography'); 
	lon_extr = unique(lon_map(lon_used), 'sorted');
  split = find(diff(lon_extr) ~= 1); % jump is last of first batch
  assert(numel(split) <= 1, 'algorithm breakdown in read_refgrid()'); 
  if isempty(split)
    lon_start(1) = lon_extr(1);
    lon_count(1) = numel(lon_extr);
  else
    lon_start(1) = lon_extr(1);
    lon_count(1) = split;
    lon_start(2) = lon_extr(split+1);
    lon_count(2) = numel(lon_extr)-split;
  end
  
  % extract contiguous chunks and deal to target grid by columns
  y1 = find(lat_map, 1);
  y2 = y1 + lat_count - 1;
  for idx=1:numel(lon_start)
    dep_base = netcdf.getVar(f,varid_dep,[lon_start(idx)-1 lat_start-1],[lon_count(idx) lat_count],'double')';  
    if is_flipped_base
      dep_base = flipud(dep_base);
    end
    west = lon_start(1);
    east = lon_start(1) + lon_count - 1;
    map = lon_map >= west & lon_map <= east;
    if any(map)
      dep(y1:y2,map) = dep_base(:,1+lon_map(map)-west);
    end
  end
  
  fprintf(1, 'read in the base bathymetry\n');
  netcdf.close(f);

end

            
    

    

