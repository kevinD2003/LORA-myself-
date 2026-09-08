%% 带频偏的LoRa计算误码率；并计算理论误码率。
%% 相同频偏不同带宽B
B=[125e3 250e3 500e3];
SF=11;
M=2^SF;
SNR=-25:1:0;
times=10000000;
N_error_max=2000;
fd=48.2;
BER=zeros(length(B),length(SNR));
BER_Approx=zeros(length(B),length(SNR));
tic;
h=waitbar(0,'waiting,SF=7');
for i=1:1:length(B)
    B_tmp = B(i);
    for ii=1:1:length(SNR)
        error=0;
        for iii=1:1:times
            if error<N_error_max
                a=randi([0 M-1]);
                [error1]=Nerror(M,B_tmp,fd,SNR(ii),a);
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
    waitbar(i/length(B),h,['SF=',num2str(SF),',f_d=' num2str(fd) ',B=' num2str(B(i))]);
end
toc;
close(h);
%% 计算理论误码率曲线
for j=1:1:length(B)
    M=2^SF;
    delta_f=B(j)/M;
    epsilon=fd/delta_f;
    Aq=abs(sin(pi*epsilon)/sin(pi*epsilon/M));
    Aq_ncoh=getAq(SF,epsilon);
    Aq_ncoh=sort(Aq_ncoh,'descend');
%     H=harmonic(M-2);%调和数
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
c=['b';'g';'r';'c';'m';'y'];
m=['o';'x';'d';'+';'s';'v'];
for f=1:1:length(B)
    semilogy(SNR,BER(f,:),'LineStyle','-','LineWidth',1.5,'Color',c(f),'Marker',m(f));hold on;%
    semilogy(SNR,BER_Approx(f,:),'k--','Marker',m(f));hold on;%
end
xlabel('SNR(dB)');ylabel('BER');
grid on;
legend(['B = ' num2str(B(1)/1000) 'kHz, simu'],['B = ' num2str(B(1)/1000) 'kHz, Approx'],...
    ['B = ' num2str(B(2)/1000) 'kHz, simu'],['B = ' num2str(B(2)/1000) 'kHz, Approx'],['B = ' num2str(B(3)/1000) 'kHz, simu'],['B = ' num2str(B(3)/1000) 'kHz, Approx']);
% legend('SF=7,simu','SF=7,Approx','SF=8,simu','SF=8,Approx','SF=9,simu','SF=9,Approx','SF=10,simu','SF=10,Approx','SF=11,simu','SF=11,Approx','SF=12,simu','SF=12,Approx','location','SouthOutside');
ylim([10^-6 1]);
% title('B=500K');

%% LoRa非相干解调DNC
function [aaerror]=Nerror(M,B,f,SNR,aa)
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+f/B));
rk1=awgn(xk,SNR);
%解调,传统DNC
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
if abs(epsilon)<1
    Aq_ncoh(aa)=0;
end
if mod(epsilon,1)==0
    Aq_ncoh(aa+epsilon)=M;
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