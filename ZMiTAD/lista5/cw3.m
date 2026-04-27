% EXERCISE 3

clc
clear
close all

data = readtable('chmiel.csv');
before = data.niezapyl;
after = data.zapylona; 

% Wilcoxon (sparowane próbki)
[p_wil, h_wil, stats_wil] = signrank(before, after, 'tail', 'right'); % right: testujemy, czy zapylenie ZWIĘKSZA masę
fprintf('Test Wilcoxona, masa nasion (zapylenie): p=%.4g, h=%d\n', p_wil, h_wil);

if h_wil
    disp('Zapylenie istotnie zwiększa masę nasion!');
else
    disp('Nie stwierdzono istotnej zmiany masy nasion po zapyleniu');
end