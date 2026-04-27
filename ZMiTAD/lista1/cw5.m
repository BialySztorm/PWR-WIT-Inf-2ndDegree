% CWICZENIE 5
% Histogramy wybranych atrybutow liczbowych z plikow iris.txt oraz glass.txt

clc
clear
close all

% ---------------------------------------------------
% WCZYTANIE DANYCH
% ---------------------------------------------------

iris = readtable('iris.txt');
glass = readtable('glass.txt');

% ---------------------------------------------------
% HISTOGRAMY DANYCH IRIS
% ---------------------------------------------------

figure

subplot(2,2,1)
hist(iris{:,1},10)
title('Iris - atrybut 1')
xlabel('wartosci')
ylabel('liczba probek')

subplot(2,2,2)
hist(iris{:,2},10)
title('Iris - atrybut 2')
xlabel('wartosci')
ylabel('liczba probek')

subplot(2,2,3)
hist(iris{:,3},10)
title('Iris - atrybut 3')
xlabel('wartosci')
ylabel('liczba probek')

subplot(2,2,4)
hist(iris{:,4},10)
title('Iris - atrybut 4')
xlabel('wartosci')
ylabel('liczba probek')

% ---------------------------------------------------
% HISTOGRAMY DANYCH GLASS
% ---------------------------------------------------

figure

subplot(1,3,1)
hist(glass{:,1},10)
title('Glass - atrybut 1')
xlabel('wartosci')
ylabel('liczba probek')

subplot(1,3,2)
hist(glass{:,2},10)
title('Glass - atrybut 2')
xlabel('wartosci')
ylabel('liczba probek')

subplot(1,3,3)
hist(glass{:,3},10)
title('Glass - atrybut 3')
xlabel('wartosci')
ylabel('liczba probek')