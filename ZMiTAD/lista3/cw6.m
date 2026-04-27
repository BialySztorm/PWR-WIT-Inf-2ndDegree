%% EXERCISE 6
% Test normality of height of men and women
% Compare Lilliefors (lillietest) and Kolmogorov-Smirnov (kstest) results

clc
clear
close all

% Load data
data = readtable('pacjenci.csv');

% Split by gender using strcmp (works for cell arrays and strings)
men = data.wzrost(strcmp(data.plec,'M'));
women = data.wzrost(strcmp(data.plec,'K'));

%% Lilliefors test (normality)
% Null hypothesis H0: data comes from normal distribution
% H1: data is not normal

[h_m_lillie,p_m_lillie] = lillietest(men);
[h_w_lillie,p_w_lillie] = lillietest(women);

fprintf('Lilliefors Test:\n')
fprintf('Men height: h=%d, p=%.4f\n', h_m_lillie, p_m_lillie)
fprintf('Women height: h=%d, p=%.4f\n', h_w_lillie, p_w_lillie)

%% Kolmogorov-Smirnov test against normal distribution
% Compute CDF for normal distribution with sample mean and std
cdf_men = normcdf(men, mean(men), std(men,1));
cdf_women = normcdf(women, mean(women), std(women,1));

[h_m_ks,p_m_ks,ksstat_m,cv_m] = kstest(men,[men,cdf_men],0.05);
[h_w_ks,p_w_ks,ksstat_w,cv_w] = kstest(women,[women,cdf_women],0.05);

fprintf('\nKolmogorov-Smirnov Test:\n')
fprintf('Men height: h=%d, p=%.4f, KSstat=%.4f, CV=%.4f\n', h_m_ks, p_m_ks, ksstat_m, cv_m)
fprintf('Women height: h=%d, p=%.4f, KSstat=%.4f, CV=%.4f\n', h_w_ks, p_w_ks, ksstat_w, cv_w)

%% QQ plots
figure
subplot(1,2,1)
qqplot(men)
title('QQ plot - men height')

subplot(1,2,2)
qqplot(women)
title('QQ plot - women height')