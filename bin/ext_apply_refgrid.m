function depth_sub = ext_apply_refgrid(x,y,ref_dir,bathy_source,wet_thresh,land_val,dry_val,wet_only,varargin)

  %% ext_apply_refgrid() is an extended replacement replacment for generate_grid()
  %  this seamlessly handles global/regional grid generation and any input 
  %  netcdf DEM (global or regional). 

  %@@@ set file name for source bathymetry and variable names
  if strcmp(bathy_source, 'etopo1')
    var_x = 'lon';
    var_y = 'lat';
    var_z = 'z';
  else
    if nargin == 11
      %@@@ Extra 3 arguments define the lat, lon and depth var names
      var_x = varargin{1};
      var_y = varargin{2};
      var_z = varargin{3};
    else
      % etopo2 or default
      var_x = 'x';
      var_y = 'y';
      var_z = 'z';    
    end
  end
  fname_base = [ref_dir,'/',bathy_source,'.nc'];

  %@@@ Compute cell corners
  [ny,nx] = size(x);
  cell = repmat(struct('px',[],'py',[],'width',[],'height',[]),nx,ny);
  for j = 1:nx
      for k = 1:ny    
          [c1,c2,c3,c4,wdth,hgt] = compute_cellcorner(x,y,j,k,nx,ny);
          cell(k,j).px = [c4(1) c1(1) c2(1) c3(1) c4(1)]';
          cell(k,j).py = [c4(2) c1(2) c2(2) c3(2) c4(2)]';
          cell(k,j).width = wdth;
          cell(k,j).height = hgt;        
      end
  end
  dx = max([cell(:).width]);
  dy = max([cell(:).height]);

  %@@@ Read reference grid region that fully covers destination elements

  [lon_base, lat_base, depth_base] = ext_read_refgrid(x,y,fname_base,var_x,var_y,var_z,dx*2,dy*2);
  [ny_base, nx_base] = size(depth_base);
  dx_base = (lon_base(end) - lon_base(1))/(nx_base - 1);
  dy_base = (lat_base(end) - lat_base(1))/(ny_base - 1);

  % debug
  % figure(1);
  % depth_base(depth_base > land_val) = land_val;
  % depth_base(isnan(depth_base)) = land_val;
  % imagesc(lon_base,lat_base,depth_base);
  % set(gca,'YDir','normal'); colormap jet; colorbar;
  % stop = 'here';

  %@@@ Obtaining data from base bathymetry. If desired grid is coarser than 
  %@@@ base grid then 2D averaging of bathymetry else grid is interpolated 
  %@@@ from base grid. No wrapping is done, as source grid extends beyond  
  %@@@ destination domain (wrapping was handled in ext_read_refgrid())

  pct_prev = 0;
  np = nx*ny;

  fprintf(1,'Generating grid bathymetry ....\n');

  depth_sub = dry_val*ones(size(x));

  for j = 1:nx
    for k = 1:ny

      ndx = round(cell(k,j).width/dx_base);
      ndy = round(cell(k,j).height/dy_base);

      if ndx <= 1 && ndy <= 1 % not great when .width and .height largely differ

        %@@@ Interpolating from base grid
        [~,lon_prev] = min(abs(lon_base-x(k,j)));
        if lon_base(lon_prev) > x(k,j)
            lon_prev = lon_prev - 1;
        end
        lon_next = lon_prev + 1;

        [~,lat_prev] = min(abs(lat_base-y(k,j)));
        if lat_base(lat_prev) > y(k,j)
            lat_prev = lat_prev - 1;
        end
        lat_next = lat_prev + 1;

        dx1 = x(k,j) - lon_base(lon_prev);
        dx2 = dx_base - dx1;
        dy1 = y(k,j) - lat_base(lat_prev);
        dy2 = dy_base - dy1;

        %@@@ Four point interpolation
        sw = depth_base(lat_prev,lon_prev);
        se = depth_base(lat_prev,lon_next);
        nw = depth_base(lat_next,lon_prev);
        ne = depth_base(lat_next,lon_next);

        sw_wt = dy2*dx2;
        se_wt = dy2*dx1;
        nw_wt = dy1*dx2;
        ne_wt = dx1*dy1;
        if isnan(sw) || (sw >= land_val && wet_only) || sw_wt <= eps('single')
          sw_wt = 0;
          sw = 0; % to factor out NaN
        end
        if isnan(se) || (se >= land_val && wet_only) || se_wt <= eps('single')
          se_wt = 0;
          se = 0; % to factor out NaN
        end
        if isnan(nw) || (nw >= land_val && wet_only) || nw_wt <= eps('single')
          nw_wt = 0;
          nw = 0; % to factor out NaN
        end
        if isnan(ne) || (ne >= land_val && wet_only) || ne_wt <= eps('single')
          ne_wt = 0;
          ne = 0; % to factor out NaN
        end

        den = sw_wt + se_wt + nw_wt + ne_wt;
        if den > eps
          depth_sub(k,j) = (sw*sw_wt + se*se_wt + nw*nw_wt + ne*ne_wt)/den;
          assert(isfinite(depth_sub(k,j)), 'breakdown in interpolation');
        end

      else

        %@@@ Cell averaging
        %@@@ Determine the base bathymetry region that covers the cell
        lon_start = min(cell(k,j).px);
        lon_end = max(cell(k,j).px);
        lat_start = min(cell(k,j).py);
        lat_end = max(cell(k,j).py);

        clear depth_tmp lon_tmp lat_tmp;

        [~,lat_start_pos] = min(abs(lat_base-lat_start));
        [~,lat_end_pos] = min(abs(lat_base-lat_end));

        [~,lon_start_pos] = min(abs(lon_base-lon_start));
        [~,lon_end_pos] = min(abs(lon_base-lon_end));

        lat_tmp = lat_base(lat_start_pos:lat_end_pos);
        lon_tmp = lon_base(lon_start_pos:lon_end_pos);
        depth_tmp = depth_base(lat_start_pos:lat_end_pos,lon_start_pos:lon_end_pos);

        %@@@ Compute the average depth from points that lie inside the
        %@@@ the cell and are below the cut off

        clear lon_tmp2d lat_tmp2d in_cell depth_tmp_incell;

        [lon_tmp2d,lat_tmp2d] = meshgrid(lon_tmp,lat_tmp);
        in_cell = inpolygon(lon_tmp2d,lat_tmp2d,cell(k,j).px,cell(k,j).py);
        depth_tmp_incell = depth_tmp(in_cell);
        npnt = numel(depth_tmp_incell);

        wet = ~isnan(depth_tmp_incell) & depth_tmp_incell < land_val;
        nwet = sum(wet,'all');
        if nwet && (nwet/npnt > wet_thresh)
          depth_sub(k,j) = mean(depth_tmp_incell(wet));
        end           

      end %@@@ End of check to see if it will interpolate or average

      %@@@ Counter to check proportion of cells completed
      n = (j-1)*ny+k;
      pct = floor(100*n/np);
      if mod(pct,5) == 0 && pct ~= pct_prev
        fprintf(1,'Completed %d percent of the cells\n', pct);
      end
      pct_prev = pct;

    end %@@@ Loop through lattitudes 
  end %@@@ Loop through longitudes
end


