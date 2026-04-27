% EXERCISE 8

clc
clear
close all

data13 = [175.26,177.8,167.64,160.02,172.72,177.8,175.26,170.18,157.48,160.02,...
         193.04,149.86,157.48,157.48,190.5,157.48,182.88,160.02];
data17 = [172.72,157.48,170.18,172.72,175.26,170.18,154.94,149.86,157.48,154.94,...
          175.26,167.64,157.48,157.48,154.94,177.8];

% Hipotezy: H0 = wzrost równy, H1 = jest różnica
[p, h, stats] = ranksum(data13, data17, 'alpha', 0.05);
fprintf('Test Manna-Whitneya wzrost grupa 13 vs 17: h = %d, p = %.4g, ranksum = %.4f\n', h, p, stats.ranksum);

% Jeśli h=1, odrzucamy H₀ - wzrosty się różnią.