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