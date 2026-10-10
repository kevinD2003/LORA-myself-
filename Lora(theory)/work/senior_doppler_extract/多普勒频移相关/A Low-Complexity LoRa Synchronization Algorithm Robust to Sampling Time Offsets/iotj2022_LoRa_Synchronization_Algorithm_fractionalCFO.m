%% A Low-Complexity LoRa Synchronization Algorithm Robust to Sampling Time Offsets
%% 小数部分CFO的估计与补偿。
B=500e3;
SF=7;
M=2^SF;
k=0:M-1;
n=0:8*M-1;
% a=randi([0 M-1]);
a=M/2;
lambda=0.5;
Nc=7;
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+lambda/M));
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+lambda/M));
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
S=[xk_preamble xk];
SNR=-7;
rk=awgn(S,SNR,'measured');
% rk=S;
%% 小数部分的估计
lambda_CFO=0;
for l=2:Nc
    y_l_1=rk((l-2)*M+1:(l-1)*M);
    y_l=rk((l-1)*M+1:l*M);
    Y_l=fft(y_l.*xk0_preamble((l-1)*M+1:l*M));
    Y_l_1=fft(y_l_1.*xk0_preamble((l-2)*M+1:(l-1)*M));
    [~,i]=max(abs(Y_l));
    lambda_cfo=0;
    for p=-2:2
        n=mod(i+p,M);
        if n==0
            n=M;
        end
        lambda_cfo=lambda_cfo+Y_l(n)*conj(Y_l_1(n));
    end
    lambda_CFO=lambda_CFO+lambda_cfo;
end
lambda_CFO=angle(lambda_CFO)/pi/2;

%% 整数部分 循环移位
r_preamble_integer=zeros(1,M);
 for o=1:8
%      r_preamble_integer=r_preamble_integer+rk((o-1)*M+1:o*M).*exp(-1j*2*pi*lambda_CFO*((o-1)*M+1:o*M)/M);
     r_preamble_integer=r_preamble_integer+fft(rk((o-1)*M+1:o*M).*xk0_preamble((o-1)*M+1:o*M).*exp(-1j*2*pi*lambda_CFO*((o-1)*M+1:o*M)/M));
 end
 r_preamble_integer= r_preamble_integer/8;
%  Yq_preamble_integer=fft(r_preamble_integer.*xk0);
Yq_preamble_integer=r_preamble_integer;
[~,a_preamble]=max(Yq_preamble_integer);
%% 对payload的处理
r_payload=rk(8*M+1:end);
Y_payload=fft(xk0.*r_payload.*exp(-1j*2*pi*lambda_CFO*k/M));%% dechrip+小数部分补偿+DFT；
Y_payload=[Y_payload(a_preamble:end) Y_payload(1:a_preamble-1)];%% 整数部分循环移位；也可以在dechirp后面做循环移位，再进行DFT。
figure;
subplot(2,1,2)
stem(0:M-1,abs(Y_payload/M),'Marker','none');xlabel('q');ylabel('Y_q');xlim([0 M-1]);
title('2022IOTJ');
%% 未补偿DNC
Y_payload_DNC=fft(xk0.*r_payload);
subplot(2,1,1)
stem(0:M-1,abs(Y_payload_DNC/M),'Marker','none');xlabel('q');ylabel('Y_q');xlim([0 M-1]);ylim([0 1])
title('DNC')




