% EXERCISE 2
% Test if average delivery time equals 3 days

clc
clear
close all

% --------------------------------
% Sample data (given in task)
% --------------------------------

delivery_days = [1 1 1 2 2 2 2 3 3 3 ...
                 4 4 4 4 4 5 5 6 6 6 7 7];

mu0 = 3;      % hypothesized mean
alpha = 0.05;

% --------------------------------
% Perform one-sample t-test
% H0: mu = 3
% H1: mu ~= 3
% --------------------------------

[h,p] = ttest(delivery_days,mu0,'Alpha',alpha);

% display statistics
sample_mean = mean(delivery_days)
sample_std = std(delivery_days)

h
p