function ext_write_grid(lon, lat, data, gname, suffix, out_dir)
  
  % write a more useful format with a header for external visualization
  %
  [ny, nx] = size(lon);
  if ny==1 || nx == 1
    nx = numel(lon);
    ny = numel(lat);
    dx = lon(2) - lon(1);
    dy = lat(2) - lat(1);
    ox = lon(1);
    oy = lat(1);
  else
    dx = lon(1,2) - lon(1,1);
    dy = lat(2,1) - lat(1,1);
    ox = lon(1,1);
    oy = lat(1,1);
  end
  
  data = data';

  fmt = repmat('%.2f ', 1, nx);
  fmt = [fmt(1:end-1) '\n'];

  fid = fopen(sprintf('%s/%s_%s.fd', out_dir, gname, suffix), 'w');
  fprintf(fid, '%d %d %.12f %.12f 0.0 1 %.12f %.12f\n', nx, ny, dx, dy, ox, oy);
  for iy = 1:ny
    fprintf(fid, fmt, data(:,iy));
  end
  fclose(fid);

end

