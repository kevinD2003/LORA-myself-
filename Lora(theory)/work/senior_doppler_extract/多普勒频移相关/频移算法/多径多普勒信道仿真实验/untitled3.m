%% 帧结构LoRa
SF=6;
M=2^SF;
Np=20;%装载的数量（传输的符号个数）
a=randi([0 M-1],1,Np);
k=0:1:M-1;  
% rk1=awgn(Sd,SNR,'measured');
%% 调制
% 前导部分
xk_p=exp(1j*2*pi*k.*(-1/2+k/2/M));
xk_preamble=[xk_p xk_p xk_p xk_p xk_p xk_p xk_p xk_p];
%数据部分
xk_payload=zeros(1,Np*M);
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);%基信号的共轭
for i=1:Np
    xk=exp(1j*2*pi*k.*(a(i)/M-1/2+k/2/M));
    xk_payload(M*(i-1)+1:M*i)=xk;
end
%% 组帧
xk_frame=[xk_preamble xk_payload];
%% 信道

% %CFO
% h_CFO=[];
% xk_CFO=exp(1j*2*pi*k*epsilon/M);
% for i=1:Np+8
%     h_CFO=[h_CFO xk_CFO];
% end
% rk=h_CFO.*xk_frame;%CFO

% %加噪
% sigPower=sum(abs(xk_frame.*xk_frame))/length(xk_frame);
% reqSNR=10^(SNR/10);
% noisePower=sigPower/reqSNR;
% noise=sqrt(noisePower/2)*(randn(1,length(xk_frame))+1j*randn(1,length(xk_frame)));

% %瑞利衰落
% omega = 1;
% h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
% rk=h_rayleigh*xk_frame+noise;

rk=xk_frame;
%% 解帧
rk_preamble=rk(1:M*8);%前导
rk_payload=rk(M*8+1:end);%数据块
%% 解调
%数据块处理
error=0;
for i=1:Np
    data_payload=rk_payload(M*(i-1)+1:M*i);
    Yq=fft(data_payload.*xk0);
    Yq=abs(Yq/M);
    [~,d]=max(Yq);
    if(d-1~=a(i))
        error=error+1;
    end
end
%% 计算BER
BER=error/Np/2;