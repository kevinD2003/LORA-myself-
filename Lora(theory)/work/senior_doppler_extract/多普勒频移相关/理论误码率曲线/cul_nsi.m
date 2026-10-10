%% 计算干扰集内元素个数；
B=500e3;
SF=7:12;%扩展因子
SNR=-25:1:-5;
nsi=zeros(length(SF),length(SNR));%%%%%%%%%%%%%%%%%%%计算干扰集内元素个数；
for j=1:length(SF)
    M=2^SF(j);
    delta_f=B/M;
    % fd=0.4*B/M;
    fd=97.6;
    epsilon=fd/delta_f;
    if mod(epsilon,1)==0
        if abs(epsilon)<1
            Aq=M;
        else
            Aq=0;
        end
    else
        Aq=abs(sin(pi*epsilon)/sin(pi*epsilon/M));
    end
    Aq_ncoh=getAq(SF(j),epsilon);
    A=Aq_ncoh;
    Aq_ncoh=sort(Aq_ncoh,'descend');
    % H=harmonic(M-2);%调和数
    for i=1:1:length(SNR)
        SNR_dB=10^(SNR(i)/10);
        N_SI=getN(SF(j),Aq_ncoh,SNR_dB);%%%%%%%%%%%计算干扰集内元素个数
        nsi(j,i)=N_SI;%%%%%%%%%%%%%%%%%%%%%%%
    end
end
figure;
c=['b';'g';'r';'c';'m';'y'];
m=['o';'x';'d';'+';'s';'v'];
for f=1:length(SF)
    stem(SNR,nsi(f,:),'LineStyle','-','Color',c(f),'Marker',m(f));hold on;
end
legend('SF=7','SF=8','SF=9','SF=10','SF=11','SF=12');
%%
function [Aq_ncoh]=getAq(SF,epsilon)
%获得理论叠加的多径在解调域上形成的幅值
M=2^SF;
aa=M/2;
Aq_ncoh=zeros(1,M);
% q=0:1:M-1;
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
