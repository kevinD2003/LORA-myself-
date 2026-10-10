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
