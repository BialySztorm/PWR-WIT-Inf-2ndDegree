% EXERCISE 4

clc
clear
close all

popcorn = [
    5.5 4.5 3.5
    5.5 4.5 4
    6   4   3
    6.5 5   4
    7   5.5 5
    7   5   4.5
];

[p,tbl,stats] = anova2(popcorn,3); % 3 powtórzenia na każdą populację
% p(1): producent, p(2): maszyna, p(3): interakcja
fprintf('p-prod=%.4g, p-masz=%.4g, p-int=%.4g\n', p);

if p(1)<0.05, disp('Różne średnie dla producentów'); end
if p(2)<0.05, disp('Różne średnie dla maszyn'); end
if p(3)<0.05, disp('Jest synergia producent*maszyna'); else disp('Brak interakcji'); end

% Post-hoc dla producentów (kolumny)
multcompare(stats,'Dimension',2)