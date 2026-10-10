%带频偏的LoRa计算误码率；
B=500e3;
SF=12;
M=2^SF;
SNR=-25:1:-18;
% SNR=-20;
N_error_max=2000;
times=1000000;
fd=0.8*B/M;%多普勒频偏Hz
% fd=0.4*B/M;
BER_Doppler=zeros(1,length(SNR));
BER_LoRa=zeros(1,length(SNR));
BER_MF=zeros(1,length(SNR));
BER_MF_IBD=zeros(1,length(SNR));

%% LoRa
tic;
% h1=waitbar(0,'LoRa,SF=7,fd=0.8*\Deltaf');
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

%% MF 匹配滤波法
h2=waitbar(0,'MF,SF=12,fd=0.8,SNR=-20');
for i=1:1:length(SNR)
    error_mf=0;
    error_ibd=0;
   for j=1:1:times
%        if error_mf<N_error_max||error_ibd<N_error_max
           %        error_mf=error_mf+MF(M,B,fd,SNR(i));
           [errormf,erroribd]=MF(M,B,fd,SNR(i));
           error_mf=error_mf+errormf;
           error_ibd=error_ibd+erroribd;
           N=j;
%            waitbar(i/times);
%        else
%            break;
%        end
   end
   BER_MF(i)=error_mf/N/2;
   BER_MF_IBD(i)=error_ibd/N/2;
   if BER_MF(i)<1E-6&&BER_MF_IBD(i)<1E-6
       break;
   end
   waitbar(i/length(SNR),h2,['SF=12,SNR=' num2str(SNR(i))]);
end
toc;
close(h2);

% %% MF,块内分集
% h3=waitbar(0,'MF-块内分集,SF=7,fd=0.8*\Deltaf');
% for i=1:1:length(SNR)
%     error_mf_ibd=0;
%    for j=1:1:times
%        error_mf_ibd=error_mf_ibd+MFIBDD(M,B,fd,SNR(i));
%    end
%    BER_MF_IBD(i)=error_mf_ibd/times/2;
%    waitbar(i/length(SNR));
% end
% toc;
% close(h3);

%%
figure;
semilogy(SNR,BER_LoRa,'b-o');hold on;
semilogy(SNR,BER_Doppler,'r-*');hold on;
semilogy(SNR,BER_MF,'m-s');hold on;
semilogy(SNR,BER_MF_IBD,'-p','Color',[1 0.5 0]);hold on;

xlabel('SNR(dB)');ylabel('BER');
grid on;
legend('LoRa,f_d=0 ','LoRa,f_d=0.4*\Deltaf','MF,f_d=0.4*\Deltaf','MF-块内分集,f_d=0.4*\Deltaf');
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
function [error1,error2]=MF(M,B,fd,SNR)
aa=randi([0 M-1]);

alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
rk1=awgn(Sd,SNR,'measured');
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

[y_preamble_d,y_payload_d]=IBDD(y_preamble,y_payload,M,3);%块内分集，采用数据块跟着前导码选点的方法。

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
%% 采用块内分集
R_d=zeros(1,M);
for d=1:M
    y_tem=[y_payload_d(d:end) y_payload_d(1:d-1)];
    R_d(d)=sum(y_preamble_d.*y_tem);
end
%解调,传统
[~,decision]=max(R_d);
if ((decision-1) ~= aa)
    error2 = 1;
else
    error2 = 0;
end

end


%% 块内分集，让前导码选点，数据块根据前导码选点。
function [Yq_preamble_D,Yq_payload_D]=IBDD(Yq_preamble,Yq_payload,M,N)
%% 确定前导码最大值位置即最大值左边和最大值右边的位置
[~,decision_preamble]=max(Yq_preamble);
decision_preamble_left=decision_preamble-1;
if decision_preamble_left==0%因为matlab的索引值不为0，考虑为0的情况
    decision_preamble_left=M;
end
decision_preamble_right=mod(decision_preamble+1,M);%右边的点要考虑大于采样点M的情况，所以要用mod
if decision_preamble_right==0%因为matlab的索引值不为0，考虑为0的情况
    decision_preamble_right=M;
end
%% 确定数据块最大值位置及最大值左边和最大值右边的位置
[~,decision_payload]=max(Yq_payload);
decision_payload_left=decision_payload-1;
if decision_payload_left==0%因为matlab的索引值不为0，考虑为0的情况
    decision_payload_left=M;
end
decision_payload_right=mod(decision_payload+1,M);%右边的点要考虑大于采样点M的情况，所以要用mod
if decision_payload_right==0%因为matlab的索引值不为0，考虑为0的情况
    decision_payload_right=M;
end
%% 比较左值与右值的大小
%左值大，选择最大值点与最大值左边的点。此时最大值点decision为右边的点。
if Yq_preamble(decision_preamble_left)>=Yq_preamble(decision_preamble_right)%对前导码判断
    %% 对前导码处理，前导码取最大值位置和最大值左边位置。
    for j=1:N
        DPRL=mod(decision_preamble_left-j,M);
        if DPRL==0%左边的点要考虑索引值为0的情况
            DPRL=M;
        end
        DPR=mod(decision_preamble+j,M);
        if DPR==0%右边的点要考虑索引值为0的情况，因为mod(M,M)=0
            DPR=M;
        end
        Yq_preamble(decision_preamble_left)=Yq_preamble(decision_preamble_left)+Yq_preamble(DPRL);%
        Yq_preamble(DPRL)=0;
        Yq_preamble(decision_preamble)=Yq_preamble(decision_preamble)+Yq_preamble(DPR);%
        Yq_preamble(DPR)=0;
    end
    %% 对数据块处理,前导取最大值位置和最大值左边的位置，数据块也取最大值位置和最大值左边位置。
    for j=1:N
        DPAL=mod(decision_payload_left-j,M);
        if DPAL==0%左边的点要考虑索引值为0的情况
            DPAL=M;
        end
        DPA=mod(decision_payload+j,M);
        if DPA==0%右边的点要考虑索引值为0的情况，因为mod(M,M)=0
            DPA=M;
        end
        Yq_payload(decision_payload_left)=Yq_payload(decision_payload_left)+Yq_payload(DPAL);%
        Yq_payload(DPAL)=0;
        Yq_payload(decision_payload)=Yq_payload(decision_payload)+Yq_payload(DPA);%
        Yq_payload(DPA)=0;
    end
    if Yq_payload(decision_payload)<Yq_payload(decision_payload_left)%% 确保最大值位置对应的分集后仍是最大值
        Yq_payload_tem=Yq_payload(decision_payload);
        Yq_payload(decision_payload)=Yq_payload(decision_payload_left);
        Yq_payload(decision_payload_left)=Yq_payload_tem;
    end
end
%右值大，选择最大值点与最大值右边的点。%此时最大值点decision为左边的点。
if Yq_preamble(decision_preamble_left)<Yq_preamble(decision_preamble_right)%对前导码判断
    %% 对前导码处理，前导码选择最大值位置和最大值右边位置。
    for j=1:N
        DPR=mod(decision_preamble-j,M);
        if DPR==0
            DPR=M;
        end
        DPRR=mod(decision_preamble_right+j,M);%最大值右边位置
        if DPRR==0%右边的点要考虑索引值为0的情况，因为mod(M,M)=0
            DPRR=M;
        end
        Yq_preamble(decision_preamble)=Yq_preamble(decision_preamble)+Yq_preamble(DPR);
        Yq_preamble(DPR)=0;
        Yq_preamble(decision_preamble_right)=Yq_preamble(decision_preamble_right)+Yq_preamble(DPRR);
        Yq_preamble(DPRR)=0;
    end
    %% 对数据块处理，前导码选择最大值位置和最大值右边位置，数据块也选择最大值位置和最大值右边位置
    for j=1:N
        DPA=mod(decision_payload-j,M);
        if DPA==0
            DPA=M;
        end
        DPAR=mod(decision_payload_right+j,M);%最大值右边位置
        if DPAR==0%数据块最大值右边位置，右边的点要考虑索引值为0的情况，因为mod(M,M)=0
            DPAR=M;
        end
        Yq_payload(decision_payload)=Yq_payload(decision_payload)+Yq_payload(DPA);
        Yq_payload(DPA)=0;
        Yq_payload(decision_payload_right)=Yq_payload(decision_payload_right)+Yq_payload(DPAR);
        Yq_payload(DPAR)=0;
    end
    if Yq_payload(decision_payload)<Yq_payload(decision_payload_right)%保证最大值点做完分集后仍然是最大值
        Yq_payload_tem=Yq_payload(decision_payload);
        Yq_payload(decision_payload)=Yq_payload(decision_payload_right);
        Yq_payload(decision_payload_right)=Yq_payload_tem;
    end
end
Yq_preamble_D=Yq_preamble;
Yq_payload_D=Yq_payload;
end




%% 块内分集，用于抬高能量。考虑0.5倍的情况。
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

%% 块内分集，采用导数法进行选点。
%Yq是非相干解调后的Yq；M是Yq的长度；N是块内采样点数的一半，即左边和右边需要累加的个数；
function Yq_D=DIBD(Yq,M,N)
[~,decision]=max(Yq);
decision_left=decision-1;
if decision_left==0%因为matlab的索引值不为0，考虑为0的情况
    decision_left=M;
end
decision_right=mod(decision+1,M);%右边的点要考虑大于采样点M的情况，所以要用mod
if decision_right==0%因为matlab的索引值不为0，考虑为0的情况
    decision_right=M;
end

%% 导数法
Yq_tem1=decision*Yq(decision)^2;
Yq_tem2=Yq(decision)^2;
for i=1:N
    dl=mod(decision-i,M);
    if dl==0
        dl=M;
    end
    dr=mod(decision+i,M);
    if dr==0
        dr=M;
    end
    Yq_tem1=Yq_tem1+dl*Yq(dl)^2+dr*Yq(dr)^2;
    Yq_tem2=Yq_tem2+Yq(dl)^2+Yq(dr)^2;
end
a_tem=Yq_tem1/Yq_tem2;

%% 比较导数法算出来的a与最大值位置的大小
if a_tem<decision%根据导数法选择最大值位置左邻点
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

if a_tem>decision%根据导数法选择最大值位置的右邻点
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

if a_tem==decision%导数法选择失效
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
end
Yq_D=Yq;
end
