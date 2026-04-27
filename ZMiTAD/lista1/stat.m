function [mean_val, stdev_val] = stat(x)
% Funkcja oblicza srednia oraz odchylenie standardowe
% x - wektor danych

n = length(x);

% obliczenie sredniej
mean_val = sum(x) / n;

% obliczenie odchylenia standardowego
stdev_val = sqrt(sum((x - mean_val).^2)/n);

end