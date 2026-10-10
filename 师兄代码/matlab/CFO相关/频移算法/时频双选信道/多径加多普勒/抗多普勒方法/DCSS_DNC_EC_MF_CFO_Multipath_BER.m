%% 多普勒频偏+多径，采用差分编码
B=250e3;
SF=7;
M=2^SF;
SNR=-15:0;
ui=[0 3 6];
% hi=[sqrt(0.8) sqrt(0.2)];
hi=[1 0.7 0.5];
epsilon=0.3;
fd=[epsilon]*B/M;
% fd=0;
% SNR=10;
% fd=0.8*B/M;
N_symbol=2;
BER_DCSS=zeros(length(fd),length(SNR));
times=1000000;
tic;
h=waitbar(0,'差分编码');
for jjj=1:length(fd)
% jjj=1;
    for jj=1:length(SNR)
        error_dcss=0;
        for j=1:times
            Sp=randi([1 M-1],1,N_symbol);
            Dp=zeros(1,length(Sp));
            Dp(1)=Sp(1);
            for i=2:N_symbol
                Dp(i)=mod((Sp(i)+Dp(i-1)),M);
            end
            k=0:1:M-1;
            Sk=zeros(1,N_symbol*M);
            for ii=1:N_symbol
                Sk((ii-1)*M+1:ii*M)=exp(1j*2*pi*k.*(Dp(ii)/M-1/2+k/2/M+fd(jjj)/B));%调制
            end
            xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd(jjj)/B));%前导码
            Sk_preamble=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble];
            Sk_frame=[Sk_preamble Sk];%组帧
            S_matipath=zeros(1,length(Sk_frame));
            for i=2:length(ui)
                S_temp=[zeros(1,ui(i)) Sk_frame(1:end-ui(i))];
                S_matipath=S_matipath+hi(i)*S_temp;
            end
            Sk_frame=hi(1)*Sk_frame;
            Rk_frame=awgn(Sk_frame,SNR(jj),'measured');
            Rk_frame=Rk_frame+S_matipath;
            Rk=Rk_frame(8*M+1:end);
            xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
            Dp_ncoh=zeros(1,N_symbol);
            for o=1:N_symbol
                Yq=abs(fft(Rk((o-1)*M+1:o*M).*xk0)/M);
                %     figure;plot(0:M-1,Yq);
                [~,decision]=max(Yq);
                Dp_ncoh(o)=decision-1;
            end
            Sp_ncoh=zeros(1,N_symbol);
            
            for iii=2:N_symbol
                Sp_ncoh(iii)=mod(Dp_ncoh(iii)-Dp_ncoh(iii-1),M);
                if Sp_ncoh(iii)~=Sp(iii)
                    error_dcss=error_dcss+1;
                end
            end
        end
        BER_DCSS(jjj,jj)=error_dcss/times/2/(N_symbol-1);
        waitbar(jj/length(SNR),h,['fd=' num2str(SNR(jj))]);
    end
    waitbar(jjj/length(fd),h,['fd=' num2str(fd(jjj))]);
end
toc;
close(h);
%%
c=['k';'m';'c';'b';'g';'r';'y'];
% c=[0 0 0;
%     0 0 1;
%     1 0 0;
%     1 0.5 0;
%     1 0 1;
%     0.41961 0.55686 0.13725;];
m=['x';'d';'s';'*';'+';'o';'v'];
figure;
for f=1:length(fd)
    semilogy(SNR,BER_DCSS(f,:),'LineStyle','-','Color',c(f,:),'Marker',m(f));hold on;
end
title('DCSS');
legend(['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',epsilon=' num2str(epsilon)])
% legend('DCSS,fd=0','DCSS,fd=0.1*\Deltaf','DCSS,fd=0.2*\Deltaf','DCSS,fd=0.3*\Deltaf','DCSS,fd=0.4*\Deltaf','DCSS,fd=0.5*\Deltaf','DCSS,fd=0.6*\Deltaf');
grid on;



%% A Low-Complexity LoRa Synchronization Algorithm Robust to Sampling Time Offsets
%% 小数部分CFO的估计与补偿。
%% Monte Carlo实验 CFO+Multipath

lambda=epsilon;
BER_LoRa=zeros(length(lambda),length(SNR));
BER_IOTJ2022=zeros(length(lambda),length(SNR));
tic;
h=waitbar(0,['SF=' num2str(SF) ',\lambda=' num2str(lambda)]);
for j=1:length(lambda)
    for jj=1:length(SNR)
        error_lora=0;
        error_iotj2022=0;
        for jjj=1:times
            [error1,error2]=IOTJ2022(SF,lambda(j),SNR(jj),ui,hi);
            error_lora=error_lora+error2;
            error_iotj2022=error_iotj2022+error1;
        end
        BER_LoRa(j,jj)=error_lora/times/2;
        BER_IOTJ2022(j,jj)=error_iotj2022/times/2;
        waitbar(jj/length(SNR),h,['\lambda=' num2str(lambda) ';SNR=' num2str(SNR(jj))]);
    end
%     waitbar(j/length(lambda),h,['\lambda=' num2str(lambda(j))]);
end
toc;
close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
c =['r';'y';'g';'c';'m'];
figure;
for f=1:length(lambda)
semilogy(SNR,BER_LoRa(f,:),'LineWidth',1,'Color','b','LineStyle','-','Marker',m(f));hold on
semilogy(SNR,BER_IOTJ2022(f,:),'Color',c(f),'LineStyle','-','Marker',m(f));hold on
end
xlabel('SNR');ylabel('BER');
% legend(['\lambda=,DNC'],'\lambda=0.8,IOTJ2022');
legend(['DNC,SF=' num2str(SF) ',ui=' num2str(ui(2)) ',epsilon=' num2str(epsilon)],['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',epsilon=' num2str(epsilon)])
grid on;

%% 
function [error1,error2]=IOTJ2022(SF,lambda,SNR,ui,hi)
M=2^SF;
k=0:M-1;
n=0:8*M-1;
a=randi([0 M-1]);
Nc=7;
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+lambda/M));
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+lambda/M));
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
S=[xk_preamble xk];
% 多径
S_matipath=zeros(1,length(S));
for i=2:length(ui)
    S_temp=[zeros(1,ui(i)) S(1:end-ui(i))];
    S_matipath=S_matipath+hi(i)*S_temp;
end
S=hi(1)*S;
rk=awgn(S,SNR,'measured')+S_matipath;
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
%% 整数部分 循环移位
r_preamble_integer=zeros(1,M);
 for o=1:8
     r_preamble_integer=r_preamble_integer+fft(rk((o-1)*M+1:o*M).*xk0_preamble((o-1)*M+1:o*M).*exp(-1j*2*pi*lambda_CFO*((o-1)*M+1:o*M)/M));
 end
 r_preamble_integer= r_preamble_integer/8;
Yq_preamble_integer=r_preamble_integer;
[~,a_preamble]=max(Yq_preamble_integer);
%% 对payload的处理
r_payload=rk(8*M+1:end);
Y_payload=fft(xk0.*r_payload.*exp(-1j*2*pi*lambda_CFO*k/M));%% dechrip+小数部分补偿+DFT；
Y_payload=[Y_payload(a_preamble:end) Y_payload(1:a_preamble-1)];%% 整数部分循环移位；也可以在dechirp后面做循环移位，再进行DFT。
[~,d]=max(abs(Y_payload/M));
if d-1==a
    error1=0;
else
    error1=1;
end
%% 未补偿DNC
Y_payload_DNC=fft(xk0.*r_payload);
[~,dnc]=max(abs(Y_payload_DNC/M));
if dnc-1==a
    error2=0;
else
    error2=1;
end
% %% 画图
% figure;
% subplot(2,1,2)
% stem(0:M-1,abs(Y_payload/M),'Marker','none');xlabel('q');ylabel('Y_q');xlim([0 M-1]);
% title('2022IOTJ');
% subplot(2,1,1)
% stem(0:M-1,abs(Y_payload_DNC/M),'Marker','none');xlabel('q');ylabel('Y_q');xlim([0 M-1]);ylim([0 1])
% title('DNC')
end





%带频偏的LoRa计算误码率；
BER_MF=zeros(1,length(SNR));
tic;

%% MF 匹配滤波法
h2=waitbar(0,['MF,SF=' num2str(SF) ',fd=' num2str(epsilon) ',SNR=' num2str(SNR(1))]);
for i=1:1:length(SNR)
    error_mf=0;
    error_ibd=0;
   for j=1:1:times
       [errormf]=MF(M,B,fd,SNR(i),ui,hi);
       error_mf=error_mf+errormf;
   end
   BER_MF(i)=error_mf/times/2;
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
function [error1]=MF(M,B,fd,SNR,ui,hi)
aa=randi([0 M-1]);
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];

% 多径
S_matipath=zeros(1,length(Sd));
for i=2:length(ui)
    S_temp=[zeros(1,ui(i)) Sd(1:end-ui(i))];
    S_matipath=S_matipath+hi(i)*S_temp;
end
Sd=hi(1)*Sd;
rk1=awgn(Sd,SNR,'measured');
rk1=rk1+S_matipath;
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:8
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=y_preamble/8;%取平均
y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;

%圆周相关运算
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble.*y_tem);
end
%解调,传统
[~,decision]=max(R);
if ((decision-1) ~= aa)
    error1 = 1;
else
    error1 = 0;
end

end
