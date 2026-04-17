clear
close all
clc

%% ---------- Data Loading --------------
% The EMG data were acquired using the MomtaSens device with 6 channels
% of surface EMG (sEMG). The dataset is stored in a .mat file where:
%   - n represents the number of channels
%   - m represents the number of samples per channel
%
% The sampling frequency of the acquisition system is 2000 Hz.

load("Acquisizione_2.mat")

fs = 2000; %sampling frequencey
[numChannels, numSamples] = size(data);
t = (0:numSamples-1) / fs; 

% Data plotting ----------
figure('Name', 'Visualization of 6 RAW CHANNELS EMG', 'Color', 'w');

for i = 1:numChannels
    subplot(numChannels, 1, i); 
    plot(t, data(i, :), 'LineWidth', 0.8);
    
    grid on;
    ylabel(['Ch ' num2str(i)]);
    xlim([t(1) t(end)]); 
    ylim([min(data(i,:)) max(data(i,:))])
    
    if i < numChannels
        set(gca, 'XTickLabel', []);
    else
        xlabel('Tempo [s]');
    end
end

sgtitle('Raw Data MotemaSens');

%% ---------- Data Filtering --------------
% EMG signals are characterized by most of their spectral energy
% in the range 20–450 Hz. Frequencies below 20 Hz are typically
% associated with motion artifacts, while frequencies above 450 Hz
% are dominated by measurement noise.

% A 5th-order Butterworth filter is used due to its flat passband
% response, ensuring minimal distortion of the EMG amplitude envelope.

f_nyq = fs / 2; %Nyquist frequency

low_cut = 20;%low cut frequency
high_cut = 450; %high cut frequency

Wp = [low_cut high_cut] / f_nyq; %passband
Ws = [10 500] / f_nyq; %stopband

[b, a] = butter(5, Wp, 'bandpass'); 
filteredData = zeros(size(data)); 

for i = 1:6
    filteredData(i, :) = filtfilt(b, a, data(i, :)); 
end

% Data plotting ----------
figure('Name', 'Visualization of 6 FILTERED CHANNELS EMG', 'Color', 'w');

for i = 1:numChannels
    subplot(numChannels, 1, i); 
    plot(t, filteredData(i, :), 'LineWidth', 0.8);
    
    grid on;
    ylabel(['Ch ' num2str(i)]);
    xlim([t(1) t(end)]); 
    ylim([min(filteredData(i,:)) max(filteredData(i,:))])
    
    if i < numChannels
        set(gca, 'XTickLabel', []);
    else
        xlabel('Tempo [s]');
    end
end

sgtitle('Filtered Data MotemaSens');


%% ---------- Envelope extraction --------------

% Machine learning techniques are applied to the EMG signal to classify
% hand opening and closing movements.
%
% The analysis focuses on the amplitude envelope of the signal, which
% contains the most relevant information for distinguishing different
% muscle activation patterns.
%
% The envelope is computed by full-wave rectification followed by a
% low-pass filter at 10 Hz, providing a smooth estimate of the
% underlying muscle activation dynamics.

cutoff_env = 20;                   
Wp_env = cutoff_env / f_nyq;         

[b_env, a_env] = butter(5, Wp_env, 'low');


for i = 1:numChannels
    rectifiedData = abs(filteredData); % rectification
    envelopeData(i, :) = filtfilt(b_env, a_env, rectifiedData(i, :)); % apply filter to get envelope
end

% Data plotting ----------
figure('Name', 'Visualization of 6 ENVELOPE CHANNELS EMG', 'Color', 'w');


for i = 1:numChannels
    subplot(numChannels, 1, i); 
    plot(t, envelopeData(i, :), 'LineWidth', 0.8);
    
    grid on;
    ylabel(['Ch ' num2str(i)]);
    xlim([t(1) t(end)]);
    ylim([min(envelopeData(i,:)) max(envelopeData(i,:))])
    
    if i < numChannels
        set(gca, 'XTickLabel', []);
    else
        xlabel('Tempo [s]');
    end
end

sgtitle('Envelope Data MomtaSens');



%% ---------- Identification of the activations --------------
% To identify the activation instants corresponding to hand opening and 
% closing movements, the findpeaks function is applied to the most 
% informative EMG channel (channel 4 in this case). Peak detection is 
% performed by setting appropriate values for MinPeakHeight and 
% MinPeakDistance to avoid detecting noise or multiple peaks within the 
% same contraction.
%
% Once the peaks are identified, fixed-length windows of 3 seconds are 
% extracted around each detected peak. Each window starts 0.6 seconds 
% before the peak and ends 2.4 seconds after the peak, ensuring that the 
% full contraction dynamics are captured.

refCh = 4;
signal   = filteredData(refCh, :);
envelope = envelopeData(refCh, :);

[pks, pks_times] = findpeaks(envelope, fs, MinPeakDistance=1.8, MinPeakHeight=0.1);

% Converti in indici campione
starts = round(pks_times * fs);

preSamp  = round(0.6 * fs);           
postSamp = round(2.4 * fs);           
winSamp  = preSamp + postSamp; 

% Plot di verifica
figure('Name', 'Verifica Finestre 3s (Linear Envelope)');
plot(t, signal, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5); hold on;
plot(t, envelope, 'r', 'LineWidth', 1.2);

for k = 1:length(pks_times)
    tStart_detect = pks_times(k);          % già in secondi
    winStart = tStart_detect - (preSamp/fs);
    winEnd   = tStart_detect + (postSamp/fs);
    patch([winStart winEnd winEnd winStart], [-2 -2 2 2], ...
          'yellow', 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    text(tStart_detect, 1.8, num2str(k), 'FontSize', 7, 'Color', 'k');
end
xlabel('Tempo [s]'); ylabel('mV');
title(['Picchi rilevati: ' num2str(length(pks_times)) ' - Inviluppo Low-pass 10Hz']);
legend('Segnale','Inviluppo'); hold off;

% Scarta C1 e aggiorna conteggio
starts(1) = [];
numContractions = length(starts);

idxAperture = [1, 3, 5:11];    % 9 aperture
idxChiusure = [2, 4, 12:18];   % 9 chiusure

nA = length(idxAperture);
nC = length(idxChiusure);
segA = zeros(winSamp, 6, nA);
segC = zeros(winSamp, 6, nC);

% Estrazione con rispetto del pre-trigger (s_start)
for k = 1:nA
    s_detect = starts(idxAperture(k));
    s_start  = s_detect - preSamp; 
    if s_start < 1, s_start = 1; end
    segA(:,:,k) = filteredData(:, s_start : s_start + winSamp - 1).';
end

for k = 1:nC
    s_detect = starts(idxChiusure(k));
    s_start  = s_detect - preSamp; 
    if s_start < 1, s_start = 1; end
    segC(:,:,k) = filteredData(:, s_start : s_start + winSamp - 1).';
end

% Concatenazione finale
tutteAperture = reshape(permute(segA, [1,3,2]), [], 6);
tutteChiusure = reshape(permute(segC, [1,3,2]), [], 6);
MatriceFinale = [tutteAperture; tutteChiusure];

fprintf('MatriceFinale completata: %d x %d\n', size(MatriceFinale,1), size(MatriceFinale,2));

%% Rappresentazione Finale: 6 Canali Filtrati e Riordinati (m x n)
[m_new, n_new] = size(MatriceFinale);
% Creiamo un nuovo asse del tempo basato sulla lunghezza della MatriceFinale
t_final = (0:m_new-1) / fs; 

figure('Name', 'Visualizzazione 6 Canali EMG Riordinati', 'Color', 'w');

for i = 1:n_new
    subplot(n_new, 1, i);
    
    % Poiché i canali sono nelle COLONNE, accediamo con MatriceFinale(:, i)
    plot(t_final, MatriceFinale(:, i), 'LineWidth', 0.8, 'Color', [0 0.4470 0.7410]);
    
    grid on;
    ylabel(['Ch ' num2str(i) ' [mV]']);
    xlim([t_final(1) t_final(end)]);
    ylim([-2 2]); % Manteniamo lo scale che hai impostato
    
    % Aggiungiamo una linea verticale rossa per separare Aperture da Chiusure
    % La posizione è (numero campioni Aperture) / frequenza di campionamento
    fine_aperture_sec = size(tutteAperture, 1) / fs;
    xline(fine_aperture_sec, 'r', 'LineWidth', 1.5, 'Alpha', 0.7);
    
    % Estetica asse X
    if i < n_new
        set(gca, 'XTickLabel', []);
    else
        xlabel('Tempo virtuale (Aperture poi Chiusure) [s]');
    end
end

% Titolo generale
sgtitle('Dati Filtrati MotemaSens: 9 Aperture seguite da 9 Chiusure');

% Aggiunta di una legenda solo sul primo subplot per chiarezza
subplot(n_new, 1, 1);
legend('Segnale EMG', 'Separazione A/C', 'Location', 'northeast');



%% ---------- Envelope extraction --------------
% parametri dell'inviluppo definiti in precedenza

% 2. Rettificazione e Filtraggio
% Poiché MatriceFinale è campioni x canali, lavoriamo sulle colonne
rectifiedFinal = abs(MatriceFinale); 
envelopeFinal = zeros(size(rectifiedFinal));

for i = 1:size(MatriceFinale, 2) % Ciclo sui canali (colonne)
    % Applichiamo il filtro passa-basso a ogni colonna
    envelopeFinal(:, i) = filtfilt(b_env, a_env, rectifiedFinal(:, i)); 
end

% 3. Creazione asse del tempo per la Matrice Finale
t_final = (0:size(envelopeFinal, 1)-1) / fs;

% 4. Plotting degli Inviluppi Riordinati
figure('Name', 'Visualization of 6 ENVELOPE CHANNELS (Reorganized)', 'Color', 'w');

for i = 1:size(envelopeFinal, 2)
    subplot(size(envelopeFinal, 2), 1, i); 
    plot(t_final, envelopeFinal(:, i), 'LineWidth', 1, 'Color', [0.8500 0.3250 0.0980]);
    
    grid on;
    ylabel(['Ch ' num2str(i) ' [mV]']);
    xlim([t_final(1) t_final(end)]); 
    ylim([-0.1 0.7]); 
    
    % Linea rossa di separazione tra Aperture e Chiusure
    fine_aperture_sec = size(tutteAperture, 1) / fs;
    xline(fine_aperture_sec, 'r', 'LineWidth', 1.5, 'Label', 'A | C');
    
    if i < size(envelopeFinal, 2)
        set(gca, 'XTickLabel', []);
    else
        xlabel('Tempo virtuale (Aperture + Chiusure) [s]');
    end
end

sgtitle('Envelope Data MotemaSens - Reorganized (Apertures then Closures)');