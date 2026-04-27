% EXERCISE 4
% Test of hypothesis about variance of assembly time

clc
clear
close all

% --------------------------------
% Parameters
% --------------------------------

n = 25;
true_std = 1.5;
alpha1 = 0.05;
alpha2 = 0.1;

% variance from hypothesis
var0 = 1.6;

% --------------------------------
% Generate sample data
% --------------------------------

assembly_time = true_std*randn(n,1);

% --------------------------------
% Variance test
% H0: variance = var0
% H1: variance < var0
% --------------------------------

[h1,p1] = vartest(assembly_time,var0,'Alpha',alpha1,'Tail','left');

[h2,p2] = vartest(assembly_time,var0,'Alpha',alpha2,'Tail','left');

sample_variance = var(assembly_time)

h1
p1

h2
p2