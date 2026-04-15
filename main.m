%% Rappresentazione Segnali EMG Grezzi
clear;
close all;
clc;

%% 1. Caricamento Dati
squadra = 1;
load("C:\Users\paolo\Desktop\ISN\protocollo_2\sq1\Acquisizione_1.mat")

% Parametri di campionamento (FS = 2000Hz se Fsamp era 2)
fs = 2000; 
[numChannels, numSamples] = size(data);
t = (0:numSamples-1) / fs; % Calcolo asse del tempo in secondi

%% 2. Creazione Figura
figure('Name', 'Visualizzazione 6 Canali EMG', 'Color', 'w');

for i = 1:numChannels
    subplot(numChannels, 1, i); % Crea un sotto-grafico per ogni canale
    plot(t, data(i, :), 'LineWidth', 0.8);
    
    % Estetica del grafico
    grid on;
    ylabel(['Ch ' num2str(i)]);
    xlim([t(1) t(end)]); % Imposta i limiti dell'asse X sul tempo totale
    
    % Rimuove le etichette dell'asse X tranne che per l'ultimo canale
    if i < numChannels
        set(gca, 'XTickLabel', []);
    else
        xlabel('Tempo [s]');
    end
end

% Titolo generale
sgtitle(['Dati Grezzi MotemaSens']);

%% Filtraggio segnale
%filtraggio di tutti i canali
% 1. Parametri del Filtro
fs = 2000;          % Frequenza di campionamento (cambia se diversa)
f_nyq = fs / 2;     % Frequenza di Nyquist

% Specifiche del filtro passa-banda (frequenze in Hz)
low_cut = 20;       % Taglio basse frequenze (rimozione offset/movimento)
high_cut = 450;     % Taglio alte frequenze (rumore)

% Normalizzazione delle frequenze rispetto alla Nyquist
Wp = [low_cut high_cut] / f_nyq; 
Ws = [10 500] / f_nyq;            % Banda di stop
Rp = 0.5; Rs = 20;               % Ripple e attenuazione

% Calcolo ordine e coefficienti (una sola volta fuori dal ciclo)
[n, Wn] = buttord(Wp, Ws, Rp, Rs);
[b, a] = butter(5, Wp, 'bandpass'); 

%% 2. Esecuzione Filtraggio
filteredData = zeros(size(data)); % Pre-allocazione matrice

for i = 1:6
    % Applica il filtro a ogni canale
    % filtfilt garantisce fase zero (nessun ritardo temporale)
    filteredData(i, :) = filtfilt(b, a, data(i, :)); 
end

%% 3. Rappresentazione Grafica (Tutti i canali in una figura)
figure('Name', 'Visualizzazione 6 Canali filtrati EMG', 'Color', 'w');

for i = 1:numChannels
    subplot(numChannels, 1, i); % Crea un sotto-grafico per ogni canale
    plot(t, filteredData(i, :), 'LineWidth', 0.8);
    
    % Estetica del grafico
    grid on;
    ylabel(['Ch ' num2str(i)]);
    xlim([t(1) t(end)]); % Imposta i limiti dell'asse X sul tempo totale
    ylim([-2 2]);
    
    % Rimuove le etichette dell'asse X tranne che per l'ultimo canale
    if i < numChannels
        set(gca, 'XTickLabel', []);
    else
        xlabel('Tempo [s]');
    end
end

% Titolo generale
sgtitle(['Dati Filtrati MotemaSens']);