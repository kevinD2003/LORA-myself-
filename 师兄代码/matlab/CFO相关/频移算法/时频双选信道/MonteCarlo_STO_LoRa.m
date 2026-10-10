%% STO采样时间偏移
SF=10;
M=2^SF;
SNR = -25:0;
BER = zeros(1,length(SNR));
times = 10000;
for i = 1 : length(SNR)
    error_lora = 0;
    for ii = 1 : times
        aa=randi([0 M-1]);
        k=0:1:M-1;
        xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));
        xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
        %% STO
        L_sto = 0;lamda_sto = 0.42;
        STO_fr = exp(1j*2*pi*lamda_sto*k/M);
        STO_fr = circshift(STO_fr, M-L_sto+1);
        xk_sto = xk .* exp(1j*2*pi*L_sto*k/M) .* STO_fr;
        rk1 = awgn(xk_sto,SNR(i),'measured');
        %% 解调
        payload_dechirp=rk1.*xk0;
        Yq_sto=abs(fft(payload_dechirp))/M;
        [~,d_lora]=max(abs(Yq_sto));
        if d_lora - 1 ~= aa
            error_lora = error_lora + 1;
        end
    end
    BER(i) = error_lora / times / 2;
    if BER(i) < 1e-6
        break;
    end
end
figure;semilogy(SNR,BER,'r-o')
% figure;stem(0:M-1,Yq_sto,"Marker","none","LineWidth",1);
% xlabel('Frequency bin, q');ylabel('|Yq/M|')