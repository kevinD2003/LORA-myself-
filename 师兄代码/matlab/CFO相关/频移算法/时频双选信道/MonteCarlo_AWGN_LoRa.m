%% LoRa AWGN
SF = 10;
M = 2^SF;
SNR = -25 : -10;
BER = zeros(1,length(SNR));
loop = 10000;
tic;
for i = 1 : length(SNR)
    error = 0;
    for ii = 1 : loop
       error = error + DNC(M,SNR(i)); 
    end
    BER(i) = error / loop / 2;
end
%% 
figure;
semilogy(SNR,BER,'b-^');
xlabel('SNR (dB)');ylabel('BER');
%% 
function error = DNC(M,SNR)
error = 0;
a = randi([0 M - 1]);
k = 0 : M-1;
xk = exp(1j*2*pi*k.*(a/M - 1/2 + k/M/2));
xk0 = exp(-1j*2*pi*k.*(- 1/2 + k/M/2));
rk = awgn(xk,SNR,'measured');
Yq = abs(fft(rk.*xk0))/M;
[~,d] = max(Yq);
if d - 1 ~= a
    error = 1;
end
end