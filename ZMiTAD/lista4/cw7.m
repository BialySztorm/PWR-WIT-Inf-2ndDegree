% EXERCISE 7

clc
clear
close all

nerwowi = [3 3 4 5 5];
spokojni = [4 6 7 9 9];

% Hipotezy: H0: gestykulacja obu grup równie duża, H1: jest różnica

[p, h, stats] = ranksum(nerwowi, spokojni, 'alpha', 0.05);
fprintf('Test Manna-Whitneya dla gestykulacji: h = %d, p = %.4f, ranksum = %.4f\n', h, p, stats.ranksum);

% Jeśli h=1, odrzucamy H₀ o równości wartości, czyli jest różnica.