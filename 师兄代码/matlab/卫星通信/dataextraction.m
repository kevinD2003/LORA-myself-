h =findall(gca, 'type', 'line');
x = get(h, 'Xdata');
y = get(h, 'Ydata');
h = figure();
ax = axes(h);
hold on;
for i=1:length(x)
plot(ax,x{i},y{i});     
end

