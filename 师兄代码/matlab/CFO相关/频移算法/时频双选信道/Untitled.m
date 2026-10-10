%% A Low-Complexity LoRa Synchronization Algorithm Robust to Sampling Time Offsets
%% 小数部分CFO的估计与补偿。
%% Monte Carlo实验
%% LoRa通信参数
B=250e3;
SF=10;
M=2^SF;
%% 信道参数
load('6path.mat');
%% 两径信道
% num = 6;
% hi = g(1:num) / g(1);
% epsilon = fd(1:num) * M / B;
% ui=ceil(tau(1:num) * B);
epsilon = 0.8;
ui=0;
hi=1;
%% 假设收发双方相距5km(考虑仅由传播时延引起的STO)
distance = 5e3;
t_sto = distance / (3e8);
N_t_sto = B * t_sto;%归一化
In_sto = floor(N_t_sto);%整数STO
Fr_sto = mod(N_t_sto,1);%小数STO
In_sto = 0;%无整数STO
Fr_sto = 0;%无小数STO
%% 
SNR=-25:10;
BER_EC=zeros(1,length(SNR));
times=1000;
N_error_max = 2000;
N_upchirp = 8;
tic;
h=waitbar(0,'SF=12,\lambda=0.8');
for j=1:length(SNR)
    error_ec=0;
    rmse=0;
    for jj=1:times
        if error_ec < N_error_max
            [error1]=EC(SF,N_upchirp,epsilon,SNR(j),ui,hi,In_sto,Fr_sto);
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
function [error1]=EC(SF,N_upchirp,epsilon,SNR,ui,hi,In_sto,Fr_sto)
M=2^SF;
k=0:M-1;
a=randi([0 M-1]);
Nc=7;
xk=exp(1j*2*pi*k.*(a/M-1/2+(k+N_upchirp*M)/2/M+epsilon(1)/M));
xk_preamble = zeros(1,N_upchirp*M);
for i = 1 : N_upchirp
    xk_preamble((i-1)*M+1 : i*M) = exp(1j*2*pi*(k+(i-1)*M).*(-1/2+(k+(i-1)*M)/2/M+epsilon(1)/M));
end
%% 
xk_frame=[xk_preamble xk];
xk_dp = hi(1) * xk_frame;
%% 手动添加高斯噪声
sigPower=sum(abs(xk_dp.*xk_dp))/length(xk_dp);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(xk_frame))+1j*randn(1,length(xk_frame)));

%% 多径
rk_mpc = zeros(1,length(xk_frame));
for i = 2 : length(ui)
    xk_tmp=exp(1j*2*pi*(k+N_upchirp*M).*(a/M-1/2+(k+N_upchirp*M)/2/M+epsilon(i)/M));
%     xk_preamble_tmp=exp(1j*2*pi*n.*(-1/2+n/2/M+epsilon(i)/M)) .* STO_in_n .* STO_fr_n;%前导符号
    xk_preamble_tmp = zeros(1,N_upchirp*M);
    for ii = 1 : N_upchirp
        xk_preamble_tmp((ii-1)*M+1 : ii*M) = exp(1j*2*pi*(k+(ii-1)*M).*(-1/2+(k+(ii-1)*M)/2/M));
    end
    xk_frame=[xk_preamble_tmp xk_tmp];
    rk_mpc_tmp = [zeros(1, ui(i)) xk_frame(1 : end - ui(i))];
    for ii = 1 : N_upchirp+1
        rk_mpc_tmp((ii-1)*M+1 : ii*M) = rk_mpc_tmp((ii-1)*M+1 : ii*M) .* exp(1j*2*pi*(k+(ii-1)*M).*(epsilon(i)/M));
    end
    rk_mpc = rk_mpc + hi(i)*rk_mpc_tmp;
end
%% 
rk = (xk_dp + rk_mpc);
%% 
for ii = 1 : N_upchirp+1
    STO_in = exp(1j*2*pi*In_sto*(k+(ii-1)*M)/M);
    STO_fr = exp(1j*2*pi*Fr_sto*(k+(ii-1)*M)/M);
    STO_fr = circshift(STO_fr, M-In_sto);
    rk((ii-1)*M+1 : ii*M) = rk((ii-1)*M+1 : ii*M).* STO_in .* STO_fr;
end
rk = rk+ noise;

%% 
n = 1:N_upchirp*M;
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
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

% %% 
% xk0=exp(-1j*2*pi*(k+N_upchirp*M).*(-1/2+(k+N_upchirp*M)/2/M));
% lambda_CFO=0;
% for l=1:Nc
%     y_l_1=rk((l-1)*M+1:l*M);
%     y_l=rk(l*M+1:(l+1)*M);
%     Y_l=fft(y_l.*exp(-1j*2*pi*(l*M+k).*(-1/2+(l*M+k)/2/M)));
%     Y_l_1=fft(y_l_1.*exp(-1j*2*pi*((l-1)*M+k).*(-1/2+((l-1)*M+k)/2/M)));
%     [~,i]=max(abs(Y_l));
%     lambda_cfo=0;
%     for p=-2:2
%         n=mod(i+p,M);
%         if n==0
%             n=M;
%         end
%         lambda_cfo=lambda_cfo+Y_l(n)*conj(Y_l_1(n));
%     end
%     lambda_CFO=lambda_CFO+lambda_cfo;
% end
% lambda_CFO=angle(lambda_CFO)/pi/2;
%% 整数部分 循环移位
r_preamble_integer=zeros(1,M);
 for o=1:N_upchirp
     r_preamble_integer=r_preamble_integer+fft(rk((o-1)*M+1:o*M).*xk0_preamble((o-1)*M+1:o*M).*exp(-1j*2*pi*lambda_CFO*((o-1)*M+1:o*M)/M));
%      r_preamble_integer=r_preamble_integer+fft(rk((o-1)*M+1:o*M).*exp(-1j*2*pi*((o-1)*M+k).*(-1/2+((o-1)*M+k)/2/M)).*exp(-1j*2*pi*lambda_CFO*((o-1)*M+1:o*M)/M));
 end
 r_preamble_integer= r_preamble_integer/N_upchirp;
Yq_preamble_integer=r_preamble_integer;
[~,a_preamble]=max(Yq_preamble_integer);
%% 对payload的处理
r_payload=rk(N_upchirp*M+1:end);
Y_payload=fft(xk0.*r_payload.*exp(-1j*2*pi*lambda_CFO*k/M));%% dechrip+小数部分补偿+DFT；
Y_payload=[Y_payload(a_preamble:end) Y_payload(1:a_preamble-1)];%% 整数部分循环移位；也可以在dechirp后面做循环移位，再进行DFT。
[~,d]=max(abs(Y_payload/M));
if d-1==a
    error1=0;
else
    error1=1;
end

end
