function ext_plot_grid(ifig, lon, lat, data, vname, gname, suffix, out_dir)
  
  figure(ifig); clf;
  pcolor(lon, lat, data);
  shading(gca, 'flat');
  colormap jet; colorbar;
  set(gca, 'fontsize', 14);
  title(sprintf('%s for %s', vname, gname), 'fontsize', 14, 'Interpreter', 'none');
  daspect([1 1 1]);
  if ~isempty(out_dir)
    savefig(sprintf('%s/%s%s.fig', out_dir, gname, suffix));
    print('-r600', sprintf('%s/%s_%s.png', out_dir, gname, suffix), '-dpng');
  end

end

