%% 时频双选信道仿真实验
%% 小数部分CFO的估计与补偿。
%% Monte Carlo实验
%% LoRa通信参数
B=250e3;
SF=10;
M=2^SF;
N_upchirp = 8;
N_payload = 1;
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
SNR=-25:10;
BER_EC=zeros(1,length(SNR));
times=10000;
N_error_max = 2000;
tic;
h=waitbar(0,'SF=12,\lambda=0.8');
for j=1:length(SNR)
    error_ec=0;
    rmse=0;
    for jj=1:times
        if error_ec < N_error_max
            [error1]=EC(SF,epsilon,SNR(j),ui,hi,In_sto,Fr_sto, N_upchirp, N_payload);
            error_ec=error_ec+error1;
            N =jj;
        end
    end
    BER_EC(1,j)=error_ec/N/2;
    if(BER_EC(1,j) < 1e-6)
        break;
    end
    waitbar(j/length(SNR),h,['\lambda=0.8;SNR=' num2str(SNR(j))]);
end
toc;
close(h);
%%
figure;
semilogy(SNR,BER_EC);
grid on
%% 
function [error1]=EC(SF,epsilon,SNR,ui,hi,In_sto,Fr_sto, N_upchirp, N_payload)
% N_upchirp = 2;
M=2^SF;
k=0:M-1;
% n=0:N_upchirp*M-1;
a=randi([0 M-1]); 
% a=M/2;
Nc=5;%采用Nc对连续的upchirp
xk_preamble = zeros(1,M*(N_upchirp));
for i = 1 : N_upchirp
    xk_preamble((i-1)*M+1 : i*M) = exp(1j*2*pi*((i-1)*M+k).*(-1/2+((i-1)*M+k)/2/M+epsilon(1)/M));
end
xk_playload = exp(1j*2*pi*((N_upchirp+N_payload-1)*M+k).*(a/M-1/2+((N_upchirp+N_payload-1)*M+k)/2/M+epsilon(1)/M));
%% 组帧
xk_Frame = [xk_preamble xk_playload];
%% 加STO
s = 0 : (N_payload+N_upchirp)*M-1;
STO_in = exp(1j*2*pi*In_sto*s/M);
STO_fr = exp(1j*2*pi*Fr_sto*s/M);
STO_fr = circshift(STO_fr, M-In_sto);
%% 
xk_dp = hi(1) * xk_Frame .* STO_in .* STO_fr;%考虑STO
%% 手动添加高斯噪声
sigPower=sum(abs(xk_dp.*xk_dp))/length(xk_dp);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;

noise=sqrt(noisePower/2)*(randn(1,length(xk_Frame))+1j*randn(1,length(xk_Frame)));

%% 多径

rk_mpc = zeros(1,length(xk_Frame));
for i = 2 : length(ui)
    xk_preamble_tmp = zeros(1,M*(N_upchirp));
    for ii = 1 : N_upchirp
        xk_preamble((ii-1)*M+1 : ii*M) = exp(1j*2*pi*((ii-1)*M+k).*(-1/2+((ii-1)*M+k)/2/M+epsilon(i)/M));
    end
    xk_playload_tmp = exp(1j*2*pi*((N_upchirp+N_payload-1)*M+k).*(a/M-1/2+((N_upchirp+N_payload-1)*M+k)/2/M+epsilon(i)/M));
    xk_Frame_tmp = [xk_preamble_tmp xk_playload_tmp].* STO_in .* STO_fr;
    xk_Frame_tmp = [zeros(1, ui(i)) xk_Frame_tmp(1 : end - ui(i))];
    rk_mpc = rk_mpc + hi(i)*xk_Frame_tmp;

end
%% 
rk = xk_dp + noise + rk_mpc;
%% 
xk0 = zeros(1, (N_upchirp+N_payload)*M);
for i = 1 : N_upchirp+N_payload
    xk0((i-1)*M+1 : i*M) = exp(-1j*2*pi*((N_upchirp+N_payload-1)*M+k).*(-1/2+((N_upchirp+N_payload-1)*M+k)/2/M));
end
lambda_CFO=0;
for l=2:Nc
    y_l_1=rk((l-2)*M+1:(l-1)*M);
    y_l=rk((l-1)*M+1:l*M);
    Y_l=fft(y_l.*xk0((l-1)*M+1:l*M));
    Y_l_1=fft(y_l_1.*xk0((l-2)*M+1:(l-1)*M));
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
 for o=1:N_upchirp
      r_preamble_integer=r_preamble_integer+fft(rk((o-1)*M+1:o*M).*xk0((o-1)*M+1:o*M).*exp(-1j*2*pi*lambda_CFO*((o-1)*M+k)/M));
 end
 r_preamble_integer= r_preamble_integer/N_upchirp;
Yq_preamble_integer=r_preamble_integer;
[~,a_preamble]=max(Yq_preamble_integer);

%% 对payload的处理
r_payload=rk(N_upchirp*M+1:end);
Y_payload=fft(xk0(N_upchirp*M+1:end).*r_payload.*exp(-1j*2*pi*lambda_CFO*k/M));%% dechrip+小数部分补偿+DFT；
Y_payload=[Y_payload(a_preamble:end) Y_payload(1:a_preamble-1)];%% 整数部分循环移位；也可以在dechirp后面做循环移位，再进行DFT。
[~,d]=max(abs(Y_payload/M));
if d-1==a
    error1=0;
else
    error1=1;
end
end