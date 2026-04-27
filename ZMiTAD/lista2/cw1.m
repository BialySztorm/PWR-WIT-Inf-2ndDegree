% EXERCISE 1
% Verification of hypothesis about mean travel time

clc
clear
close all

% --------------------------------
% Parameters given in the task
% --------------------------------

mu0 = 28;          % hypothesized population mean
sample_mean = 31.5;
sample_std = 5;
n = 100;
alpha = 0.05;

% --------------------------------
% Generate sample with given parameters
% --------------------------------

sample_data = sample_mean + sample_std*randn(n,1);

% --------------------------------
% Perform t-test
% H0: mu = 28
% H1: mu ~= 28
% --------------------------------

[h,p] = ttest(sample_data,mu0,'Alpha',alpha);

% display results
h
p