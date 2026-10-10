%% Aq-D(q)
B=500e3;
SF=7:12;
epsilon=0:0.05:1;
Aq_D=zeros(length(SF),length(epsilon));
for i=1:length(SF)
    M=2^SF(i);
    a=M/2;
    for ii=1:length(epsilon)
        if mod(epsilon(ii),1)==0
            if epsilon(ii)==0
                Aq=M;
            else
                Aq=0;
            end
        else
            Aq=abs(sin(pi*epsilon(ii))/sin(pi*epsilon(ii)/M));
        end
        D=zeros(1,M);
        for q=0:1:M-1
            D(q+1)=abs(sin(pi*(q-a-epsilon(ii)))/sin(pi*(q-a-epsilon(ii))/M));
        end
        if mod(epsilon(ii),1)==0
            if abs(epsilon(ii))>0
                D(a+epsilon(ii)+1)=M;
            end
        end
        D(a+1)=0;
        D_sort=sort(D,'descend');
        Aq_D(i,ii)=(Aq-D_sort(1))/M;
    end
end

%% 
SF=7:12;
% M=2^SF;
B=500e3;
epsilon=0:0.05:1;
SNR=-15;
BER=zeros(length(SF),length(epsilon));
times=1000000;
% times=100;
tic;
h=waitbar(0,'SF=7,waiting....');
for t=1:length(SF)
    M=2^SF(t);
    for j=1:length(epsilon)
        error=0;
        for jj=1:1:times
            aa=randi([0 M-1]);
            error=error+Nerror(M,B,epsilon(j),SNR,aa);
        end
        BER(t,j)=error/2/times;
        waitbar(t/length(SF),h,['SF=',num2str(SF(t)),',\epsilon=',num2str(epsilon(j))]);
%         waitbar(j/length(epsilon),h,['SF=10,\epsilon=' num2str(epsilon(j))]);
    end
%     waitbar(t/length(SF),h,['SF=',num2str(SF(t))]);
    
end
close(h);
toc;

%%
figure;
yyaxis left
% figure;
c=['r';'g';'y';'c';'m';'b'];
m=['o';'x';'d';'+';'s';'v'];
for f=1:length(SF)
    plot(epsilon,Aq_D(f,:),'LineStyle',':','Color','r','Marker',m(f),'LineWidth',1.5);hold on;
end
% hold off;
legend('SF=7', 'SF=8','SF=9','SF=10','SF=11','SF=12');
% ah=axes('position',get(gca,'position'),'visible','off');
xlabel(char(949));ylabel('A_a-D_q_m_a_x');
% char(949)是epsilon;
% grid on;
hold off;
% ah=axes('position',get(gca,'position'),'visible','off');
%%
 figure;
% yyaxis right
for f=1:length(SF)
    semilogy(epsilon,BER(f,:),'LineStyle','-','Color',c(f),'Marker',m(f),'LineWidth',1.5);hold on
%     plot(epsilon,Aq_D(f,:),'LineStyle','-','Color',c(f),'Marker',m(f),'LineWidth',1.5);hold on;
end
ylabel('BER(SNR=-15dB)');
ylim([10^-6 1])
grid on
legend('SF=7','SF=8','SF=9','SF=10','SF=11','SF=12',...
    'SF=7','SF=8','SF=9','SF=10','SF=11','SF=12');
hold off
% legend off;
% legend('SF=7','SF=8','SF=9','SF=10','SF=11','SF=12',...
%     ['SF=7,\Gamma=',num2str(SNR),'dB'],['SF=8,\Gamma=',num2str(SNR),'dB'],['SF=9,\Gamma=',num2str(SNR),'dB'],['SF=10,\Gamma=',num2str(SNR),'dB'],['SF=11,\Gamma=',num2str(SNR),'dB'],['SF=12,\Gamma=',num2str(SNR),'dB']);
%    'SF=10,simu,SNR=-15dB','SF=10,Approx,SNR=-15dB' );
% legend();
% ah2=axes('position',get(gca,'position'),'visible','off');

%%
function [aaerror]=Nerror(M,B,epsilon,SNR,aa)
k=0:1:M-1; 
f=epsilon*B/M;
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


