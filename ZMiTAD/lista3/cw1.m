% EXERCISE 1
% Empirical CDF for dataset controlB

clc
clear
close all

controlB = [0.08 0.10 0.15 0.17 0.24 0.34 0.38 0.42 0.49 0.50 ...
            0.70 0.94 0.95 1.26 1.37 1.55 1.75 3.20 6.98 50.57];

% sort data
data_sorted = sort(controlB);

n = length(data_sorted);

% empirical CDF
ecdf = (1:n)/n;

figure
stairs(data_sorted, ecdf,'LineWidth',2)

xlabel("x")
ylabel("F(x)")
title("Empirical CDF - controlB")
grid on