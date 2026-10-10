% preamble=[ones(1,64) zeros(1,64) ones(1,32)];
data=[ones(1,64) randi([0 1],1,64) ones(1,32)];
% data_qpsk=pskmod(data,4,pi/4);
preamble=data;
data_delay=[zeros(1,200) data];
result=zeros(1,length(data_delay));
for d=1:length(data_delay)
    if(d+length(preamble)>length(data_delay))
        break;
    end
    data_tmp=data_delay(d+1:d+length(preamble));
    % data_tmp1=data_tmp(1:64);
    % data_tmp2=data_tmp(129:end);
    % data_tmpp=[data_tmp1 zeros(1,64) data_tmp2];
    % % data_tmp=[data_tmp(1:64) zeros(1:64) data_tmp(end-31:end)];
    % result(d+1)=sum(data_tmp.*preamble);
    if(culerror(preamble,data_tmp)) 
        delay=d;
    else
        delay=0;
    end
end

function flag = culerror(preamble,data)
    flag=1;
    for i=1:length(preamble)
        if(preamble(i)~=data(i))
            flag=0;
        end
    end


end