%带频偏的LoRa计算误码率；
%找错误；
B=125e3;
SF=7;
M=2^SF;
SNR=-5;
times=10;
fd=0.8*B/M;%多普勒频偏Hz
BER_Doppler=zeros(1,length(SNR));
BER_LoRa=zeros(1,length(SNR));
BER_MF=zeros(1,length(SNR));
BER_MF_IBD=zeros(1,length(SNR));

% %% LoRa
% tic;
% h1=waitbar(0,'LoRa,SF=7,fd=0.5*\Deltaf');
% for i=1:1:length(SNR)
%     error=0;
%     errorL=0;
%    for j=1:1:times
%        [error1,error2]=Nerror(M,B,fd,SNR(i));
%        error=error+error1;
%        errorL=errorL+error2;
%    end
%    BER_Doppler(i)=error/times/2;
%    BER_LoRa(i)=errorL/times/2;
%    waitbar(i/length(SNR));
% end
% toc;
% close(h1);

% %% MF
% h2=waitbar(0,'MF,SF=7,fd=0.5*\Deltaf');
% for i=1:1:length(SNR)
%     error_mf=0;
%    for j=1:1:times
%        error_mf=error_mf+MF(M,B,fd,SNR(i));
%    end
%    BER_MF(i)=error_mf/times/2;
%    waitbar(i/length(SNR));
% end
% toc;
% close(h2);

%% MF,块内分集
h3=waitbar(0,'MF-块内分集,SF=7,fd=0.5*\Deltaf');
for i=1:1:length(SNR)
    error_mf_ibd=0;
   for j=1:1:times
       error_mf_ibd=error_mf_ibd+MFIBD(M,B,fd,SNR(i));
   end
   BER_MF_IBD(i)=error_mf_ibd/times/2;
   waitbar(i/length(SNR));
end
toc;
close(h3);

%%
figure;
semilogy(SNR,BER_LoRa,'b-o');hold on;
semilogy(SNR,BER_Doppler,'r-*');hold on;
semilogy(SNR,BER_MF,'m-s');hold on;
semilogy(SNR,BER_MF_IBD,'-p','Color',[1 0.5 0]);hold on;

xlabel('SNR(dB)');ylabel('BER');
grid on;
legend('LoRa,f_d=0 ','LoRa,f_d=0.5*\Deltaf','MF,f_d=0.5*\Deltaf','MF1,f_d=0.5*\Deltaf');
%xlim([-20 -4])
% title('B=125KHz,SF=7,\Deltaf=B/M=976.5625Hz');

%% LoRa调制解调；受到多普勒频偏影响的LoRa调制解调。
function [aaerror,aaerrorL]=Nerror(M,B,fd,SNR)
aa=randi([0 M-1]);
k=0:1:M-1;  
xk_Doppler=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));%受到多普勒频偏影响的LoRa信号
xk_LoRa=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));%不受多普勒频移
rk1=awgn(xk_Doppler,SNR,'measured');
rk2=awgn(xk_LoRa,SNR,'measured');
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
    YqL=fft(rk2.*xk0)/M;
    YqL=abs(YqL);%非相干解调
    [~,decisionL]=max(YqL);
    if ((decisionL-1) ~= aa)
        aaerrorL = 1;
    else
        aaerrorL = 0;
    end
end


%% MF算法
function error=MF(M,B,fd,SNR)
aa=randi([0 M-1]);

alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk];
rk1=awgn(Sd,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:1
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
% y_preamble=y_preamble/1;
y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;
%圆周相关运算
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble_tem.*y_tem);
end
%解调,传统
[~,decision]=max(R);
if ((decision-1) ~= aa)
    error = 1;
else
    error = 0;
end
end

%% MFIBD
function error=MFIBD(M,B,fd,SNR)
aa=randi([0 M-1]);
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk];
rk1=awgn(Sd,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:1
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    ypp=y_preamble_tem;
    y_preamble_tem=IBD(y_preamble_tem,M,3);
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
% y_preamble=y_preamble/1;

y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;
ypa=y_payload;
y_payload=IBD(y_payload,M,3);
%圆周相关运算
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble.*y_tem);
end
%解调,传统
[~,decision]=max(R);
if ((decision-1) ~= aa)
    error = 1;
    aa
    figure;plot(0:M-1,ypp);title('preamble,没有分集');
    figure;plot(0:M-1,ypa);title('payload，没有分集');
    figure;plot(0:M-1,y_preamble);title('preamble');
    figure;plot(0:M-1,y_payload);title('payload');
    figure;plot(0:M-1,R);title('R');
else
    error = 0;
end
end

%% 块内分集，用于抬高能量。
%Yq是非相干解调后的Yq；M是Yq的长度；N是块内采样点数的一半，即左边和右边需要累加的个数；
function Yq_D=IBD(Yq,M,N)
[~,decision]=max(Yq);
decision_left=decision-1;
if decision_left==0%因为matlab的索引值不为0，考虑为0的情况
    decision_left=M;
end
decision_right=mod(decision+1,M);%右边的点要考虑大于采样点M的情况，所以要用mod
if decision_right==0%因为matlab的索引值不为0，考虑为0的情况
    decision_right=M;
end
%% 比较左值与右值的大小
%左值大，选择最大值点与最大值左边的点。此时最大值点decision为右边的点。
if Yq(decision_left)>=Yq(decision_right)
    for j=1:N
        DL=mod(decision_left-j,M);
        if DL==0%左边的点要考虑索引值为0的情况
            DL=M;
        end
        D=mod(decision+j,M);
        if D==0%右边的点要考虑索引值为0的情况，因为mod(M,M)=0
            D=M;
        end
        Yq(decision_left)=Yq(decision_left)+Yq(DL);%
        Yq(DL)=0;
        Yq(decision)=Yq(decision)+Yq(D);%
        Yq(D)=0;
    end
end
%右值大，选择最大值点与最大值右边的点。%此时最大值点decision为左边的点。
if Yq(decision_left)<Yq(decision_right)
    for j=1:N
        D=mod(decision-j,M);
        if D==0
            D=M;
        end
        DR=mod(decision_right+j,M);
        if DR==0%右边的点要考虑索引值为0的情况，因为mod(M,M)=0
            DR=M;
        end
        Yq(decision)=Yq(decision)+Yq(D);
        Yq(D)=0;
        Yq(decision_right)=Yq(decision_right)+Yq(DR);
        Yq(DR)=0;
    end
end
Yq_D=Yq;
end