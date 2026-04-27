% EXERCISE 9
% Test normality of capacitor capacity

clc
clear
close all

alpha = 0.05;

data = readtable("kondensatory.csv");

capacity = data.pojemnosc;

% Lilliefors test

[h,p,L,CV] = lillietest(capacity,'Alpha',alpha);

fprintf("p-value = %.4f\n",p)

if h == 1
    fprintf("Reject H0: distribution is not normal\n")
else
    fprintf("Cannot reject H0: distribution may be normal\n")
end

% QQ plot

figure
qqplot(capacity)
title("QQ plot - capacitor capacity")