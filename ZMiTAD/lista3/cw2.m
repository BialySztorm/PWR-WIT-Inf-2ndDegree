% EXERCISE 2
% Empirical CDF with logarithmic X scale

clc
clear
close all

controlB = [0.08 0.10 0.15 0.17 0.24 0.34 0.38 0.42 0.49 0.50 ...
            0.70 0.94 0.95 1.26 1.37 1.55 1.75 3.20 6.98 50.57];

data_sorted = sort(controlB);

n = length(data_sorted);
ecdf = (1:n)/n;

figure
stairs(data_sorted,ecdf,'LineWidth',2)

set(gca,'XScale','log')

xlabel("x (log scale)")
ylabel("F(x)")
title("Empirical CDF (log scale)")
grid on