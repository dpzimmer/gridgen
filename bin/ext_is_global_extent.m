% global defined as from 0 to 360-dx, or from 0 to 360
% this will almost surely return false for CURV, which is appropriate
%
function [rc,wrap] = ext_is_global_extent(lon,dx)

  x1 = lon(1);
  x2 = lon(end);
  if x2 < x1
    x2 = x2 + 360;
  end
  rx = x2 - x1;
  wrap = abs(rx-360) <= eps('single');
  rc = wrap || abs(rx+dx-360) <= eps('single');
  
end
