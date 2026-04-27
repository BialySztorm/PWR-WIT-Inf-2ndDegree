% EXERCISE 5

clc
clear
close all

FEV = [
4.64 5.12 4.64 3.21 3.92 4.95 3.75 2.95 2.95
5.92 6.10 4.32 3.17 3.75 5.22 2.50 3.21 2.80
5.25 4.85 4.13 3.88 4.01 5.16 2.65 3.15 3.63
6.17 4.72 5.17 3.50 4.64 5.35 2.84 3.25 3.85
4.20 5.36 3.77 2.47 3.63 4.35 3.09 2.30 2.19
5.90 5.41 3.85 4.12 3.46 4.89 2.90 2.76 3.32
5.07 5.31 4.12 3.51 4.01 5.61 2.62 3.01 2.68
4.13 4.78 5.07 3.85 3.39 4.98 2.75 2.31 3.35
4.07 5.08 3.25 4.22 3.78 5.77 3.10 2.50 3.12
5.30 4.97 3.49 3.07 3.51 5.23 1.99 2.02 4.11
4.37 5.85 3.65 3.62 3.19 4.76 2.42 2.64 2.90
3.76 5.26 4.10 2.95 4.04 5.15 2.37 2.27 2.75
];
% Tworzymy zmienne grupujące
nRep = size(FEV,1);    % 12 powtórzeń
nComb = size(FEV,2);   % 9 kombinacji substancja-zakład

% Rozwiązujemy indeksy: które kolumny to która substancja i który zakład
% (każda z 9 kolumn = substancja (1,2,3), zakład (1,2,3))
[zak, toks] = meshgrid(1:3, 1:3);        % zakład: kolumny szybciej się zmieniają
group_zaklad = repmat(zak(:)', nRep, 1); % powtórz po 12 rzędów
group_toksyn = repmat(toks(:)', nRep, 1);

Y = FEV(:); % zamieniamy na wektor
group_zaklad = group_zaklad(:);
group_toksyn = group_toksyn(:);

% Sprawdzenie normalności i równości wariancji: jw. (możesz dodać)

% ANOVA z 2 czynnikami:
[p, tbl, stats] = anovan(Y, {group_toksyn, group_zaklad}, 'model','interaction', ...
    'varnames', {'Toksyczna', 'Zaklad'});

% Interpretacja
if p(1)<0.05, disp('Wpływ substancji istotny!'); end
if p(2)<0.05, disp('Wpływ zakładu istotny!'); end
if p(3)<0.05, disp('Interakcja istotna!'); end

% Post-hoc dla substancji
disp('Post-hoc dla substancji:');
multcompare(stats, 'Dimension', 1)