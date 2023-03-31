% wrapping compute_boundary() with domain setup for both global/regional approaches
%
function [bound_ingrid] = ext_compute_boundary(lon,lat,dx,dy,bound,bflg)

  [glb,~] = ext_is_global_extent(lon,dx);
  
  if glb
    
    %% this code adapted from the global example
    %  not sure why it is necessary to split polygons
    %  not sure why they specify the global extent as 360 rather than 360-dx
    
    % Split the domain into two parts to avoid polygons improperly wrapping around
    grid_box1 = [lat(1)   0 lat(end) 180];
    grid_box2 = [lat(1) 180 lat(end) 360];
    
    % Extract the boundaries from the GSHHS and the optional databases
    % the subset of polygons within the grid domain are stored in b and b_opt
    % for GSHHS and user defined polygons respectively
    [ba,~] = compute_boundary(grid_box1,bound,bflg);
    [bb,~] = compute_boundary(grid_box2,bound,bflg);
    
    % revised compute_boundary() to allow blind concatenation with empty results
    bound_ingrid = [ba bb];
    
  else
    
    %% this code adapted from the regional example

    % Set the domain big enough to include the cells along the edges of the grid (handles CURV also)
    lons = min(min(lon))-dx;
    lone = max(max(lon))+dx;
    lats = min(min(lat))-dy;
    late = max(max(lat))+dy;

    % Extract the boundaries from the GSHHS and the optional databases
    % the subset of polygons within the grid domain are stored in b and b_opt
    % for GSHHS and user defined polygons respectively
    grid_box = [lats lons late lone];
    [bound_ingrid,~] = compute_boundary(grid_box,bound,bflg);

  end
  
end
