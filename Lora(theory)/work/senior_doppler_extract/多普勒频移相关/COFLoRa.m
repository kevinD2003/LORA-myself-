%带频偏的LoRa计算；
B=125e3;
SF=7;
M=2^SF;
%f=rand(1,1)
fd=0.5*B/M;
% fd=1000;
% aa=randi([0 M-1],1,1);
% aa=randi([0 M-1]);
% aa=M/2;
% aa=124;
% aa=M-1;
k=0:1:M-1;  
error=0;e=0;
for j=1:1
    
    for i=1:1
        aa=100;
        xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));%多普勒频偏下的LoRa
        yk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));
%         SNR=-7;
        rk=awgn(xk,SNR,'measured');
%         rk=xk;
SNR=-5;
xk=awgn(xk,SNR,'measured');
yk=awgn(yk,SNR,'measured');
        %解调,传统
        xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
        Yq=fft(rk.*xk0)/M;
        Yq=(abs(Yq));%非相干解调
%         E1=sum(abs(fft(xk.*xk0/M).^2))
        E2=sum(abs(fft(yk.*xk0/M).^2))
%         figure;plot(Yq)
%         [~,decision]=max(Yq);
%         if (decision-1)~=aa+1
%             error=error+1;
%         end
% figure;plot(0:M-1,Yq);
%         Ye=zeros(1,M);
%         for iii=1:M
%             Ye(iii)=Yq(iii)^2;
%             for iiii=1:3
%                 dl=mod(iii-iiii,M);
%                 if dl==0
%                     dl=M;
%                 end
%                 dr=mod(iii+iiii,M);
%                 if dr==0
%                     dr=M;
%                 end
%             Ye(iii)=Ye(iii)+Yq(dl)^2+Yq(dr)^2;
%             end
%         end
% %         figure;plot(Ye);
%         [~,decision]=max(Ye);
%         %%导数法
%         Yq1=decision*Yq(decision)^2;
%         Yq2=Yq(decision)^2;
%         for ii=1:3
%             dl=mod(decision-ii,M);
%                 if dl==0
%                     dl=M;
%                 end
%                 dr=mod(decision+ii,M);
%                 if dr==0
%                     dr=M;
%                 end
%             Yq1=Yq1+(dl)*Yq(dl)^2+(dr)*Yq(dr)^2;
%             Yq2=Yq2+Yq(dl)^2+Yq(dr)^2;
%         end
%         a_a=Yq1/Yq2-1;
%         if a_a<64||a_a>65
%             e=e+1;
%             if e==1
% %                 figure;plot(Ye);
% %                 figure;plot(Yq);
%             end
%         end
        
        %     Yq1=0;
        %     Yq2=0;
        %     for ii=1:M
        %         Yq1=Yq1+ii*Yq(ii)^2;
        %         Yq2=Yq2+Yq(ii)^2;
        %     end
        %     a_a=Yq1/Yq2-1
    end
end

% figure;plot(0:M-1,Yq_left);title('Yq left');ylim([0 1]);xlim([0 M]);
% figure;plot(0:M-1,Yq_right);title('Yq right');ylim([0 1]);xlim([0 M]);
% figure;plot(0:M-1,Yq_left+Yq_right);title('Yq_left+Yq_right');xlim([0 M]);%ylim([0 1]);
% figure;
% % subplot(2,1,1);
% plot(0:M-1,Yq,'r-');title('B=125KHz,SF=7,符号a=0,f_d=0.5×\Deltaf');xlabel('q');ylabel('X_q_d');ylim([0 1]);xlim([0 M-1]);hold on;
% figure;plot(0:M-1,abs(Yq-Yq_t));title('xiugai');
% 
% 
% [~,decision]=max(Yq);
% aancoh=decision-1;
%     if ((decision-1) ~= aa)
%         aaerror = 1;
%     else
%         aaerror = 0;
%     end
% Yqy=fft(yk.*xk0)/M;
% Yqy=abs(Yqy);
% % figure;plot(0:M-1,Yqy,'b-');title('B=125KHz,SF=7,前导符号a=0');ylabel('X_q');xlabel('q');ylim([0 1]);xlim([0 M-1]);
% 
% %%
% 能量集中算法
[~,decision]=max(Yq);
if Yq(decision-1)>=Yq(decision+1)
    for j=1:3
        Yq(decision-1)=Yq(decision-1)+Yq(decision-1-j);
        Yq(decision-1-j)=0;
        Yq(decision)=Yq(decision)+Yq(decision+j);
        Yq(decision+j)=0;
    end
end
if Yq(decision-1)<Yq(decision+1)
    for j=1:3
        Yq(decision)=Yq(decision)+Yq(decision-j);
        Yq(decision-j)=0;
        Yq(decision+1)=Yq(decision+1)+Yq(decision+1+j);
        Yq(decision+1+j)=0;
    end
end
figure;f1=stem(0:M-1,Yq,'Marker','none');hold on;
% % subplot(2,1,2);plot(0:M-1,Yq,'b-');ylabel('X_q_d');xlabel('q');xlim([0 M-1]);
% %% 块内分集
% N=3;
% 
% [~,decision]=max(Yq);
% decision_left=decision-1;
% if decision_left==0%因为matlab的索引值不为0，考虑为0的情况
%     decision_left=M;
% end
% decision_right=mod(decision+1,M);%右边的点要考虑大于采样点M的情况，所以要用mod
% if decision_right==0%因为matlab的索引值不为0，考虑为0的情况
%     decision_right=M;
% end
% %% 比较左值与右值的大小
% %左值大，选择最大值点与最大值左边的点。此时最大值点decision为右边的点。
% if Yq(decision_left)>=Yq(decision_right)
%     for j=1:N
%         DL=mod(decision_left-j,M);
%         if DL==0%左边的点要考虑索引值为0的情况
%             DL=M;
%         end
%         D=mod(decision+j,M);
%         if D==0%右边的点要考虑索引值为0的情况，因为mod(M,M)=0
%             D=M;
%         end
%         Yq(decision_left)=Yq(decision_left)+Yq(DL);%
%         Yq(DL)=0;
%         Yq(decision)=Yq(decision)+Yq(D);%
%         Yq(D)=0;
%     end
% end
% %右值大，选择最大值点与最大值右边的点。%此时最大值点decision为左边的点。
% if Yq(decision_left)<Yq(decision_right)
%     for j=1:N
%         D=mod(decision-j,M);
%         if D==0
%             D=M;
%         end
%         DR=mod(decision_right+j,M);
%         if DR==0%右边的点要考虑索引值为0的情况，因为mod(M,M)=0
%             DR=M;
%         end
%         Yq(decision)=Yq(decision)+Yq(D);
%         Yq(D)=0;
%         Yq(decision_right)=Yq(decision_right)+Yq(DR);
%         Yq(DR)=0;
%     end
% end
%     Yq_D=Yq;
% %     subplot(2,1,2);plot(0:M-1,Yq,'b-');ylabel('X_q_d');xlabel('q');xlim([0 M-1]);
% %%
% 
% 
% 
% 
% 
% 
% % q=0:M-1;
% % Xq=abs(sin(pi*(q-aa-M*fd/B))./sin(pi*(q-aa-M*fd/B)/M))/M;
% % plot(0:M-1,Xq,'k--');legend('simu','approx')
% 
% 
% %%
% % figure;
% % semilogy(SNR,BER,'-or');
% % xlabel('SNR(dB)','FontName','Times New Roman','FontSize',12);
% % ylabel('Probability of Bit Error $P_b$','FontName','Times New Roman','Interpreter','latex','FontSize',12);grid on;
% % legend(['$L=' num2str(L) ',ncoh,Simu$'],'FontName','Times New Roman','Interpreter','latex','FontSize',8);
% % xlim([-15 15]);
% 
