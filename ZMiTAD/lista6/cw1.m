% EXERCISE 1

clc
clear
close all

% Wczytaj dane
load('anova_data.mat', 'koala'); % lub: koala = readmatrix('anova_data.csv');

% Sprawdzenie normalności – Lilliefors
for g = 1:size(koala,2)
    [h_lillie, p_lillie] = lillietest(koala(:,g));
    fprintf('Grupa %d: Lilliefors p = %.4f, normalnosc: %d\n', g, p_lillie, ~h_lillie);
end

% Sprawdzenie równości wariancji – Bartlett
[p_bartlett, tbl] = vartestn(koala(:), repmat((1:size(koala,2))', size(koala,1),1), ...
    'TestType','Bartlett','Display','off');
fprintf('Bartlett p = %.4f; %s\n', p_bartlett, ternary(p_bartlett>0.05, 'wariancje równe', 'wariancje różne'));

% ANOVA jeśli założenia OK
[p, tbl, stats] = anova1(koala);
title('Boxplot koala');

if p > 0.05
    disp('Brak podstaw do odrzucenia H0: średnie są równe.');
else
    disp('Odrzucamy H0: nastąpiła różnica co najmniej jednej średniej!');
    multcompare(stats);
end

function out = ternary(cond, t, f)
if cond
    out=t; else out=f;
end
end