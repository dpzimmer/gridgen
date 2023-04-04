function ext_create_grid(fname, lon, lat, varargin)

  % Defaults
  out_dir = '.';        % directory where all output files are saved
  grid_type = 'RECT';   % or CURV
  ref_grid = 'etopo1';  % reference grid source 
  boundary = 'full';    % option to determine which GSHHS.mat file to load
  user_poly = '';       % file with switches for using user defined polygons
  land_val = 0.0;       % bathymetry level indicating dry cells, all values below this level are considered wet
  dry_val = 999999;     % depth value for dry cells (can change as desired)
  wet_only = 1;         % only consider wet points in interpolation (can result in wet points > MSL)
  wet_max = -0.1;       % enforce wet points are no greater than this elevation (when wet_only = 0)
  poly_thresh = 0.5;    % (0.5) Fraction of cell that has to be inside a polygon for cell to be marked dry
  wet_thresh = 0.1;     % (0.1) Proportion of base bathymetry cells that need to be wet for the target cell to be considered wet. 
  obstr_offset = 1;     % See documentation for create_obstr for details
  lake_tol = -1;        % see documentation on remove_lake routine for possible values
  bound_flag = 1;       % maximum boundary level to consider
  plot = 'depth';       % {'depth', 'mask'} what to plot 
  vars = {'x','y','z'}; % variable names for reference grid (unless standard etopo1)
  split = 1;            % split boundary polygons for more efficient computation of land-sea mask, 0=No, 1=Yes
  
  % Optional overrides
  for idx=1:2:numel(varargin)
    if strcmp(varargin{idx}, 'out_dir')
      out_dir = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'ref_grid')
      ref_grid = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'boundary')
      boundary = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'user_poly')
      user_poly = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'land_val')
      land_val = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'wet_only')
      wet_only = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'wet_max')
      wet_max = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'poly_thresh')
      poly_thresh = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'wet_thresh')
      wet_thresh = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'obstr_offset')
      obstr_offset = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'lake_tol')
      lake_tol = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'bound_flag')
      bound_flag = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'plot')
      plot = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'vars')
      vars = varargin{idx+1};
    elseif strcmp(varargin{idx}, 'split')
      split = varargin{idx+1};
    end
  end
  
  % paths
  [bin_dir, ~, ~] = fileparts(mfilename('fullpath'));
  n = length(bin_dir);
  ref_dir = replaceBetween(bin_dir, n-2, n, 'reference_data');
  if ~isfolder(out_dir)
    mkdir(out_dir);
  end
  
  % ext_apply_refgrid() gives us whatever we ask for, but the rest of the code likes 0-360 (at this point)
  lonW = min(min(lon));
  lonE = max(max(lon));
  if (lonW < 0) || (lonE > 360)
    error('grid longitudes must be in the range 0 to 360');
  end
  
  % Generate the grid
  if strcmp(grid_type, 'RECT')
    [ny,nx] = size(lon);
    dx = (lon(end) - lon(1))/(nx-1);
    dy = (lat(end) - lat(1))/(ny-1);
  else % 'CURV'
    dx = max(max(abs(diff(lon,1,1)),[],'all'), max(abs(diff(lon,1,2)),[],'all'));
    dy = max(max(abs(diff(lat,1,1)),[],'all'), max(abs(diff(lat,1,2)),[],'all'));
  end
  max_delta = max([dx dy]);
  
  % no reason to define a global grid having a wrapped longitude
	[glb,wrp] = ext_is_global_extent(lon, dx);
  if glb && wrp
    lon = lon(:,1:end-1); % wrapping is handled in model
  end
  
  fprintf(1,'.........Creating Bathymetry..................\n'); 
  depth = ext_apply_refgrid(lon,lat,ref_dir,ref_grid,wet_thresh,land_val,dry_val,wet_only,vars{1},vars{2},vars{3});
 
  % adjust to datum provided
  valid = depth ~= dry_val;
  depth(valid) = depth(valid) - land_val;
  
  % Load boundary polygon inputs
  fprintf(1,'.........Reading Boundaries..................\n');
  load([ref_dir,'/coastal_bound_',boundary,'.mat']);  %#ok<LOAD>
  if ~isempty(user_poly)
    [bound_user,~] = optional_bound(ref_dir,user_poly); % revised return for empty set
  else
    bound_user = [];
  end

  % Computing boundaries within the domain
  fprintf(1,'.........Computing Boundaries..................\n');
  b = ext_compute_boundary(lon,lat,dx,dy,bound,bound_flag);
  if ~isempty(bound_user)
    b_opt = ext_compute_boundary(lon,lat,dx,dy,bound_user,bound_flag);     
  else
    b_opt = [];
  end

  % Set up Land - Sea Mask

  % Set up initial land sea mask. The cells can either all be set to wet
  % or to make the code more efficient the cells marked as dry in 
  % 'generate_grid' can be marked as dry cells
  m = ones(size(depth)); 
  m(depth == dry_val) = 0; 

  % XXX - split_boundary does not play nice with great lakes polygons
  %     - this may be due to the resolution of the polygons?
  %     - this needs investigating, and perhaps should be an option
  %     - turn off splitting until resolved
  
  % Split the larger GSHHS polygons for efficient computation of the 
  % land sea mask. This is an optional step but recomended as it  
  % significantly speeds up the computational time. Rule of thumb is to
  % set the limit for splitting the polygons at least 4-5 times dx,dy
  fprintf(1,'.........Splitting Boundaries..................\n');

  if split == 0 
    b_split = b; %THIS WORKS FOR GREAT LAKES
  else
    b_split = split_boundary(b,5*max_delta); %THIS DOES NOT WORK FOR GREAT LAKES
  end

  % Get a better estimate of the land sea mask using the polygon data sets.
  % (NOTE : This part will have to be commented out if cells above the 
  % MSL are being marked as wet, like in inundation studies)
  fprintf(1,'.........Cleaning Mask..................\n');
  m2 = clean_mask(lon,lat,m,b_split,poly_thresh,max_delta);

  % Masking out regions defined by optional polygons
  if ~isempty(b_opt)
    m3 = clean_mask(lon,lat,m2,b_opt,poly_thresh,max_delta);       
  else                                              
    m3 = m2;
  end

  % Remove lakes and other minor water bodies
  fprintf(1,'.........Separating Water Bodies..................\n');
  [m4,mask_map] = remove_lake(m3,lake_tol,glb);

  % Cleanup for wet points interpolated above MSL
  if ~wet_only
    depth((m4 ~= 0) & (depth > wet_max)) = wet_max;
  end

  % Generate sub - grid obstruction sets in x and y direction, based on 
  % the final land/sea mask and the coastal boundaries
  fprintf(1,'.........Creating Obstructions..................\n');
  [sx1,sy1] = create_obstr(lon,lat,b,m4,obstr_offset,obstr_offset);      

  % Output to ascii files for WAVEWATCH III
  depth_scale = 1000;
  obstr_scale = 100;

  d = round(depth*depth_scale);
  write_ww3file([out_dir,'/',fname,'.bot'],d);                 

  write_ww3file([out_dir,'/',fname,'.msk'],m4);             

  d1 = round((sx1)*obstr_scale);
  d2 = round((sy1)*obstr_scale);
  write_ww3obstr([out_dir,'/',fname,'.obs'],d1,d2);   
  
  write_ww3meta([out_dir,'/',fname],grid_type,lon,lat,1/depth_scale,1/obstr_scale,1.0,'.bot','.obs','.msk');          
  
  % Vizualization
  if ~isempty(plot)
    if ischar(plot)
      if strcmp(plot, 'all')
        plot = {'depth', 'lake', 'mask', 'obs', 'poly' };
      elseif strcmp(plot, 'grid')
        plot = {'depth', 'lake', 'mask', 'obs' };
      else
        plot = { plot };
      end
    end
    ifig = 0;
    
    if any(strcmp(plot, 'depth'))
      tmp = depth; tmp(m4 == 0) = NaN;
      ifig = ifig+1;
      ext_plot_grid(ifig, lon, lat, tmp, 'Bathymetry', fname, 'depth', out_dir);
    end
    
    if any(strcmp(plot, 'lake'))
      tmp = mask_map; tmp(mask_map == -1) = NaN;
      ifig = ifig+1;
      ext_plot_grid(ifig, lon, lat, tmp, 'Different water bodies', fname, 'lake', out_dir);
    end

    if any(strcmp(plot, 'mask'))
      ifig = ifig+1;
      figure(ifig); clf;
      ext_plot_grid(ifig, lon, lat, m4, 'Land-Sea Mask', fname, 'mask', out_dir);
    end

    if any(strcmp(plot, 'obs'))
      tmp = sx1; tmp(m4 == 0) = NaN;
      ifig = ifig+1;
      ext_plot_grid(ifig, lon, lat, tmp, 'Sx obstruction', fname, 'obsX', out_dir);
      
      tmp = sy1; tmp(m4 == 0) = NaN;
      ifig = ifig+1;
      ext_plot_grid(ifig, lon, lat, tmp, 'Sy obstruction', fname, 'obsY', out_dir);
    end
    
    if any(strcmp(plot, 'poly'))
      
      cc = {'y','b','r','k'}; % NOTE: there is a level 4 boundary type!
      
      % only plot full boundaries for a custom set
      if ~any(strcmp({'low','inter','high','full'}, boundary))
        ifig = ifig+1;
        figure(ifig); clf;
        for ii=1:numel(bound)
          patch(bound(ii).x, bound(ii).y, cc{bound(ii).level});
          hold on;
        end
        hold off;
        set(gca,'fontsize',14);
        title(['Boundaries Available ',fname],'fontsize',14,'Interpreter','none');
        savefig([out_dir,'/',fname,'_bound_all.fig']);
      end
      
      % only plot boundaries used for regional models
      if ~glb
        ifig = ifig+1;
        figure(ifig); clf;
        for ii=1:numel(b)
          patch(b(ii).x, b(ii).y, cc{b(ii).level});
          hold on;
        end
        hold off;
        set(gca,'fontsize',14);
        title(['Boundaries used for ',fname],'fontsize',14,'Interpreter','none');
        savefig([out_dir,'/',fname,'_bound_used.fig']);

        ifig = ifig+1;
        figure(ifig); clf;
        for ii=1:numel(b_split)
          patch(b_split(ii).x, b_split(ii).y, cc{b_split(ii).level});
          hold on;
        end
        hold off;
        set(gca,'fontsize',14);
        title(['Split boundaries for ',fname],'fontsize',14,'Interpreter','none');
        savefig([out_dir,'/',fname,'_bound_split.fig']);
      end
    end
  end
end

