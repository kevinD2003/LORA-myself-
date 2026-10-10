%% 卫星多普勒信道，LoRa BER性能 。
%% 天启28星
% SF=7,B=125k;preamble:8,payload:22;883s,每秒钟33帧。
% SF=12,B=125k;preamble:8,payload:22;883s,每秒钟1帧。
%% Monte Carlo实验 CFO。
load('TQ28_CFO.mat');
B = 125e3;
SF=7;
M = 2^SF;
N_frame=33;
if SF==12
    N_frame=1;
end
N_upchirp=8;
N_payload=22+(8-N_upchirp);%数据块的装载
SNR=-12:1:0;
BER_LoRa=zeros(1,length(SNR));
times=883;
tic;
h=waitbar(0,['SF=' num2str(SF) ',TQ28']);

%% LoRa
for j=1:length(SNR)
    error_lora=0;
    for jj=1:times
        lambda = F_cfo(jj) * M / B;
        % lambda = 0;
        for jjj=1:N_frame
           [error2]=LoRa(SF,lambda,SNR(j),N_payload,N_upchirp);
           error_lora=error_lora+error2;
        end
    end
    BER_LoRa(j)=error_lora/(times*N_payload*N_frame)/2;
    if(BER_LoRa(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['LoRa,SNR=' num2str(SNR(j))]);
end
%% 
toc;
close(h);
figure;
semilogy(SNR,BER_LoRa,'b-+');
grid on;
legend('LoRa');


%% LoRa
function [error]=LoRa(SF,lambda,SNR,N_payload,N_upchirp)
error=0;
M=2^SF;
k=0:M-1;
n=0:N_upchirp*M-1;
a=randi([0 M-1],1,N_payload);
%% 调制
xk_payload=zeros(1,M*N_payload);
for i=1:N_payload
    xk_payload((i-1)*M+1:i*M)=exp(1j*2*pi*k.*(a(i)/M-1/2+k/2/M+lambda/M));
end
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+lambda/M));
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
%% 组帧
xk_frame=[xk_preamble xk_payload];%因为LoRa用不到前导码的upchirp，其实只传数据部分即可。
%% 加噪
rk1=awgn(xk_frame,SNR,'measured');
% %% 手动添加高斯噪声
% sigPower=sum(abs(S.*S))/length(S);
% reqSNR=10^(SNR/10);
% noisePower=sigPower/reqSNR;
% noise=sqrt(noisePower/2)*(randn(1,length(S))+1j*randn(1,length(S)));
% %% 瑞利信道
% omega = 1;
% h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
% rk=h_rayleigh*S+noise;
%% 解帧
rk_preamble=rk1(1:N_upchirp*M);
rk_payload=rk1(N_upchirp*M+1:end);


%% 未补偿DNC
for j=1:N_payload
    Y_payload_DNC=fft(xk0.*rk_payload((j-1)*M+1:j*M));
    [~,dnc]=max(abs(Y_payload_DNC/M));
    if dnc-1~=a(j)
        error=error+1;
    end
end

end