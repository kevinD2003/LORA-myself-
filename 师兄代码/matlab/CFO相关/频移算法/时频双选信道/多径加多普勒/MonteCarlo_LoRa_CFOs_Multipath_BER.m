%% 多径+多普勒的LoRa计算误码率；
%% LoRa通信参数
B=250e3;
SF=10;
M=2^SF;
%% 两径信道
hi=[sqrt(0.8) sqrt(0.2)]/sqrt(0.8);%
% hi = [1 1];
% epsilon=[0.2 0.3];
v=[120 90]*5/18;%m/s; 单位转换 km/h乘上5/18得到m/s
fc = 868e6;% Hz
c = 3e8;% m/s
f_cfo = fc * v / c;
epsilon = f_cfo * M / B;
ui=[0 6];

% %% VehB channel
% power=[-2.5 0 -12.8 -10.0 -25.2 -16];%dB
% delay=[0 300 8900 12900 17100 20000];%ns
% hi=10.^(power/10);
% ui=ceil(B*delay*10^-9);

%% 
SNR=-25:1:30;
% times=10000000;
times = 10000000;
N_error_max=2000;
BER=zeros(1,length(SNR));
BER_Approx=zeros(1,length(SNR));
tic;
h=waitbar(0,'waiting,SF=10');
for ii=1:1:length(SNR)
    error=0;
    for iii=1:1:times
        if error<N_error_max
            [error1]=Nerror(M,epsilon,ui,hi,SNR(ii));
            error=error+error1;
            N=iii;
        else
            break;
        end
    end
    BER(1,ii)=error/N/2;
    if BER(1,ii)<1E-6
        break;
    end
    waitbar(ii/length(SNR),h,['SNR=',num2str(SNR(ii)),'dB']);
end

toc;
close(h);
%% 计算理论误码率
a = M / 2;
Aq_ncoh=getAq(a,SF,epsilon,ui,hi);
% Aq=Aq_ncoh(a+1)/M;
Aq=sin(pi*epsilon(1))/sin(pi*epsilon(1)/M)*exp(1j*pi*(1-1/M))/M;
Aq=abs(Aq);
% Aq=(Aq+Aq_ncoh(a+1)/M)/2;
Aq_ncoh(a+1)=0;
Aq_ncoh=sort(Aq_ncoh,'descend')/M;
% H=harmonic(M-2);%调和数
for i=1:1:length(SNR)
    SNR_dB=10^(SNR(i)/10);
    N_SI=getN(SF,Aq_ncoh,SNR_dB);
    nsi(1,i)=N_SI;%%%%%%%%%%%%%%%%%%%%%%%
    H=harmonic(M-N_SI-1);%调和数
    %噪声引起的误码率
    Pe_N=qfunc(Aq*sqrt(2*SNR_dB*M)-sqrt(2*H));
    %多径引起的误码率
    Pe_I=1;
    for k=1:N_SI
        Pe_I=Pe_I*(1-qfunc((Aq-Aq_ncoh(k))*sqrt(SNR_dB*M)));
    end
    %总误码率
    BER_Approx(1,i)=0.5*(1- (1-Pe_N)*Pe_I);
end 

%% 画图
figure;
semilogy(SNR,BER,'-o')
xlabel('SNR (dB)');ylabel('BER');
grid on;
ylim([10^-6 1]);
% legend(['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',ε=' num2str(epsilon(2))] );
% legend('三径信道，时延为0,6,10');

hold on
semilogy(SNR,BER_Approx(1,:),'r--*');hold on;%
% xlabel('SNR(dB)','FontName','Times New Roman','FontSize',12);
% ylabel('$BER$','FontName','Times New Roman','Interpreter','latex','FontSize',12);grid on;
ylim([10^-6 1]);
% xlim([-25 35]);
% legend(['$L=' num2str(L) ',ncoh,Approx$'],'FontName','Times New Roman','Interpreter','latex','FontSize',8);
legend(['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',v1=' num2str(v(1) * 18 / 5) 'km/h, v2=' num2str(v(2) * 18 / 5) 'km/h, simu'],...
    ['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',v1=' num2str(v(1) * 18 / 5) 'km/h, v2=' num2str(v(2) * 18 / 5) 'km/h, Approx']);
% legend(['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',ε1=' num2str(epsilon(1)) ',ε2=' num2str(epsilon(2)) ', simu'],...
%     ['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',ε1=' num2str(epsilon(1)) ',ε2=' num2str(epsilon(2)) ', Approx']);

%%
function [Aq_ncoh]=getAq(a,SF,epsilon,ui,hi)
%获得理论叠加的多径在解调域上形成的幅值
M=2^SF;
Yq_t=zeros(1,M);
for q=0:1:M-1
    for i=1:length(ui)
        Yq_tem1=sin(pi*(1-ui(i)/M)*(q-a-epsilon(i)+ui(i)));
        Yq_tem2=sin(pi*(1/M)*(q-a-epsilon(i)+ui(i)));
        Yq_t_tem=(Yq_tem1/Yq_tem2)*exp(-1j*pi*(q*(1+ui(i)/M-1/M)+(a+epsilon(i))*(-1+ui(i)/M+1/M)-ui(i)/M));
        Yq_t(q+1)=Yq_t(q+1)+hi(i)*Yq_t_tem;
    end
end
for i=1:length(ui)
    if mod(epsilon(i),1)==0
       Yq_t(a+epsilon(i)-ui(i)+1)=0;
    end
end
for i=1:length(ui)
    if mod(epsilon(i),1)==0
       Yq_t(a+epsilon(i)-ui(i)+1)=Yq_t(a+epsilon(i)-ui(i)+1)+hi(i)*(M-ui(i));
    end
end
Aq_ncoh=abs(Yq_t);
% figure;
% plot(0:M-1,Aq_ncoh/M);
end

%% 获取干扰集的个数
function N=getN(SF,Aq_ncoh,SNR_dB)
M=2^SF;
N=0;
for i=1:M
    Aq_ncoh_tem=SNR_dB*(Aq_ncoh(i))^2*M;
    if 10*log10(Aq_ncoh_tem)>=1.3
        N=N+1;
    end
end

end



%% 
function [aaerror]=Nerror(M,epsilon,ui,hi,SNR)
a=randi([0 M-1]);
k=0:1:M-1;
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
rkm=zeros(1,M);
xk=hi(1)*exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(1)/M));%直达径信号，先衰减再加噪；
% xk=hi(1)*exp(1j*2*pi*k.*(a/M-1/2+k/2/M));%直达径信号，先衰减再加噪
% rotation=exp(1j*2*pi*k.*(epsilon(1)/M));%直达径信号，先衰减再加噪
% xk = xk .* rotation;
%% 手动添加高斯噪声
sigPower=sum(abs(xk.*xk))/M;
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,M)+1j*randn(1,M));
%% 多径
for i=2:length(ui)
    xkm=hi(i)*exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(i)/M));
%     xkm=hi(i)*exp(1j*2*pi*k.*(a/M-1/2+k/2/M));
%     rotation_m=exp(1j*2*pi*k.*(epsilon(i)/M));
%     xkm = xkm .* rotation_m;
    xk_tem=[zeros(1,ui(i)) xkm(1:M-ui(i))];
    rkm=rkm+xk_tem;
end
rk=xk+rkm+noise;%先衰减再加噪
Yq=abs(fft(rk.*xk0)/M);%非相干解调
[~,decision]=max(Yq);
    if ((decision-1) ~= a)
        aaerror = 1;
    else
        aaerror = 0;
    end
end

