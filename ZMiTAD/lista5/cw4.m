% EXERCISE 4

clc
clear
close all

data = readtable('czytelnictwo.csv');
przed = data.przed;
po = data.po;

[p_sgn, h_sgn] = signtest(przed, po, 0.05, 'tail', 'right');
[p_wil, h_wil] = signrank(przed, po, 'tail', 'right');
fprintf('Test SIGNS (czy czytają MNIEJ po pracy): h=%d, p=%.4g\n', h_sgn, p_sgn);
fprintf('Test Wilcoxona (czy czytają MNIEJ po pracy): h=%d, p=%.4g\n', h_wil, p_wil);

if h_wil
    disp('Po podjęciu pracy czytają ISTOTNIE MNIEJ prasy!');
else
    disp('BRAK dowodu, że po pracy czytają MNIEJ prasy.');
end