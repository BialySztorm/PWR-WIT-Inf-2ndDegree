% EXERCISE 6

clc
clear
close all

data17 = [172.72,157.48,170.18,172.72,175.26,170.18,154.94,149.86,157.48,154.94,...
          175.26,167.64,157.48,157.48,154.94,177.8];

mu = 164.1475;

[H, P, CI, STATS] = ttest(data17, mu, 0.05, 'both');
fprintf('Test dla jednej próby, wzrost godz 17:\nH = %d, P = %.4g, CI = [%.4f %.4f], tstat = %.4f, df = %d\n', ...
    H, P, CI(1), CI(2), STATS.tstat, STATS.df);

% Jeśli H=1, odrzucasz hipotezę o równości średniej i mu