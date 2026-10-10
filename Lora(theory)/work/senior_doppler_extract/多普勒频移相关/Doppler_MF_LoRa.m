%% 画图用
%带频偏的LoRa计算；
B=125e3;
SF=7;
M=2^SF;
fd=0.1*B/M;
aa=M/2;
k=0:1:M-1;  
error_reshape=0;
error=0;
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));%多普勒频偏下的LoRa
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
SNR=-7;
% rk=awgn(xk,SNR,'measured');
rk=xk;
%解调,传统
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
Yq=fft(rk.*xk0)/M;
Yq=abs(Yq);%非相干解调
y_payload=Yq;
y_preamble=abs(fft(xk_preamble.*xk0)/M);
% 匹配滤波
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble.*y_tem);
end

% figure;
stem(0:M-1,y_payload,'Marker','none','LineStyle','-','LineWidth',0.5,'Color','r');xlabel('q');ylabel('Xq');xlim([0 M-1]);hold on
% stem(0:M-1,y_payload,'Marker','none','LineWidth',1);xlabel('q');ylabel('Xq');xlim([0 M-1]);hold on
% I=y_payload;
% I(aa+1)=0;
% stem(0:M-1,I,'Marker','none','LineWidth',1,'Color','r');
% title('SF=7,符号a=64，f_d=0');
%% 匹配滤波画图
% figure;
% subplot(1,3,1);stem(0:M-1,y_payload,'Marker','none');xlabel('q');ylabel('X_q');title('数据块');xlim([0 M-1]);ylim([0 1]);
% subplot(1,3,2);stem(0:M-1,y_preamble,'Marker','none');xlabel('q');ylabel('X_q');title('前导码');xlim([0 M-1]);ylim([0 1]);
% subplot(1,3,3);stem(0:M-1,R,'Marker','none');xlabel('d');ylabel('R');title('匹配滤波');xlim([0 M-1]);ylim([0 1]);

%% 采用块内分集
% y_payload_d=IBD(y_payload,M,3);
y_payload_d=y_payload;
y_preamble_d=IBD(y_preamble,M,3);
R_d=zeros(1,M);
for d=1:M
    y_tem=[y_payload_d(d:end) y_payload_d(1:d-1)];
    R_d(d)=sum(y_preamble_d.*y_tem);
end
%% 匹配滤波+块内分集画图
% figure;
% subplot(1,3,1);stem(0:M-1,y_payload_d,'Marker','none');xlabel('q');ylabel('X_q');title('数据块,块内分集');xlim([0 M-1]);%ylim([0 1]);
% subplot(1,3,2);stem(0:M-1,y_preamble_d,'Marker','none');xlabel('q');ylabel('X_q');title('前导码，块内分集');xlim([0 M-1]);%ylim([0 1]);
% subplot(1,3,3);stem(0:M-1,R_d,'Marker','none');xlabel('d');ylabel('R');title('匹配滤波');xlim([0 M-1]);%ylim([0 1]);
% % text(64,2.4,'(64,2.32872)','HorizontalAlignment','center');text(63,1.25,'(63,1.18490)','HorizontalAlignment','right');text(65,1.25,'(65,1.18490)');




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