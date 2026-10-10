%% 多普勒频偏+多径，采用差分编码
%% 两径信道+不同多普勒
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
%% 
SNR=-25:1:15;
N_error_max=200;
N_upchirps=8;
times=10000;
BER_MF=zeros(1,length(SNR));
tic;
%% 
N_symbol=2;
N_upchirp=8;
BER_DCSS=zeros(1,length(SNR));
tic;
h=waitbar(0,'差分编码');

%% 
for j=1:length(SNR)
    error_dcss=0;
    for jj=1:times
        if error_dcss < N_error_max
            error_dcss =error_dcss + DCSS(M,N_symbol,N_upchirp,epsilon,SNR(j),hi,ui,In_sto,Fr_sto);
            N = jj;
        end
    end
    BER_DCSS(j)=error_dcss/N/2/(N_symbol-1);
    if(BER_DCSS(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['fd=' num2str(SNR(j))]);
end
toc;
close(h);
%%
c=['k';'m';'c';'b';'g';'r';'y'];
m=['x';'d';'s';'*';'+';'o';'v'];
figure;
semilogy(SNR,BER_DCSS,'LineStyle','-','Color','g','Marker','*');hold on;
legend(['SF=' num2str(SF) ',DCSS'])
grid on;



function error = DCSS(M,N_symbol,N_upchirp,epsilon,SNR,hi,ui,In_sto,Fr_sto)
error = 0;
Sp=randi([1 M-1],1,N_symbol);
Dp=zeros(1,length(Sp));
Dp(1)=Sp(1);
for i=2:N_symbol
    Dp(i)=mod((Sp(i)+Dp(i-1)),M);
end

%% 加STO
k=0:1:M-1;
STO_in = exp(1j*2*pi*In_sto*k/M);
STO_fr = exp(1j*2*pi*Fr_sto*k/M);
STO_fr = circshift(STO_fr, M-In_sto);
%% 调制
Sk=zeros(1,N_symbol*M);
for ii=1:N_symbol
    Sk((ii-1)*M+1:ii*M)=exp(1j*2*pi*k.*(Dp(ii)/M-1/2+k/2/M+epsilon(1)/M)).* STO_in .* STO_fr;%调制
end
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(1)/M)) .* STO_in .* STO_fr;%前导码

Sk_pre=zeros(1,N_upchirp*M);
for ii = 1 : N_upchirp
    Sk_pre((ii-1)*M+1 : ii*M) = xk_preamble;
end

Sk_frame=hi(1) * [Sk_pre Sk];%组帧
%% 添加高斯噪声
sigPower=sum(abs(Sk_frame.*Sk_frame))/length(Sk_frame);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(Sk_frame))+1j*randn(1,length(Sk_frame)));
%% 多径
rk_mpc = zeros(1,length(Sk_frame));
for i = 2 : length(ui)
    for ii=1:N_symbol       
%         Sk_tmp((ii-1)*M+1:ii*M)=exp(1j*2*pi*k.*(Dp(ii)/M-1/2+k/2/M+epsilon(i)/M)).* STO_in .* STO_fr;%调制
        Sk_tmp((ii-1)*M+1:ii*M)=exp(1j*2*pi*k.*(Dp(ii)/M-1/2+k/2/M));%调制
    end
%     xk_preamble_tmp=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(i)/M)) .* STO_in .* STO_fr;%前导符号
    xk_preamble_tmp=exp(1j*2*pi*k.*(-1/2+k/2/M));%前导符号
    Sk_pre_tmp=zeros(1,N_upchirp*M);
    for ii = 1 : N_upchirp
        Sk_pre_tmp((ii-1)*M+1 : ii*M) = xk_preamble_tmp;
    end
    xk_frame=[Sk_pre Sk_tmp];
    rk_mpc_tmp = [zeros(1, ui(i)) xk_frame(1 : end - ui(i))];
    for ii = 1 : N_upchirp+N_symbol
        rk_mpc_tmp((ii-1)*M+1 : ii*M) = rk_mpc_tmp((ii-1)*M+1 : ii*M) .* exp(1j*2*pi*k.*(epsilon(i)/M)) .* STO_in .* STO_fr;
    end
    rk_mpc = rk_mpc + hi(i)*rk_mpc_tmp;
end
%% 接收信号
Rk_frame=Sk_frame+noise+rk_mpc;
Rk=Rk_frame(N_upchirp*M+1:end);
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
%% 解调
Dp_ncoh=zeros(1,N_symbol);
for o=1:N_symbol
    Yq=abs(fft(Rk((o-1)*M+1:o*M).*xk0)/M);
    [~,decision]=max(Yq);
    Dp_ncoh(o)=decision-1;
end
Sp_ncoh=zeros(1,N_symbol);

for iii=2:N_symbol
    Sp_ncoh(iii)=mod(Dp_ncoh(iii)-Dp_ncoh(iii-1),M);
    if Sp_ncoh(iii)~=Sp(iii)
        error=error+1;
    end
end
end