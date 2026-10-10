%带频偏的LoRa计算误码率；
B=500e3;
SF=7;
M=2^SF;
SNR=-15:1:10;
% SNR=-20;
N_error_max=2000;
times=1000;
ui=[0 10];
hi=[sqrt(0.8) sqrt(0.2)];
% hi=[1 1];
epsilon=0.3;
fd=epsilon*B/M;%多普勒频偏Hz
BER_MF=zeros(1,length(SNR));
tic;

%% MF 匹配滤波法
h2=waitbar(0,['MF,SF=' num2str(SF) ',fd=' num2str(epsilon) ',SNR=' num2str(SNR(1))]);
for i=1:1:length(SNR)
    error_mf=0;
    error_ibd=0;
   for j=1:1:times
       [errormf]=MF(M,B,fd,SNR(i),ui,hi);
       error_mf=error_mf+errormf;
   end
   BER_MF(i)=error_mf/times/2;
   if BER_MF(i)<1E-6
       break;
   end
   waitbar(i/length(SNR),h2,['SF=' num2str(SF) ',SNR=' num2str(SNR(i))]);
end
toc;
close(h2);


%%
figure;
semilogy(SNR,BER_MF,'m-s');hold on;
xlabel('SNR(dB)');ylabel('BER');
grid on;
legend(['MF,ui=' num2str(ui(2)) ',ε=' num2str(epsilon)]);

%% MF算法
function [error1]=MF(M,B,fd,SNR,ui,hi)
aa=randi([0 M-1]);
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];

% 多径
S_matipath=zeros(1,length(Sd));
for i=2:length(ui)
    S_temp=[zeros(1,ui(i)) Sd(1:end-ui(i))];
    S_matipath=S_matipath+hi(i)*S_temp;
end
Sd=hi(1)*Sd;
rk1=awgn(Sd,SNR,'measured');
rk1=rk1+S_matipath;
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
