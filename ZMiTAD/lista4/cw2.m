% EXERCISE 2

clc
clear
close all

nerwowi = [3 3 4 5 5];
spokojni = [4 6 7 9 9];

% Hipotezy:
% H0: Średnia gestykulacja obu grup jest taka sama.
% H1: Średnia się różni (dwustronny).

% Test t
[H, P, CI, STATS] = ttest2(nerwowi, spokojni, 0.05, 'both', 'equal');
fprintf('T-Test, gestykulacja spokojni vs nerwowi:\nH = %d, P = %.4f, CI = [%.3f %.3f], tstat = %.3f, df = %.1f\n', ...
    H, P, CI(1), CI(2), STATS.tstat, STATS.df);

% Stopień swobody = n1+n2-2 = 8
% Można użyć testu t, dwustronny. Jeśli H=1, średnie różnią się istotnie.