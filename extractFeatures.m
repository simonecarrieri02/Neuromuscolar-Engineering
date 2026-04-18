%--------------------------------------------------------------------------
% extractFeatures  –  Time-domain feature extraction from a multi-channel
%                     EMG signal window.
%
% Feature selection based on: Toledo-Pérez et al., "Support Vector
% Machine-Based EMG Signal Classification Techniques: A Review", which
% identifies the MAV · WL · ZC · SSC core as the most recurrent
% combination across high-accuracy studies in the literature.
%
% INPUT
%   win  : [samples × channels] matrix containing the signal window
%
% OUTPUT
%   feat : [1 × (6 · channels)] row vector of features concatenated
%          per channel in the order: MAV, RMS, VAR, WL, ZC, SSC
%--------------------------------------------------------------------------
function feat = extractFeatures(win)

    MAV = mean(abs(win));                       % Mean Absolute Value
    RMS = sqrt(mean(win.^2));                   % Root Mean Square
    VAR = var(win);                             % Variance
    WL  = sum(abs(diff(win)));                  % Waveform Length
    ZC  = sum(abs(diff(sign(win))))  / 2;       % Zero Crossings
    SSC = sum(abs(diff(sign(diff(win))))) / 2;  % Slope Sign Changes

    feat = [MAV, RMS, VAR, WL, ZC, SSC];       % [1 × 6·channels]

end