% EXERCISE 4
% Compare distributions of height of men and women

clc
clear
close all

data = readtable("pacjenci.csv");

% split by gender
men = data.wzrost(strcmp(data.plec,'M'));
women = data.wzrost(strcmp(data.plec,'K'));

% KS test
[h,p,ksstat] = kstest2(men,women);

fprintf("Kolmogorov-Smirnov test\n")
fprintf("KS statistic: %.4f\n",ksstat)
fprintf("p-value: %.4f\n",p)

if h==1
    fprintf("Reject H0: distributions differ\n")
else
    fprintf("Cannot reject H0: distributions are similar\n")
end

% normality tests
[h_m,p_m] = lillietest(men);
[h_w,p_w] = lillietest(women);

fprintf("\nNormality test (men) p-value: %.4f\n",p_m)
fprintf("Normality test (women) p-value: %.4f\n",p_w)

% QQ plots
figure

subplot(1,2,1)
qqplot(men)
title("QQ plot - men height")

subplot(1,2,2)
qqplot(women)
title("QQ plot - women height")