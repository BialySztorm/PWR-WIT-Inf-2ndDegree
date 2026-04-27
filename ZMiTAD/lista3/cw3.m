% EXERCISE 3
% Empirical CDF for controlA and treatmentA

clc
clear
close all

controlA = [0.22 -0.87 -2.39 -1.79 0.37 -1.54 1.28 -0.31 -0.74 ...
            1.72 0.38 -0.17 -0.62 -1.10 0.30 0.15 2.30 0.19 ...
            -0.50 -0.09];

treatmentA = [-5.13 -2.19 -2.43 -3.83 0.50 -3.25 4.32 1.63 5.18 ...
             -0.43 7.11 4.87 -3.10 -5.81 3.76 6.31 2.58 0.07 ...
              5.76 3.50];

x = sort([controlA(:);treatmentA(:)]);

F1 = arrayfun(@(v) mean(controlA <= v), x);
F2 = arrayfun(@(v) mean(treatmentA <= v),x);

[D, idx] = max(abs(F1 - F2));


figure

plot(x, F1, 'b', 'LineWidth', 2);
hold on
plot(x, F2, 'r', 'LineWidth', 2);
plot([x(idx), x(idx)], [F1(idx), F2(idx)], 'y', 'LineWidth', 2);

legend("controlA","treatmentA", "D statistic")
title(sprintf("ECDF comparison, D = %.3f", D))
xlabel("x")
ylabel("F(x)")
grid on