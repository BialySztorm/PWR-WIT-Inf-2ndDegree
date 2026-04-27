% CWICZENIE 6
% Generowanie rozkladu N(3,7)

clc
clear
close all

% generowanie danych
x = 3 + sqrt(7)*randn(1000,1);

% histogram
figure
hist(x,30)
title('Histogram rozkladu N(3,7)')

% dystrybuanta empiryczna
figure
[f,xx] = ecdf(x);
plot(xx,f)
title('Dystrybuanta empiryczna')