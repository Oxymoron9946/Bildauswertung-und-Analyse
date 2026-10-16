%% Führt alle Tests aus (Einheitentests, GUI-Rauchtest, Regressionstest)
% Der Regressionstest braucht die Messvideos und dauert ca. 10 min;
% ohne Videos wird er übersprungen.

ergebnis = runtests(fileparts(mfilename('fullpath')));
disp(table(ergebnis));
assertSuccess(ergebnis);
