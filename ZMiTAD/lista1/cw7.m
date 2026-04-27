% CWICZENIE 7
% Obliczanie prawdopodobienstw dla rozkladu normalnego

clc
clear

% P(Z < 2)
P1 = normcdf(2,0,1)

% P(|Z| < 2)
P2 = normcdf(2,0,1) - normcdf(-2,0,1)