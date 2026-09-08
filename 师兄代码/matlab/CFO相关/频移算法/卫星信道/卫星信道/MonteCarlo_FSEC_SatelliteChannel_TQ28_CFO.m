%% 补偿法，采用频移的方式（将小数倍的频移补全至整数倍）。
%% 小数部分CFO的估计与补偿。
%% 天启28星
% SF=7,B=125k;preamble:8,payload:22;883s,每秒钟33帧。
% SF=12,B=125k;preamble:8,payload:22;883s,每秒钟1帧。
%% Monte Carlo实验 CFO。
load('TQ28_CFO.mat');
B = 125e3;
SF=12;
M = 2^SF;
N_frame=33;
N_upchirp=8;
N_payload=22+(8-N_upchirp);%数据块的装载
SNR=-25:1:0;
BER_FD_Shift=zeros(1,length(SNR));
times=883;
tic;
h=waitbar(0,['SF=' num2str(SF) ',TQ28']);
for j=1:length(SNR)
    error=0;
    for jj=1:times
        epsilon = F_cfo(jj) * M / B;
        for jjj = 1 : N_frame
            [error1]=FD_Shift(SF,epsilon,SNR(j),N_payload,N_upchirp);
            error=error+error1;
        end
    end
    BER_FD_Shift(j)=error/(times*N_payload*N_frame)/2;
    if(BER_FD_Shift(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['SNR= ' num2str(SNR(j))]);
end
toc;
close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
c =['r';'y';'g';'c';'m'];
figure;
% for f=1:length(epsilon)
% % semilogy(SNR,BER_LoRa(f,:),'LineWidth',1,'Color','b','LineStyle','-','Marker',m(f));hold on
% semilogy(SNR,BER_FD_Shift(f,:),'Color',c(f),'LineStyle','-','Marker',m(f));hold on
% end
semilogy(SNR,BER_FD_Shift,'Color','r','LineStyle','-','Marker','o');
legend(['New Algorithm,SF=' num2str(SF) ',TQ28']);
xlabel('SNR');ylabel('BER')
grid on;

%% 
function [error1]=FD_Shift(SF,epsilon,SNR,N_payload,N_upchirp)
error1=0;
M=2^SF;
aa=randi([0 M-1], 1, N_payload);
k=0:1:M-1;
%% 调制
xk_payload=zeros(1,M*N_payload);
for i=1:N_payload
    xk_payload((i-1)*M+1:i*M)=exp(1j*2*pi*k.*(aa(i)/M-1/2+k/2/M+epsilon/M));
end
xk_pre=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
xk_preamble=zeros(1,M*N_upchirp);
for ii=1:N_upchirp
    xk_preamble((ii-1)*M+1:ii*M)=xk_pre;
end

%% 组帧
xk_frame=[xk_preamble xk_payload];
%% 加噪
rk1=awgn(xk_frame,SNR,'measured');
%% 解帧
rk_preamble=rk1(1:N_upchirp*M);
rk_payload=rk1(N_upchirp*M+1:end);
%% 解调
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);%基信号的共轭
% 前导码的处理
r_pre_ave=zeros(1,M);
%只用num个前导码
for o=1:N_upchirp
    rk_pre=rk_preamble((o-1)*M+1:o*M);
    r_pre_ave=r_pre_ave+rk_pre;
end
r_pre_ave=r_pre_ave/N_upchirp;
% 估计
epsilon_i=0;
eta=0;
eta_o=0;
Yq_max=0;
step=0.1;
while eta_o<=0.9
    y_preamble_tem=abs(fft(r_pre_ave.*exp(1j*2*pi*k*eta_o/M).*xk0));
    [Yq_max_tmp,epsilon_integer_tmp]=max(y_preamble_tem);
    if Yq_max_tmp > Yq_max
        Yq_max = Yq_max_tmp;
        epsilon_i = epsilon_integer_tmp;
        eta = eta_o;
    end
    eta_o=eta_o+step;
end


% 数据块的处理
for j=1:N_payload
    y_payload=abs(fft(rk_payload((j-1)*M+1:j*M).*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;%补偿
    [~,d]=max(abs(y_payload));
    if d-1~=aa(j)
        error1=error1+1;
    end
end
end
