% CWICZENIE 3
% Generowanie probki z rozkladu normalnego

clc
clear
close all

% losowanie 300 elementow
x = randn(300,1);

% wykres probki
figure
plot(x)
title('Probka z rozkladu normalnego')

% histogram 20 przedzialow
figure
hist(x,20)
title('Histogram - 20 przedzialow')

% histogram 100 przedzialow
figure
hist(x,100)
title('Histogram - 100 przedzialow')

% boxplot
figure
boxplot(x)
title('Boxplot danych')