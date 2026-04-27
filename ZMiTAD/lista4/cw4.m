% EXERCISE 4

clc
clear
close all

data = readtable('absolwenci.csv');
wydzialy = unique(data.Faculty);

for i = 1:numel(wydzialy)
    fac = wydzialy{i};
    women = data.Salary5Year(strcmp(data.Faculty, fac) & strcmp(data.Gender, 'F'));
    men   = data.Salary5Year(strcmp(data.Faculty, fac) & strcmp(data.Gender, 'M'));
    % Wywal NaN
    women = women(~isnan(women));
    men   = men(~isnan(men));
    nF = numel(women);
    nM = numel(men);
    fprintf('\n--- Wydział: %s ---\n', fac);
    fprintf('Kobiet (F):    %d\n', nF);
    fprintf('Mężczyzn (M):  %d\n', nM);
    
    if nF > 1 && nM > 1
        if nF == nM
            disp('Liczba kobiet i mężczyzn jest taka sama.');
            disp('UWAGA: Równość liczebności NIE wystarczy, by można było wykonać test t dla prób zależnych!');
            disp('Osoby nie są sparowane (to różni ludzie), więc test t dla prób parowanych NIE MA SENSU.');
            disp('Prawidłowy jest test t dla prób NIEZALEŻNYCH (ttest2).');
        else
            disp('Liczba kobiet i mężczyzn NIE jest równa.');
            disp('Próby są niezależne — prawidłowy test: t-test dla prób niezależnych (ttest2).');
        end

        [H, P, CI, STATS] = ttest2(women, men, 0.05, 'both', 'unequal');
        fprintf('t-test niezależny: H=%d, p=%.4f, 95%% CI=[%.2f, %.2f], tstat=%.2f, df=%.1f\n', ...
            H, P, CI(1), CI(2), STATS.tstat, STATS.df);

        if H
            disp('=> Odrzucamy hipotezę o równości średnich (różnica ISTOTNA przy p<0.05).');
        else
            disp('=> Brak podstaw do odrzucenia hipotezy o równości średnich (p>=0.05).');
        end
    else
        disp('Za mało danych w jednej z grup, by wykonać test t.');
    end
end

disp('--- WYJAŚNIENIE ---');
disp(['Test t dla prób zależnych JEST DOPUSZCZALNY tylko gdy obserwacje są sensownie sparowane (np. te same osoby przed/po, bliźnięta, para). ' ...
     'Równe liczności grup to za mało! Gdy mamy różne osoby i zero logicznych par, stosujemy t-test dla prób niezależnych – nawet jeśli liczba kobiet i mężczyzn jest równa.']);