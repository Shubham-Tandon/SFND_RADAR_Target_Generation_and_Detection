close all
clear all
clc;

%% Radar Specifications 
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequency of operation = 77GHz
% Max Range = 200m
% Range Resolution = 1 m
% Max Velocity = 100 m/s
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%speed of light = 3e8

Rmax = 200;  % m
Rres = 1;    % m
Vres = 3;    % m/s
Vmax = 70;   % m/s
c    = 3e8;  % m/s

sweepFactor = 5.5;

%% User Defined Range and Velocity of target
% *%TODO* :
% define the target's initial position and velocity. Note : Velocity
% remains contant
Rtarget = 110;  % m
Vtarget = -20;   % m/s
 


%% FMCW Waveform Generation

% *%TODO* :
%Design the FMCW waveform by giving the specs of each of its parameters.
% Calculate the Bandwidth (B), Chirp Time (Tchirp) and Slope (slope) of the FMCW
% chirp using the requirements above.

B      = c/(2 * Rres); %Bandwidth(Bsweep)=speed_of_light/(2*rangeResolution)
Tchirp = sweepFactor * 2 * Rmax / c;
slope  = B / Tchirp;

%Operating carrier frequency of Radar 
fc= 77e9;             %carrier freq

                                                          
%The number of chirps in one sequence. Its ideal to have 2^ value for the ease of running the FFT
%for Doppler Estimation. 
Nd=128;                   % #of doppler cells OR #of sent periods % number of chirps

%The number of samples on each chirp. 
Nr=1024;                  %for length of time OR # of range cells

% Timestamp for running the displacement scenario for every sample on each
% chirp
t=linspace(0,Nd*Tchirp,Nr*Nd); %total time for samples


%Creating the vectors for Tx, Rx and Mix based on the total samples input.
Tx=zeros(1,length(t)); %transmitted signal
Rx=zeros(1,length(t)); %received signal
Mix = zeros(1,length(t)); %beat signal

%Similar vectors for range_covered and time delay.
r_t=zeros(1,length(t));
td=zeros(1,length(t));


%% Signal generation and Moving Target simulation
% Running the radar scenario over the time. 

% t(1:50)

for i=1:length(t)         
    
    
    % *%TODO* :
    %For each time stamp update the Range of the Target for constant velocity. 
    if (i > 1)
        Rtarget = Rtarget + Vtarget * (t(i) - t(i - 1));
    end
    
    tD = 2 * Rtarget / c ;
    
    % *%TODO* :
    %For each time sample we need update the transmitted and
    %received signal. 
    Tx(i) = cos( 2*pi * (fc * t(i) + slope * (t(i)^2) / 2));
    Rx(i) = cos( 2*pi * (fc * (t(i) - tD) + (slope * (t(i) - tD)^2 ) / 2));
    
    % *%TODO* :
    %Now by mixing the Transmit and Receive generate the beat signal
    %This is done by element wise matrix multiplication of Transmit and
    %Receiver Signal
    Mix(i) = Tx(i) * Rx(i);
    
end

%% RANGE MEASUREMENT


 % *%TODO* :
%reshape the vector into Nr*Nd array. Nr and Nd here would also define the size of
%Range and Doppler FFT respectively.
signal     = reshape(Mix, [Nr, Nd]);

 % *%TODO* :
%run the FFT on the beat signal along the range bins dimension (Nr) and
%normalize.
signal_fft = fft(signal, Nr, 1);

 % *%TODO* :
% Take the absolute value of FFT output
P2 = abs(signal_fft/Nr);

 % *%TODO* :
% Output of FFT is double sided signal, but we are interested in only one side of the spectrum.
% Hence we throw out half of the samples.
P1 = P2(1:Nr/2 + 1);


%plotting the range


 % *%TODO* :
 % plot FFT output 


figure ('Name','Range from First FFT')  %plotting the range
plot(P1);                               % plot FFT output 
axis ([0 200 0 0.5]);


%% RANGE DOPPLER RESPONSE
% The 2D FFT implementation is already provided here. This will run a 2DFFT
% on the mixed signal (beat signal) output and generate a range doppler
% map.You will implement CFAR on the generated RDM


% Range Doppler Map Generation.

% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.

Mix=reshape(Mix,[Nr,Nd]);

% 2D FFT using the FFT size for both dimensions.
sig_fft2 = fft2(Mix,Nr,Nd);

% Taking just one side of signal from Range dimension.
sig_fft2 = sig_fft2(1:Nr/2,1:Nd);
sig_fft2 = fftshift (sig_fft2);
RDM = abs(sig_fft2);
RDM = 10*log10(RDM) ;

%use the surf function to plot the output of 2DFFT and to show axis in both
%dimensions
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure,surf(doppler_axis,range_axis,RDM);

%% CFAR implementation

%Slide Window through the complete Range Doppler Map

% *%TODO* :
%Select the number of Training Cells in both the dimensions.
Tc = 8;
Tr = 10;

% *%TODO* :
%Select the number of Guard Cells in both dimensions around the Cell under 
%test (CUT) for accurate estimation
Gc = 2;
Gr = 4;

Cols = 2 * (Tc + Gc) + 1;
Rows = 2 * (Tr + Gr) + 1;

TrnCells = 2* Tc * (2* (Tr + Gr) + 1) + 2*Tr * (2 * Gc + 1);


% Create a sliding window of 1s of the following size
% 
%              T T T T T T T T T T T 
%              T T T T T T T T T T T 
%              T T T G G G G G T T T 
%              T T T G G C G G T T T 
%              T T T G G G G G T T T 
%              T T T T T T T T T T T 
%              T T T T T T T T T T T 
          
window   = ones(Rows, Cols);

% Mofidy the sliding window so that only trainig cells have 1s. Those are
% the cells for which nose needs to be added
% 
%              1 1 1 1 1 1 1 1 1 1 1
%              1 1 1 1 1 1 1 1 1 1 1
%              1 1 1 0 0 0 0 0 1 1 1 
%              1 1 1 0 0 0 0 0 1 1 1 
%              1 1 1 0 0 0 0 0 1 1 1  
%              1 1 1 1 1 1 1 1 1 1 1
%              1 1 1 1 1 1 1 1 1 1 1

for row = 1:Rows
    for col = 1:Cols
        
        if ((row > Tr) && (row <= (Tr + 2*Gr + 1)) && (col > Tc) ...
                && (col <= Tc + 2 * Gc + 1))
           window(row, col) = 0;            
        end        
    end
end

% *%TODO* :
% offset the threshold by SNR value 
offset = 4;

% *%TODO* :
%Create a vector to store noise_level for each iteration on training cells
noise_matrix = zeros(size(window));

% *%TODO* :
%design a loop such that it slides the CUT across range doppler map by
%giving margins at the edges for Training and Guard Cells.
%For every iteration sum the signal level within all the training
%cells. To sum convert the value from logarithmic to linear using db2pow
%function. Average the summed values for all of the training
%cells used. After averaging convert it back to logarithimic using pow2db.
%Further add the offset to it to determine the threshold. Next, compare the
%signal under CUT with this threshold. If the CUT level > threshold assign
%it a value of 1, else equate it to 0.


% Use RDM[x,y] as the matrix from the output of 2D FFT for implementing
% CFAR

winSize  = size(window);
RSMSize  = size(RDM);
RDM_CFAR = zeros(RSMSize);

for row = 1:(RSMSize(1) - 2*(Gr+Tr))  
    for col = 1:(RSMSize(2) - 2*(Gc+Tc))
        
        % Calculate the noise matrix by multiplying the sliding window with
        % the RDM matrix matching the sliding window size
        noise_matrix = window.*RDM(row:(winSize(1) + row - 1), col:(winSize(2) + col - 1));
        noise_matrix = db2pow(noise_matrix);                % Convert from decibal to linear scale
        noise       = sum(sum(noise_matrix, 'All'));        % Add all the noises from the noise_matrix
        threshold   = (noise / TrnCells) * offset;          % Average the Noise and multiplying the offset
        threshold   = pow2db(threshold);                    % Convert to decibal 
        signal      = RDM(row + Tr + Gr, col + Tc + Gc);    % Extract the signal from CUT cell
        
        if signal > threshold
            RDM_CFAR(row + Tr + Gr, col + Tc + Gc) = 1;
        end
        
        fprintf(' %i, %i Thresh: %0.3f, Signal: %0.3f \n', row, col, threshold, signal);
             
    end
    
end


% *%TODO* :
%display the CFAR output using the Surf function like we did for Range
%Doppler Response output.
figure('Name','CA-CFAR Filtered RDM'),surf(doppler_axis,range_axis,RDM_CFAR);
colorbar;
