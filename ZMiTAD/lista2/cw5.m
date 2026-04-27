% EXERCISE 5
% Comparison of variances between two customer groups

clc
clear
close all

% --------------------------------
% Given statistics
% --------------------------------

n_new = 20;
n_old = 22;

mean_new = 27.7;
std_new = 5.5;

mean_old = 32.1;
std_old = 6.3;

alpha = 0.05;

% --------------------------------
% Generate samples with given parameters
% --------------------------------

new_product_age = mean_new + std_new*randn(n_new,1);
old_product_age = mean_old + std_old*randn(n_old,1);

% --------------------------------
% Perform F-test for equality of variances
% H0: variances are equal
% H1: variances differ
% --------------------------------

[h,p] = vartest2(new_product_age,old_product_age,'Alpha',alpha);

% sample variances
var_new = var(new_product_age)
var_old = var(old_product_age)

h
p