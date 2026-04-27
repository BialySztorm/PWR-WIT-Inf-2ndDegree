% EXERCISE 2

clc
clear
close all

% Wczytaj dane (np. plik .mat)
load('anova_data.mat', 'wombats', 'wombat_groups');

groups = unique(wombat_groups);
for i = 1:numel(groups)
    % Dla categorical lub string:
    ind = wombat_groups == groups(i); % Działa dla categorical i string!
    data_g = wombats(ind);
    [h,p] = lillietest(data_g);
    fprintf('Grupa %s: p = %.4f, normalność: %d\n', string(groups(i)), p, ~h);
end

[p_bart,~] = vartestn(wombats(:), wombat_groups(:), 'TestType','Bartlett','Display','off');
fprintf('Bartlett p = %.4f %s\n', p_bart, ternary(p_bart>0.05,'(wariancje równe)','(wariancje różne)'));

[p, tbl, stats] = anova1(wombats, wombat_groups);

if p > 0.05
    disp('Brak istotnych różnic średnich między grupami.');
else
    disp('Istnieje istotna różnica średnich wśród grup!');
    multcompare(stats);
end

function o = ternary(cond,a,b)
if cond, o=a; else, o=b; end
end