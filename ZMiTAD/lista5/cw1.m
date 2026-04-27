% EXERCISE 1

clc
clear
close all

% Dane: masa kobiet PRZED i PO diecie
before = [88 69 86 59 57 82 94 93 64 91 86 59 91 60 57 92 70 88 70 85];
after  = [73 68 75 54 53 84 84 86 66 84 78 58 91 57 59 88 71 84 64 85];

% Wizualizacja (boxplot i histogram różnicy)
figure
subplot(1,2,1)
boxplot([before' after'],'Labels', {'przed', 'po'}); title('Boxplot wag');
subplot(1,2,2)
histogram(before-after); title('Histogram różnic (przed-po)');
xlabel('Różnica masy [kg]');

% Test znaków (czy mediana różnicy = 0)
[p_sgn, h_sgn, stats_sgn] = signtest(before, after, 0.05, 'tail', 'right');
fprintf('Test znaków (czy masa po diecie < przed): p=%.4g, h=%d, n_znak=%d\n', p_sgn, h_sgn, stats_sgn.sign);

% Test Wilcoxona (czy rozkład wag się przesunął)
[p_wil, h_wil, stats_wil] = signrank(before, after, 'tail', 'right');
fprintf('Test Wilcoxona: p=%.4g, h=%d, stat=%.4g\n', p_wil, h_wil, stats_wil.signedrank);

% Interpretacja w konsoli
if h_wil
    disp('Odrzucamy H0 – dieta prawdopodobnie działa (masa średnio się obniżyła)');
else
    disp('Brak podstaw do odrzucenia H0 – nie udowodniliśmy skuteczności diety');
end