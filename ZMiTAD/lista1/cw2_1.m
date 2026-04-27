% CWICZENIE 2_1
% Porownanie histogramu i boxplota

clc
clear
close all

% generowanie danych
x1 = 2*(randn(100,1)+1);
x2 = 3*(randn(100,1)-1);

% polaczenie danych w jedna macierz
z = [x1 x2];

% boxplot
subplot(2,1,1)
boxplot(z)
title('Boxplot danych')

% histogram
subplot(2,1,2)
hist(z)
title('Histogram danych')