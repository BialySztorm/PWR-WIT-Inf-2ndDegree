% EXERCISE 5

clc
clear
close all

data13 = [175.26,177.8,167.64,160.02,172.72,177.8,175.26,170.18,157.48,160.02,...
         193.04,149.86,157.48,157.48,190.5,157.48,182.88,160.02];

mu = 169.051; % wartość progowa do testowania

[H, P, CI, STATS] = ttest(data13, mu, 0.05, 'both');
fprintf('Test dla jednej próby, wzrost godz 13:\nH = %d, P = %.4g, CI = [%.4f %.4f], tstat = %.4f, df = %d\n', ...
    H, P, CI(1), CI(2), STATS.tstat, STATS.df);

% Jeśli H=1, odrzucasz hipotezę o równości średniej i mu