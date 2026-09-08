%% MF STO_CFO_Multipath；
%% LoRa通信参数
B=250e3;
SF=10;
M=2^SF;
%% 信道参数
load('6path.mat');
%% 两径信道
num = 6;
hi = g(1:num) / g(1);
epsilon = fd(1:num) * M / B;
ui=ceil(tau(1:num) * B);
%% 假设收发双方相距5km(考虑仅由传播时延引起的STO)
distance = 5e3;
t_sto = distance / (3e8);
N_t_sto = B * t_sto;%归一化
In_sto = floor(N_t_sto);%整数STO
Fr_sto = mod(N_t_sto,1);%小数STO
% In_sto = 0;%无整数STO
% Fr_sto = 0;%无小数STO
%% 
SNR=-25:1:15;
% SNR=-20;
N_error_max=200;
N_upchirp=2;
loop=1000;
BER_MF=zeros(1,length(SNR));
tic;

%% MF 匹配滤波法
h2=waitbar(0,['MF,SF=' num2str(SF)  ',SNR=' num2str(SNR(1))]);
for i=1:1:length(SNR)
    error_mf=0;
   for j=1:1:loop
       [errormf]=MF(M,epsilon,SNR(i),N_upchirp,hi,ui,In_sto,Fr_sto);
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
legend('MF');

%% MF算法
function [error1]=MF(M,epsilon,SNR,N_upchirp,hi,ui,In_sto,Fr_sto)
aa=randi([0 M-1]);
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(1)/M));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(1)/M));%前导符号
%% 加STO
STO_in = exp(1j*2*pi*In_sto*k/M);
STO_fr = exp(1j*2*pi*Fr_sto*k/M);
STO_fr = circshift(STO_fr, M-In_sto);
xk_sto = xk .* STO_in .* STO_fr;
xk_preamble_sto = xk_preamble .* STO_in .* STO_fr;
%% 
xk_preamble=zeros(1,N_upchirp*M);
for i=1:N_upchirp
    xk_preamble((i-1)*M+1:i*M)=xk_preamble_sto;
end
xk_frame=[xk_preamble xk_sto];
xk_dp = hi(1) * xk_frame;
%% 手动添加高斯噪声
sigPower=sum(abs(xk_dp.*xk_dp))/length(xk_dp);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(xk_frame))+1j*randn(1,length(xk_frame)));

%% 多径
rk_mpc = zeros(1,length(xk_frame));
for i = 2 : length(ui)
%     xk_tmp=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(i)/M)) .* STO_in .* STO_fr;
%     xk_preamble_tmp=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(i)/M)) .* STO_in .* STO_fr;%前导符号
    xk_tmp=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));
    xk_preamble_tmp=exp(1j*2*pi*k.*(-1/2+k/2/M));%前导符号
    xk_preamble_frame=zeros(1,N_upchirp*M);
    for ii=1:N_upchirp
        xk_preamble_frame((ii-1)*M+1:ii*M)=xk_preamble_tmp;
    end
    xk_frame_tmp=[xk_preamble_frame xk_tmp];
    rk_mpc_tmp = [zeros(1, ui(i)) xk_frame_tmp(1 : end - ui(i))];
    for ii = 1 : N_upchirp+1
        rk_mpc_tmp((ii-1)*M+1 : ii*M) = rk_mpc_tmp((ii-1)*M+1 : ii*M) .* exp(1j*2*pi*k.*(epsilon(i)/M)) .* STO_in .* STO_fr;
    end
    
    rk_mpc = rk_mpc + hi(i)*rk_mpc_tmp;
end
%% 
rk1 = xk_dp + noise + rk_mpc;

xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:N_upchirp
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=y_preamble/N_upchirp;%取平均
y_payload=abs(fft(rk1(N_upchirp*M+1:end).*xk0))/M;

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
