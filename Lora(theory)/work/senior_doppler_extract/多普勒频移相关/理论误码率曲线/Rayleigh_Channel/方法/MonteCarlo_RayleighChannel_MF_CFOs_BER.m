%带频偏的LoRa计算误码率；
B=500e3;
SF=10;
M=2^SF;
SNR=-25:1:25;
N_error_max=2000;
times=1000;
epsilon=0.5;
fd=epsilon*B/M;%多普勒频偏Hz
BER_MF=zeros(1,length(SNR));

tic;

%% MF 匹配滤波法
h2=waitbar(0,['MF,SF=' num2str(SF) ',\epsilon=' num2str(epsilon)]);
for i=1:1:length(SNR)
    error_mf=0;
    
   for j=1:1:times
%        if error_mf<N_error_max||error_ibd<N_error_max
           %        error_mf=error_mf+MF(M,B,fd,SNR(i));
           [errormf]=MF(M,B,fd,SNR(i));
           error_mf=error_mf+errormf;
           
           N=j;
%            waitbar(i/times);
%        else
%            break;
%        end
   end
   BER_MF(i)=error_mf/N/2;
   if BER_MF(i)<1E-6
       break;
   end
   waitbar(i/length(SNR),h2,['SF=12,SNR=' num2str(SNR(i))]);
end
toc;
close(h2);


%%
figure;
semilogy(SNR,BER_MF,'m-s');hold on;
xlabel('SNR(dB)');ylabel('BER');
grid on;
legend(['SF=' num2str(SF) ',\epsilon=' num2str(epsilon) ',RayleighChannel']);
%xlim([-20 -4])
% title('B=125KHz,SF=7,\Deltaf=B/M=976.5625Hz');
%% MF算法
function [error1]=MF(M,B,fd,SNR)
aa=randi([0 M-1]);
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
%% 手动添加高斯噪声
sigPower=sum(abs(Sd.*Sd))/length(Sd);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(Sd))+1j*randn(1,length(Sd)));
%% 瑞利信道
omega = 1;
h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
rk1=h_rayleigh*Sd+noise;
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:8
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=y_preamble/8;%取平均
y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;


%圆周相关运算
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble.*y_tem);
end
%解调,传统
[~,decision]=max(R);
if ((decision-1) ~= aa)
    error1 = 1;
else
    error1 = 0;
end

end


