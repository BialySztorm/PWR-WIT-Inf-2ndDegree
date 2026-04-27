% CWICZENIE 4
% Porownanie generatorow liczb pseudolosowych

clc
clear
close all

N = 1000;

% generowanie danych
y1 = gen1(1,N);
y2 = gen2(1,N);
y3 = gen3(1,N);
y4 = rand(N,1);

% histogramy
subplot(2,2,1)
hist(y1)
title('gen1')

subplot(2,2,2)
hist(y2)
title('gen2')

subplot(2,2,3)
hist(y3)
title('gen3')

subplot(2,2,4)
hist(y4)
title('rand')

% srednie
mean(y1)
mean(y2)
mean(y3)
mean(y4)

% wariancje
var(y1)
var(y2)
var(y3)
var(y4)