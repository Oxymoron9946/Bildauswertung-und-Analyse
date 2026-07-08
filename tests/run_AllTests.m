% RUN_ALLTESTS Führt alle Unit Tests im Projekt aus.
% Dieses Skript sucht im Ordner 'tests' nach Klassen, die von
% matlab.unittest.TestCase erben, und führt sie aus.

clc; clear;

% Bestimme das Test-Verzeichnis
testDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testDir);

% Füge alle Quellcode-Ordner zum Pfad hinzu, damit die Tests die Funktionen finden
addpath(fullfile(projectRoot, 'src', 'core'));
addpath(fullfile(projectRoot, 'src', 'io'));
addpath(fullfile(projectRoot, 'src', 'utils'));
addpath(fullfile(projectRoot, 'src', 'config'));

fprintf('==================================================\n');
fprintf('STARTE MATLAB UNIT TESTS\n');
fprintf('==================================================\n\n');

% Erstelle die Test-Suite aus dem Ordner
import matlab.unittest.TestSuite;
suite = TestSuite.fromFolder(testDir);

% Führe die Tests aus
runner = matlab.unittest.TestRunner.withTextOutput();
results = runner.run(suite);

% Zeige eine Zusammenfassung
fprintf('\n==================================================\n');
if all([results.Passed])
    fprintf('ERFOLG: Alle %d Tests wurden bestanden!\n', numel(results));
else
    numFailed = sum([results.Failed]);
    fprintf('FEHLER: %d von %d Tests sind fehlgeschlagen.\n', numFailed, numel(results));
end
fprintf('==================================================\n');