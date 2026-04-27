% EXERCISE 8
% Test normality of bulb lifetime

clc
clear
close all

alpha = 0.1;

data = readtable("zarowki.csv");

lifetimes = data.czas;

% Lilliefors normality test

[h,p,L,CV] = lillietest(lifetimes,'Alpha',alpha);

fprintf("p-value = %.4f\n",p)

if h == 1
    fprintf("Reject H0: distribution is not normal\n")
else
    fprintf("Cannot reject H0: distribution may be normal\n")
end

% QQ plot

figure
qqplot(lifetimes)
title("QQ plot - bulb lifetime")