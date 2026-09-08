%% 多普勒频偏+多径，采用差分编码
%% 天启28星
% SF=7,B=125k;preamble:8,payload:22;883s,每秒钟33帧。
% SF=12,B=125k;preamble:8,payload:22;883s,每秒钟1帧。
load('TQ28_CFO.mat');
B = 125e3;
SF=12;
M = 2^SF;
N_frame=33;
if SF==12
    N_frame=1;
end
N_upchirp=8;
N_payload=22+(8-N_upchirp);%数据块的装载
SNR=-25:0;
BER_DCSS=zeros(1,length(SNR));
times=883;
tic;
h=waitbar(0,'差分编码');
% jjj=1;
for j=1:length(SNR)
    error_dcss=0;
    for jj=1:times
        epsilon = F_cfo(jj) * M / B;
        for jjj=1:N_frame
            error=DCSS(SF,epsilon,SNR(j),N_payload,N_upchirp);
            error_dcss=error_dcss+error;
        end
        
    end
    BER_DCSS(j)=error_dcss/(times*(N_payload-1)*N_frame)/2;
    if(BER_DCSS(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['SNR=' num2str(SNR(j))]);
end
toc;
close(h);
%%
c=['k';'m';'c';'b';'g';'r';'y'];
m=['x';'d';'s';'*';'+';'o';'v'];
figure;
semilogy(SNR,BER_DCSS,'LineStyle','-','Color','g','Marker','*');hold on;
title('DCSS');
legend(['DCSS,SF=' num2str(SF) ',TQ28'])
grid on;



function error_dcss=DCSS(SF,epsilon,SNR,N_payload,N_upchirp)
error_dcss=0;
M=2^SF;
Sp=randi([1 M-1],1,N_payload);
Dp=zeros(1,length(Sp));
Dp(1)=Sp(1);
for i=2:N_payload
    Dp(i)=mod((Sp(i)+Dp(i-1)),M);
end
k=0:1:M-1;
xk_payload=zeros(1,N_payload*M);
for ii=1:N_payload
    xk_payload((ii-1)*M+1:ii*M)=exp(1j*2*pi*k.*(Dp(ii)/M-1/2+k/2/M+epsilon/M));%调制
end
xk_pre=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导码
xk_preamble=[xk_pre xk_pre xk_pre xk_pre xk_pre xk_pre xk_pre xk_pre];
xk_frame=[xk_preamble xk_payload];%组帧
rk1=awgn(xk_frame,SNR,'measured');
% %% 手动添加高斯噪声
% sigPower=sum(abs(Sk_frame.*Sk_frame))/length(Sk_frame);
% reqSNR=10^(SNR(j)/10);
% noisePower=sigPower/reqSNR;
% noise=sqrt(noisePower/2)*(randn(1,length(Sk_frame))+1j*randn(1,length(Sk_frame)));
% %% 瑞利信道
% omega = 1;
% h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
% Rk_frame=h_rayleigh*Sk_frame+noise;

%% 解帧
rk_preamble=rk1(1:N_upchirp*M);
rk_payload=rk1(N_upchirp*M+1:end);
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
Dp_ncoh=zeros(1,N_payload);
for o=1:N_payload
    Yq=abs(fft(rk_payload((o-1)*M+1:o*M).*xk0)/M);
    %     figure;plot(0:M-1,Yq);
    [~,decision]=max(Yq);
    Dp_ncoh(o)=decision-1;
end
Sp_ncoh=zeros(1,N_payload);

for iii=2:N_payload
    Sp_ncoh(iii)=mod(Dp_ncoh(iii)-Dp_ncoh(iii-1),M);
    if Sp_ncoh(iii)~=Sp(iii)
        error_dcss=error_dcss+1;
    end
end
end