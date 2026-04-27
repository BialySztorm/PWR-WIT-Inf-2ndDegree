% EXERCISE 10
% Normality of salaries for agriculture and pedagogy graduates

clc
clear
close all

alpha = 0.05;

data = readtable("absolwenci.xls");

agriculture = data.rolnictwo;
pedagogy = data.pedagogika;

% --- normality tests ---

[h_a,p_a] = lillietest(agriculture);
[h_p,p_p] = lillietest(pedagogy);

fprintf("AGRICULTURE\n")
fprintf("p-value = %.4f\n",p_a)

if h_a == 1
    fprintf("Reject H0: distribution is not normal\n")
else
    fprintf("Cannot reject H0: distribution may be normal\n")
end

fprintf("\nPEDAGOGY\n")
fprintf("p-value = %.4f\n",p_p)

if h_p == 1
    fprintf("Reject H0: distribution is not normal\n")
else
    fprintf("Cannot reject H0: distribution may be normal\n")
end

% --- QQ plots ---

figure

subplot(1,2,1)
qqplot(agriculture)
title("QQ plot - agriculture salaries")

subplot(1,2,2)
qqplot(pedagogy)
title("QQ plot - pedagogy salaries")