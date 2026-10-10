%% Aq-D(q)
B=125e3;
SF=7:12;
epsilon=0:0.1:1;
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
        Aq_D(i,ii)=(Aq-D_sort(1));
    end
end
figure;
c=['b';'g';'y';'c';'m';'r'];
m=['o';'x';'d';'+';'s';'v'];
for f=1:length(SF)
    plot(epsilon,Aq_D(f,:),'Color',c(f),'Marker',m(f));hold on;
end
legend('SF=7',...
    'SF=8','SF=9','SF=10','SF=11','SF=12');
xlabel('epsilon');ylabel('(A_q-D_q_m_a_x)');


