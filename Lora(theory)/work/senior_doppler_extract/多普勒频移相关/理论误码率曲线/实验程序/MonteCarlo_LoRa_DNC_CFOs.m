%带频偏的LoRa计算误码率；
B=250e3;
SF=10;
M=2^SF;
SNR=-25:1:-4;
times=10000000;
% times=10000;
N_error_max=2000;
%  f=rand(1,1);
%  f=f*B/(2*M)
%  f/B
fd=[0 0.1 0.2 0.3 0.4 0.5 0.6 1.1]*B/M;
BER=zeros(length(fd),length(SNR));
BER_Approx=zeros(length(fd),length(SNR));
tic;
h=waitbar(0,'waiting,SF=10');
for i=1:1:length(fd)
    for ii=1:1:length(SNR)
        error=0;
        for iii=1:1:times
            if error<N_error_max
%                 a=randi([0 M-1]);
                a=1;
                [error1]=Nerror(M,B,fd(i),SNR(ii),a);
                error=error+error1;
                N=iii;
            else
                break;
            end
        end
        BER(i,ii)=error/N/2;
        if BER(i,ii)<1E-6
            break;
        end
    end
    waitbar(i/length(fd),h,['fd=',num2str(fd(i)*M/B),'\Deltaf']);
end
toc;
close(h);
%% 计算理论误码率曲线
for j=1:1:length(fd)
    delta_f=B/M;
    epsilon=fd(j)/delta_f;
    if mod(epsilon,1)==0
        if abs(epsilon)<1
            Aq=M;
        else
            Aq=0;
        end
    else
        Aq=abs(sin(pi*epsilon)/sin(pi*epsilon/M));
    end
    Aq_ncoh=getAq(SF,epsilon);
    Aq_ncoh=sort(Aq_ncoh,'descend');
    for jj=1:1:length(SNR)
        SNR_dB=10^(SNR(jj)/10);
        N_SI=getN(SF,Aq_ncoh,SNR_dB);
        H=harmonic(M-N_SI-1);%调和数
        %噪声引起的误码率
        Pe_N=qfunc(Aq*sqrt(2*SNR_dB/M)-sqrt(2*H));
        %频谱扩散引起的误码率
        Pe_I=1;
        for k=1:N_SI
            Pe_I=Pe_I*(1-qfunc((Aq-Aq_ncoh(k))*sqrt(SNR_dB/M)));
        end
        %总误码率
        BER_Approx(j,jj)=0.5*(1- (1-Pe_N)*Pe_I);
    end
end

%% 画图
figure;
% c=['k';'b';'g';'r';'c';'m';'y';'b'];
c=[1 0.5 0;
    0 0 1;
    0 1 0;
    1 0 0;
    0 1 1;
    1 0 1;
    1 1 0;
    0.5 0 0;];
m=['p';'o';'x';'d';'+';'s';'v';'h'];
for f=1:1:length(fd)
    semilogy(SNR,BER(f,:),'LineStyle','-.','LineWidth',1.5,'Color',c(f,:),'Marker',m(f));hold on;%
    semilogy(SNR,BER_Approx(f,:),'k-.','Marker',m(f));hold on;%
end
xlabel('SNR(dB)');ylabel('BER');
grid on;
% legend('SF=10,f_d=0.1*\Deltaf,simu','SF=10,f_d=0.1*\Deltaf,Approx','SF=10,f_d=0.2*\Deltaf,simu','SF=10,f_d=0.2*\Deltaf,Approx','SF=10,f_d=0.3*\Deltaf,simu','SF=10,f_d=0.3*\Deltaf,Approx','SF=10,f_d=0.4*\Deltaf,simu','SF=10,f_d=0.4*\Deltaf,Approx','SF=10,f_d=0.5*\Deltaf,simu','SF=10,f_d=0.5*\Deltaf,Approx','SF=10,f_d=0.6*\Deltaf,simu','SF=10,f_d=0.6*\Deltaf,Approx','location','SouthOutside');
le=legend('ε=0,simu','ε=0,Approx','ε=0.1,simu','ε=0.1,Approx','ε=0.2,simu','ε=0.2,Approx','ε=0.3,simu','ε=0.3,Approx','ε=0.4,simu','ε=0.4,Approx','ε=0.5,simu','ε=0.5,Approx','ε=0.6,simu','ε=0.6,Approx','ε=-30.5,simu','ε=-30.5,Approx','location','SouthOutside');
% set(le,'Orientation','horizon','Box','off')
xlim([-25 -4]);
xticks([-25 -20 -15 -10 -5])
xticklabels({'-25','-20','-15','-10','-5'})
ylim([10^-6 1]);
title('B=500K');
% %% 画图
% figure;
% c=['b';'g';'r';'c';'m';'y'];
% m=['o';'x';'+';'*';'s';'v'];
% 
%     semilogy(SNR,BER(1,:),'bo','MarkerSize',7);hold on;%
%     semilogy(SNR,BER(2,:),'gx','MarkerSize',7);hold on;%
%     semilogy(SNR,BER(3,:),'r+','MarkerSize',7);hold on;%
%     semilogy(SNR,BER(4,:),'c*','MarkerSize',7);hold on;%
%     semilogy(SNR,BER(5,:),'ms','MarkerSize',7);hold on;%
%     semilogy(SNR,BER(6,:),'yv','MarkerSize',7);hold on;%
% for f=1:1:length(fd)
% %     semilogy(RSNR,BER(f,:),'LineStyle','.-','LineWidth',1.5,'Color',c(f),'Marker',m(f));hold on;%
%     semilogy(SNR,BER_Approx(f,:),'LineStyle','-.','LineWidth',1.5,'Color',c(f));hold on;%
% end
% 
% xlabel('SNR(dB)');ylabel('BER');
% grid on;
% % legend('SF=7,f_d=0.1*\Deltaf,simu','SF=7,f_d=0.1*\Deltaf,Approx','SF=7,f_d=0.2*\Deltaf,simu','SF=7,f_d=0.2*\Deltaf,Approx','SF=7,f_d=0.3*\Deltaf,simu','SF=7,f_d=0.3*\Deltaf,Approx','SF=7,f_d=0.4*\Deltaf,simu','SF=7,f_d=0.4*\Deltaf,Approx','SF=7,f_d=0.5*\Deltaf,simu','SF=7,f_d=0.5*\Deltaf,Approx','SF=7,f_d=0.6*\Deltaf,simu','SF=7,f_d=0.6*\Deltaf,Approx','location','SouthOutside');
% %xlim([-20 -4])
% legend('f_d=0.1*\Deltaf,simu','f_d=0.2*\Deltaf,simu','f_d=0.3*\Deltaf,simu','f_d=0.4*\Deltaf,simu','f_d=0.5*\Deltaf,simu','f_d=0.6*\Deltaf,simu','f_d=0.1*\Deltaf,Approx','f_d=0.2*\Deltaf,Approx','f_d=0.3*\Deltaf,Approx','f_d=0.4*\Deltaf,Approx','f_d=0.5*\Deltaf,Approx','f_d=0.6*\Deltaf,Approx')
% ylim([10^-6 1]);
%%
function [aaerror]=Nerror(M,B,f,SNR,aa)
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+f/B));
rk1=awgn(xk,SNR);
%解调,传统
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
Yq=fft(rk1.*xk0)/M;
Yq=abs(Yq);%非相干解调
[~,decision]=max(Yq);
    if ((decision-1) ~= aa)
        aaerror = 1;
    else
        aaerror = 0;
    end
end

%% 获得理论频谱扩散在解调域上形成的幅值
function [Aq_ncoh]=getAq(SF,epsilon)
%
M=2^SF;
aa=M/2;
Aq_ncoh=zeros(1,M);
for q=1:1:M
   Dq_ncoh_tem=sin(pi*(q-aa-epsilon))/sin(pi*(q-aa-epsilon)/M);
   Aq_ncoh(q)=abs(Dq_ncoh_tem);
end
if mod(epsilon,1)==0
    if abs(epsilon)<1
        Aq_ncoh(aa)=0;
    else
        Aq_ncoh(aa+epsilon)=M;
    end
else
    Aq_ncoh(aa)=0;
end
end

%% 获取干扰集的个数
function N=getN(SF,Aq_ncoh,SNR_dB)
M=2^SF;
N=0;
for i=1:M
    Aq_ncoh_tem=SNR_dB*(Aq_ncoh(i))^2/(M);
    if 10*log10(Aq_ncoh_tem)>=1.3
        N=N+1;
    end
end
end