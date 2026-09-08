%% 块内分集+形成单径或者多径选择
function [Yq_preamble_D,Yq_payload_D]=IBDSP(Yq_preamble,Yq_payload,M,N)
[~,decision_preamble]=max(Yq_preamble);
[~,decision_payload]=max(Yq_payload);

for j=1:N
    %% 前导符号处理
    decision_left_preamble=mod(decision_preamble-j,M);
    if decision_left_preamble==0
        decision_left_preamble=M;
    end
    Yq_preamble(decision_preamble)= Yq_preamble(decision_preamble)+Yq_preamble(decision_left_preamble);
    decision_right_preamble=mod(decision_preamble+j,M);
    if decision_right_preamble==0
        decision_right_preamble=M;
    end
    Yq_preamble(decision_preamble)= Yq_preamble(decision_preamble)+Yq_preamble(decision_right_preamble);
    
    %% 对数据块处理
    decision_left_payload=mod(decision_payload-j,M);
    if decision_left_payload==0
        decision_left_payload=M;
    end
    Yq_payload(decision_payload)= Yq_payload(decision_payload)+Yq_payload(decision_left_payload);
    decision_right_payload=mod(decision_payload+j,M);
    if decision_right_payload==0
        decision_right_payload=M;
    end
    Yq_payload(decision_payload)= Yq_payload(decision_payload)+Yq_payload(decision_right_payload);
end
Yq_preamble_D=Yq_preamble;
Yq_payload_D=Yq_payload;
end