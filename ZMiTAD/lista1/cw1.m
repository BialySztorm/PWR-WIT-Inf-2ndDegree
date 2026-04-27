% CWICZENIE 1
% Podstawowe operacje na macierzach w MATLAB

clc
clear
close all

% tworzenie zmiennej
a = 1;

% wyswietlenie wszystkich zmiennych w workspace
who

% macierz zer
A = zeros(3,3)

% macierz jedynek
B = ones(2,4)

% macierz jednostkowa
C = eye(4)

% powielanie macierzy
D = repmat([1 2;3 4],2,2)

% losowe liczby z rozkladu jednostajnego (0,1)
E = rand(3,3)

% losowe liczby z rozkladu normalnego N(0,1)
F = randn(3,3)

% rozmiar macierzy
size(E)

% dlugosc wektora
length(E)

% reczne tworzenie macierzy
A = [1,2,3,4;5,6,7,8;9,1,2,3]

% transpozycja macierzy
AT = A'

% operacje na macierzach
X = [1 2;3 4]
Y = [5 6;7 8]

dodawanie = X + Y
odejmowanie = X - Y
mnozenie_macierzy = X * Y
mnozenie_elementow = X .* Y

% odczyt elementu macierzy (wiersz 1 kolumna 2)
element = Y(1,2)