%带频偏的LoRa计算误码率；
SF=12;
M=2^SF;
SNR=-25:1:-15;
% SNR=-20;
N_error_max=200;
N_upchirps=1;
times=1000000;
epsilon=0.8;
BER_MF=zeros(1,length(SNR));
tic;

%% MF 匹配滤波法
h2=waitbar(0,['MF,SF=' num2str(SF) ',fd=' num2str(epsilon) ',SNR=' num2str(SNR(1))]);
for i=1:1:length(SNR)
    error_mf=0;
    error_ibd=0;
   for j=1:1:times
       [errormf]=MF(M,epsilon,SNR(i),N_upchirps);
       error_mf=error_mf+errormf;
       N=j;
       if error_mf > N_error_max
           break;
       end
   end
   BER_MF(i)=error_mf/N/2;
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
function [error1]=MF(M,epsilon,SNR,N_upchirps)
aa=randi([0 M-1]);
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon/M));
xk_preamble_tmp=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
xk_preamble=zeros(1,N_upchirps*M);
for i=1:N_upchirps
    xk_preamble((i-1)*M+1:i*M)=xk_preamble_tmp;
end
Sd=[xk_preamble xk];

rk1=awgn(Sd,SNR,'measured');

xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:N_upchirps
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=y_preamble/N_upchirps;%取平均
y_payload=abs(fft(rk1(N_upchirps*M+1:end).*xk0))/M;

%圆周相关运算
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble.*y_tem);
end
 
[~,decision]=max(R);
if ((decision-1) ~= aa)
    error1 = 1;
else
    error1 = 0;
end

end
