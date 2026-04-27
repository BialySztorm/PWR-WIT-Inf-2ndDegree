% EXERCISE 3

clc
clear
close all

mniej30 = [6 7 10 9];
po30 = [5 6 2 3];

% Hipotezy:
% H0: średnie równe, H1: nie są równe.
[H, P, CI, STATS] = ttest2(mniej30, po30, 0.05, 'both', 'equal');
fprintf('T-Test, rozbawienie mniej30 vs po30:\nH = %d, P = %.4f, CI = [%.3f %.3f], tstat = %.3f, df = %.1f\n', ...
    H, P, CI(1), CI(2), STATS.tstat, STATS.df);

% Stopień swobody = 4+4-2=6
% H=1: Odrzucamy H₀, średnie są różne.