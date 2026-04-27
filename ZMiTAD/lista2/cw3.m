% EXERCISE 3
% Test of hypothesis about average real estate price growth

clc
clear
close all

% --------------------------------
% Given sample statistics
% --------------------------------

mu0 = 49;     % hypothesized growth (%)
sample_mean = 38;
sample_std = 14;

n = 18;
alpha = 0.01;

% --------------------------------
% Generate sample with given parameters
% --------------------------------

growth_data = sample_mean + sample_std*randn(n,1);

% --------------------------------
% Perform t-test
% --------------------------------

[h,p] = ttest(growth_data,mu0,'Alpha',alpha);

% manual calculation using t statistic
t_stat = (mean(growth_data)-mu0)/(std(growth_data)/sqrt(n));

% probability from t distribution
p_manual = 2*(1-tcdf(abs(t_stat),n-1));

h
p
t_stat
p_manual