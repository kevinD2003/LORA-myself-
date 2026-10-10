%% Monte Carlo实验，多普勒-高斯信道
SF=12;
M = 2^SF;
% SNR=-25:1:-20;
SNR=-25:0;
% SNR=-22;
BER_PRC=zeros(1,length(SNR));
epsilon=[0.5 0.8];
N_upchirp=8;
N_payload=1;
ui=[0 ceil(M/3)];
% times=[100000*ones(1,length(SNR))];
% times=10000;
times=[10000*ones(1,17) 100000*ones(1,4) 1000000*ones(1,2) 10000000*ones(1,6)];
tic;
h=waitbar(0,['SF=' num2str(SF) ',计算中']);
% close(h);
%% methods
for j=1:length(SNR)
    error_prc=0;
    for jj = 1 : times(j)
        % epsilon=rand();%SF=12,B=250k时，v=[0 75]km/h
        [error1]=methods_PRC_EC(SF,epsilon,ui,SNR(j),N_payload,N_upchirp);
        error_prc=error_prc+error1;
        
    end
    BER_PRC(j)=error_prc/(times(j)*N_payload)/2;
    if(BER_PRC(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['methods, SNR= ' num2str(SNR(j))]);
end
close(h);
toc;
% close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
c =['r';'y';'g';'c';'m'];
figure;
semilogy(SNR,BER_PRC,'Color','r','LineStyle','-','Marker','o');hold on;
title('两径信道：时延为T_c/3；速度第一径为0.5，第二径为0.8；SF=12，B=250k')
%title(['TQ28 Satellite Channel, SF = ' num2str(SF) ', B = 125kHz']);
legend(['PRC,' num2str(N_upchirp) ' upchirps']);
xlabel('SNR (dB)');ylabel('BER')
grid on;

% figure;
% plot(SNR,10*log10(RMSE_EC),'Color',[0.07 0.62 1],'LineStyle','-','Marker','v');hold on
% plot(SNR,10*log10(RMSE_PRC),'Color','r','LineStyle','-','Marker','o');hold on;
% %title(['TQ28 Satellite Channel, SF = ' num2str(SF) ', B = 125kHz']);
% legend(['EC,' num2str(N_upchirp) ' upchirps'],['PRC,' num2str(N_upchirp) ' upchirps']);
% xlabel('SNR (dB)');ylabel('RMSE (dB)')
% grid on;


 % save(['RicianFading' num2str(cycle_times) 'time_' 'SF_' num2str(SF) '_' num2str(N_upchirp) '_upchirps_EC_PRC_TQ28_BER.mat'],...
 %    "BER_EC",'BER_PRC', ...
 %    'SNR','SF','B','N_upchirp','N_frame');
%% methods BICS-PRC  
function [error1]=methods_PRC_EC(SF,epsilon,ui,SNR,N_payload,N_upchirps)
error1=0;
M=2^SF;
aa=randi([0 M-1], 1, N_payload);
k=0:1:M-1;
%% PRC
%% 调制
xk_payload=zeros(1,M*N_payload);
rotation_factor=exp(1j*2*pi*k*epsilon(1)/M);
for i=1:N_payload
    xk_payload_tmp=exp(1j*2*pi*k.*(aa(i)/M-1/2+k/2/M));
    % xk_payload_tmp=[xk_payload_tmp(1:M/4) xk_payload_tmp(M/2+1:M*3/4) xk_payload_tmp(M/4+1:M/2) xk_payload_tmp(1+3*M/4:end)];
    xk_payload((i-1)*M+1:i*M)=xk_payload_tmp;
end
xk_pre=exp(1j*2*pi*k.*(-1/2+k/2/M));%前导符号
% xk_pre=[xk_pre(1:M/4) xk_pre(M/2+1:M*3/4) xk_pre(M/4+1:M/2) xk_pre(1+3*M/4:end)];
xk_preamble=zeros(1,M*N_upchirps);
for ii=1:1:N_upchirps
    xk_preamble((ii-1)*M+1:ii*M)=xk_pre;
end
rotation_factor_frame=zeros(1,M*(N_upchirps+N_payload));
for i=1:N_payload+N_upchirps
    rotation_factor_frame(1+(i-1)*M:i*M)=rotation_factor;
end
%% 组帧
xk_frame=[xk_preamble xk_payload];
xk_frame_CM=xk_frame.*rotation_factor_frame;
%% 加噪
%% 手动添加高斯噪声
sigPower=sum(abs(xk_frame.*xk_frame))/length(xk_frame);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(xk_frame))+1j*randn(1,length(xk_frame)));
%% 多径
rk_multipath=zeros(1,length(xk_frame));
for o=2:length(ui)
    rk_multipath_tmp=[zeros(1,ui(o)) xk_frame(1:end-ui(o))];
    rotation_factor_tmp=exp(1j*2*pi*k*epsilon(o)/M);
    rotation_factor_frame_tmp=zeros(1,M*(N_upchirps+N_payload));
    for i=1:N_payload+N_upchirps
        rotation_factor_frame_tmp(1+(i-1)*M:i*M)=rotation_factor_tmp;
    end
    rk_multipath=rk_multipath+rk_multipath_tmp.*rotation_factor_frame_tmp;
end

rk1=xk_frame_CM+noise+rk_multipath;
% rk1=xk_frame+noise;
%% 解帧
rk_preamble=rk1(1:N_upchirps*M);
rk_payload=rk1(N_upchirps*M+1:end);
%% 解调
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);%基信号的共轭
% 前导码的处理
r_pre_ave=zeros(1,M);
%只用num个前导码
for o=1:N_upchirps
    rk_pre=rk_preamble((o-1)*M+1:o*M);
    % rk_pre=[rk_pre(1:M/4) rk_pre(M/2+1:M*3/4) rk_pre(M/4+1:M/2) rk_pre(1+3*M/4:end)];
    r_pre_ave=r_pre_ave+rk_pre;

end
r_pre_ave=r_pre_ave/N_upchirps;
%% 估计
epsilon_i=0;
eta=0;
eta_o=0;
Yq_max=0;
step=0.1;
while eta_o<1
    y_preamble_tem=abs(fft(r_pre_ave.*exp(1j*2*pi*k*eta_o/M).*xk0));
    [Yq_max_tmp,epsilon_integer_tmp]=max(y_preamble_tem);
    if Yq_max_tmp>Yq_max
        Yq_max=Yq_max_tmp;
        eta=eta_o;
        epsilon_i=epsilon_integer_tmp;
    end
    eta_o=eta_o+step;
end
%% 补偿
for j=1:N_payload
    rk_pay=rk_payload((j-1)*M+1:j*M);
    % rk_pay=[rk_pay(1:M/4) rk_pay(M/2+1:M*3/4) rk_pay(M/4+1:M/2) rk_pay(1+3*M/4:end)];
    y_payload=abs(fft(rk_pay.*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
    [~,d]=max(abs(y_payload));
    if d-1~=aa(j)
        error1=error1+1;
    end
end
end


