% EXERCISE 7
% Shapiro-Wilk test for sugar variable

clc
clear
close all

alpha = 0.05;

data = readtable("pacjenci.csv");

sugar = data.cukier;

% Shapiro-Wilk test

[H, pValue] = lillietest(sugar);

fprintf("Shapiro-Wilk test\n")
fprintf("p-value = %.4f\n",pValue)

if H == 1
    fprintf("Reject H0: distribution is not normal\n")
else
    fprintf("Cannot reject H0: distribution may be normal\n")
end

% QQ plot

figure
qqplot(sugar)
title("QQ plot - sugar level")