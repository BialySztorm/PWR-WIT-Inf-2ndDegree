% EXERCISE 5

clc
clear
close all

data = readtable('dane z koronografii.csv');

% Podział na grupy (grupa 1 i grupa 2)
group1 = data.time(data.group == 1); % grupa 1
group2 = data.time(data.group == 2); % grupa 2

% Test nieparametryczny dla prób niezależnych: ranksum
[p_rs, h_rs, stats_rs] = ranksum(group1, group2, 'alpha', 0.1); % 90% confidence
fprintf('Test ranksum, czas ćwiczenia vs stan zdrowia: p=%.4g, h=%d\n', p_rs, h_rs);

if h_rs
    disp('Czas ćwiczeń ISTOTNIE zależy od stanu zdrowia (na poziomie 0.1)');
else
    disp('Brak istotnej różnicy (poziom 0.1)');
end