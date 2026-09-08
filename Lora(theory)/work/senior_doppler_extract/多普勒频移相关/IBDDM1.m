%% 块内分集；不需要区分0.5，0.6的情况，选两径,然后两径叠加选变成一径
%preamble是前导码；payload是数据块；M是2^SF；
function [Yq_preamble_D,Yq_payload_D]=IBDDM(Yq_preamble,Yq_payload,M,N)

%% 先选前导码
[~,decision_preamble]=max(Yq_preamble);
decision_left_preamble=decision_preamble-1;
if decision_left_preamble==0
    decision_left_preamble=M;
end
decision_right_preamble=mod(decision_preamble+1,M);
if decision_right_preamble==0
    decision_right_preamble=M;
end
%% 前导码最大值左邻点大；即选择最大值点和最大值左邻点
if Yq_preamble(decision_left_preamble)>=Yq_preamble(decision_right_preamble)
    right_preamble=1;%选择了左邻点表示最大值点位置是在右边。
    for j=1:1:N
        %% 对前导码左邻点操作
        DLPR=mod(decision_left_preamble-j,M);
        if DLPR==0
           DLPR=M; 
        end
        Yq_preamble(decision_left_preamble)=Yq_preamble(decision_left_preamble)+Yq_preamble(DLPR);
        Yq_preamble(DLPR)=0;
        %% 对前导码最大值点操作
        DPR=mod(decision_preamble+j,M);
        if DPR==0
           DPR=M; 
        end
        Yq_preamble(decision_preamble)=Yq_preamble(decision_preamble)+Yq_preamble(DPR);
        Yq_preamble(DPR)=0;
    end
end

%% 前导码最大值右邻点大；即选择最大值点和最大值右邻点
if Yq_preamble(decision_right_preamble)>Yq_preamble(decision_left_preamble)
    left_preamble=1;%选择最大值右邻点,表示最大值点是左边。
    for j=1:1:N
        %% 对前导码右邻点操作
        DRPR=mod(decision_right_preamble+j,M);
        if DRPR==0
           DRPR=M; 
        end
        Yq_preamble(decision_right_preamble)=Yq_preamble(decision_right_preamble)+Yq_preamble(DRPR);
        Yq_preamble(DRPR)=0;
        %% 对前导码最大值点操作
        DPR=mod(decision_preamble-j,M);
        if DPR==0
           DPR=M; 
        end
        Yq_preamble(decision_preamble)=Yq_preamble(decision_preamble)+Yq_preamble(DPR);
        Yq_preamble(DPR)=0;
    end
end


%% 选数据块
[~,decision_payload]=max(Yq_payload);
decision_left_payload=decision_payload-1;
if decision_left_payload==0
    decision_left_payload=M;
end
decision_right_payload=mod(decision_payload+1,M);
if decision_right_payload==0
    decision_right_payload=M;
end
%% 数据块最大值左邻点大；即选择最大值点和最大值左邻点
if Yq_payload(decision_left_payload)>=Yq_payload(decision_right_payload)
    right_payload=1;%选择了左邻点表示最大值点位置是在右边。
    for j=1:1:N
        %% 对数据块左邻点操作
        DLPA=mod(decision_left_payload-j,M);
        if DLPA==0
           DLPA=M; 
        end
        Yq_payload(decision_left_payload)=Yq_payload(decision_left_payload)+Yq_payload(DLPA);
        Yq_payload(DLPA)=0;
        %% 对前导码最大值点操作
        DPA=mod(decision_payload+j,M);
        if DPA==0
           DPA=M; 
        end
        Yq_payload(decision_payload)=Yq_payload(decision_payload)+Yq_payload(DPA);
        Yq_payload(DPA)=0;
    end
end

%% 数据块最大值右邻点大；即选择最大值点和最大值右邻点
if Yq_payload(decision_right_payload)>Yq_payload(decision_left_payload)
    left_payload=1;%选择最大值右邻点,表示最大值点是左边。
    for j=1:1:N
        %% 对前导码右邻点操作
        DRPA=mod(decision_right_payload+j,M);
        if DRPA==0
           DRPA=M; 
        end
        Yq_payload(decision_right_payload)=Yq_payload(decision_right_payload)+Yq_payload(DRPA);
        Yq_payload(DRPA)=0;
        %% 对前导码最大值点操作
        DPA=mod(decision_payload-j,M);
        if DPA==0
           DPA=M; 
        end
        Yq_payload(decision_payload)=Yq_payload(decision_payload)+Yq_payload(DPA);
        Yq_payload(DPA)=0;
    end
end
%% 查看最大值位置是否失配
if left_preamble==1%前导码最大值位置是左边
    Yq_preamble(decision_preamble)=Yq_preamble(decision_right_preamble)+Yq_preamble(decision_preamble);
    Yq_preamble(decision_right_preamble)=0;
   if right_payload==1%数据块最大值位置是右边
      Yq_payload(decision_left_payload)=Yq_payload(decision_left_payload)+Yq_payload(decision_payload);
      Yq_payload(decision_payload)=0;
   else%数据块最大值位置也在左边
       Yq_payload(decision_payload)=Yq_payload(decision_right_payload)+Yq_payload(decision_payload);
       Yq_payload(decision_right_payload)=0;
   end
end
if right_preamble==1%前导码最大值位置在右边
    Yq_preamble(decision_preamble)=Yq_preamble(decision_left_preamble)+Yq_preamble(decision_preamble);
    Yq_preamble(decision_left_preamble)=0;
   if left_payload==1%数据块最大值位置在左边
      Yq_payload(decision_left_payload)=Yq_payload(decision_right_payload);
      Yq_payload(decision_right_payload)=0; 
   else%数据块最大值位置也在右边
       Yq_payload(decision_payload)=Yq_payload(decision_left_payload)+Yq_payload(decision_payload);
       Yq_payload(decision_left_payload)=0;
   end
end
Yq_preamble_D=Yq_preamble;
Yq_payload_D=Yq_payload;
end