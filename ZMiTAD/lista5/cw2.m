% EXERCISE 2

clc
clear
close all

% Wczytywanie danych
data = readtable('czytelnictwo.csv');
przed = data.przed;
po = data.po;

[p_sgn, h_sgn] = signtest(przed, po, 0.05, 'tail', 'both');
[p_wil, h_wil] = signrank(przed, po, 'tail', 'both');

fprintf('Test SIGNS: h=%d, p=%.4g (dwustronny)\n', h_sgn, p_sgn);
fprintf('Test Wilcoxona: h=%d, p=%.4g (dwustronny)\n', h_wil, p_wil);

if h_wil
    disp('Po podjęciu pracy CZAS czytania się ZMIENIŁ (nie wiemy w którą stronę)');
else
    disp('BRAK dowodu na zmianę czasu czytania po zatrudnieniu');
end