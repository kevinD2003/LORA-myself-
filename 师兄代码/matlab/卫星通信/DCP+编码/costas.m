clc;

close all;

clear all;

addpath 'func\'





datestr(now)

len = 10000;              %符号数

Freq_Data = 8e6;         %符号速率

nsamp = 4;               %采样倍数

Freq_Sample = Freq_Data * nsamp;   %采样频率

Freq_Carr = 8e6;         %载波频率

FC_NCO = 8e6;            %本地NCO频率

Ts = 1 / Freq_Sample;    %采样周期

T = nsamp * Ts;          %符号周期

alpha = 0.5;             %根升余弦滤波器系数

delay = 2;               %根升余弦滤波器系数

err = 1e-3;              %信号加载的时偏



% err = 0;              %信号加载的时偏





sl = 3000;               %sl>finish2，进入Gardner环的有效的数据起点

sp = floor(len - 20 - len * err / 4); %进入Gardner环的有效的数据终点

wc = Freq_Carr * 2 * pi; 

wc_nco = FC_NCO * 2 * pi;





Delta_Freq = - Freq_Carr/200;         %频偏 





%Delta_Freq = -800;      %频偏 



 

%得到QPSK调制两路信号

 [I_Data,Q_Data] = QPSK_mod(len);

 

 %I路同步头

 start1 = 2501;

 finish1 = 2600;

 comps1 = start1 * nsamp - 11;

 compf1 = finish1 * nsamp - 8;

 I_Data(start1:finish1) = 1;

 %Q路同步头

 start2 = 2701;

 finish2 = 2800;

 comps2 = start2 * nsamp - 11;

 compf2 = finish2 * nsamp - 8;

 Q_Data(start2:finish2) = 1;

 

 %经过根升余弦滤波器

 I_D = u_rrcsend(I_Data,len,nsamp,err,Ts);

 Q_D = u_rrcsend(Q_Data,len,nsamp,err,Ts);

 

 carlen = length(I_D)/nsamp  %经过根升余弦滤波器后的符号数（去除了周期迭代后的一些无效符号）

 %载波信号

 Delta_Phase=rand(1)*2*pi;   %随机初始相位

 %Delta_Phase = 0;

 I_Carrier=cos((wc+Delta_Freq)/Freq_Sample*(1:carlen*nsamp)+Delta_Phase);  %I路载波

 Q_Carrier=-sin((wc+Delta_Freq)/Freq_Sample*(1:carlen*nsamp)+Delta_Phase); %Q路载波

 %调制

 I_MOD = I_D.*I_Carrier;

 Q_MOD = Q_D.*Q_Carrier;

 %发送信号

 send = I_MOD + Q_MOD;

 

plot(abs(fft(send,256)));

 

 

 %统计参数预设

 ratio = zeros(1,2);%用于统计误码率

 tp = 1;%用于计数

 dataI = I_Data(5:len-5);%用于统计的I路信号

 dataQ = Q_Data(5:len-5);%用于统计的Q路信号

 

 %for SNR_DB = 4:5

     SNR_DB = 4

     rece = awgn(send,SNR_DB,'measured');  %接受端的信号，加载指定的snr

     %rece = send;

     %锁相环参数预设

     Discriminator_Out=zeros(carlen * nsamp,1);

     Freq_Control=zeros(carlen * nsamp,1);

     PLL_Phase_Part=zeros(carlen * nsamp,1);   %锁相环频率

     PLL_Freq_Part=zeros(carlen * nsamp,1);    %锁相环相位

     WC_frame = zeros(1,carlen * nsamp);       

     NCO_Phase = 0;



     mul = 2;%按块进入根升余弦滤波器

     for i = 1 + mul:carlen - mul

         %为加快收敛，前端使用较大的系数以快速震荡

         if i < 1000

                C1 = 0.007;

                C2 = C1 * 0.007;

         else

                C1 = 0.0005;

                C2 = C1 * 0.001;

         end

         %频率锁相环

         for k = 1 : nsamp

            I_NCO = cos(wc_nco/Freq_Sample*((i-1-mul)*nsamp+1 : (i-1+mul)*nsamp+nsamp)+mod(NCO_Phase,2*pi));%NCO产生的I路输入信息数据

            Q_NCO = - sin(wc_nco/Freq_Sample*((i-1-mul)*nsamp+1 : (i-1+mul)*nsamp+nsamp)+mod(NCO_Phase,2*pi));%NCO产生的Q路输入信息数据 

            I_RECE=rece((i-1-mul)*nsamp+1 : (i-1+mul)*nsamp+nsamp).*I_NCO;   %I路输入信息数据

            Q_RECE=rece((i-1-mul)*nsamp+1 : (i-1+mul)*nsamp+nsamp).*Q_NCO;   %Q路输入信息数据

            %根升余弦滤波

            I_RRC_S = RRCrece(I_RECE,Freq_Data,nsamp,alpha,delay);%I路输入信息数据经过根升余弦匹配滤波

            Q_RRC_S = RRCrece(Q_RECE,Freq_Data,nsamp,alpha,delay);%Q路输入信息数据经过根升余弦匹配滤波

            

            I_PLL=I_RRC_S(delay*nsamp-nsamp/2+mul*nsamp+2+k);   %鉴相器的I路输入信息数据

            Q_PLL=Q_RRC_S(delay*nsamp-nsamp/2+mul*nsamp+2+k);   %鉴相器的Q路输入信息数据

            dataoutI((i-1)*nsamp+k) = I_PLL;%用来查看鉴相器的I路输入信息数据

            dataoutQ((i-1)*nsamp+k) = Q_PLL;

            %鉴相器处理

            Discriminator_Out = (sign(I_PLL)*Q_PLL-sign(Q_PLL)*I_PLL)/sqrt(2);   

            dd((i-1)*nsamp+k) = Discriminator_Out;%用来查看鉴相器的输出

            %环路滤波器处理

            PLL_Phase_Part((i-1)*nsamp+k) = Discriminator_Out * C1;   

            Freq_Control((i-1)*nsamp+k) = PLL_Phase_Part((i-1)*nsamp+k)+PLL_Freq_Part((i-1)*nsamp+k-1);

            PLL_Freq_Part((i-1)*nsamp+k) = Discriminator_Out * C2 + PLL_Freq_Part((i-1)*nsamp+k-1);

            NCO_Phase = NCO_Phase + Freq_Control((i-1)*nsamp+k);  %生成的相位

            WC_frame((i-1)*nsamp+k) = FC_NCO + PLL_Freq_Part((i-1)*nsamp+k) * Freq_Sample;

            

            %=========================================================

            NCO_Phase_((i-1)*nsamp+k)=mod(NCO_Phase,2*pi);

         end

     end



     figure

     subplot(121),stem(dataoutI);

     subplot(122),stem(dataoutQ);
     
%     figure;

%     subplot(1,2,1)

%     plot(WC_frame((1+mul)*nsamp:end-mul*nsamp));

%     grid on;

%     title('锁相环频率响应曲线');

% 

%     subplot(1,2,2)

%     plot(PLL_Phase_Part((1+mul)*nsamp:end-mul*nsamp)*180/pi);

%     title('锁相环相位响应曲线');

%     grid on;

    

    %判断同步头，信号是否出现了反相，及时调整

    num1 = symerr(sign(I_D(comps1:compf1)) , sign(dataoutI(comps1:compf1)));

    num2 = symerr(sign(I_D(comps1:compf1)) , -sign(dataoutI(comps1:compf1)));

    num3 = symerr(sign(I_D(comps1:compf1)) , sign(dataoutQ(comps1:compf1)));

    num4 = symerr(sign(I_D(comps1:compf1)) , -sign(dataoutQ(comps1:compf1)));

    numI = [num1,num2,num3,num4];

    num = min(numI)



    if num1 == num

        dataout_I = dataoutI;

    elseif num2 == num

        dataout_I = -dataoutI;

    elseif  num3 == num

        dataout_I = dataoutQ;

    else

        dataout_I = -dataoutQ;

    end



    num1 = symerr(sign(Q_D(comps2:compf2)) , sign(dataoutQ(comps2:compf2)));

    num2 = symerr(sign(Q_D(comps2:compf2)) , -sign(dataoutQ(comps2:compf2)));

    num3 = symerr(sign(Q_D(comps2:compf2)) , sign(dataoutI(comps2:compf2)));

    num4 = symerr(sign(Q_D(comps2:compf2)) , -sign(dataoutI(comps2:compf2)));

    numQ = [num1,num2,num3,num4];

    num = min(numQ)



    if num1 == num

        dataout_Q = dataoutQ;

    elseif num2 == num

        dataout_Q = -dataoutQ;

    elseif  num3 == num

        dataout_Q = dataoutI;

    else

        dataout_Q = -dataoutI;

    end

    

 

    

     %进入gardner环的信号

     datarcosI = dataout_I(9:end) ;

     datarcosQ = dataout_Q(9:end) ;



     %信号符号数

     interplen = length(datarcosI)/nsamp;

     

     %gardner环系数

     C1 = 0.001

     C2 = C1 * 0.001;

 

     q = zeros(1,interplen);

     m = 5;%采样速率时钟

     j = 3;%符号速率时钟

     q0 = 0.9;

     w = 0.5;%lf输出

     s0 = 2;%插值乘法器值



     Detector_out = zeros(1,interplen);%误差检测输出

     interp_outI = zeros(1,interplen * 2);%插值filter输出;

     interp_outQ = zeros(1,interplen * 2);

     

     %预设第一个符号周期内插值

     interp_outI(1) = datarcosI(2);

     interp_outI(2) = datarcosI(4);

     interp_outQ(1) = datarcosQ(2);

     interp_outQ(2) = datarcosQ(4);

     %gardner环

     for i = 2 : interplen - 1

         for k = 1 : nsamp

              %nco控制模块

              y_temp = q0 - w;

              q(m) = q0;

              if y_temp > 0

                  q0 = y_temp;

              else 

                  q0 = mod(y_temp,1);

                  mk = m;

                  uk = s0 * q(m);

                  uu(j) = uk;

                  %内插器I

                  data1 = datarcosI(mk);

                  data2 = datarcosI(mk + 1);

                  interp_outI(j) = uk * data2 + (1 - uk) * data1;

                  %内插抽取模块

                  if mod(j,2) ~= 0

                      qoutI((j+1)/2) = interp_outI(j);

                  end

                  %内插器Q

                  data1 = datarcosQ(mk);

                  data2 = datarcosQ(mk + 1);

                  interp_outQ(j) = uk * data2 + (1 - uk) * data1;

                  %内插抽取模块

                  if mod(j,2) ~= 0

                      qoutQ((j+1)/2) = interp_outQ(j);

                  end

                  j = j + 1;

              end

              m  = m + 1;

         end

          %误差检测         

          Detector_out(i) = (interp_outI((i - 2)* 2 + 2)) * ((interp_outI((i - 1)* 2 + 1)) - (interp_outI((i - 2)* 2 + 1)))...

                           + (interp_outQ((i - 2)* 2 + 2)) * ((interp_outQ((i - 1)* 2 + 1)) - (interp_outQ((i - 2)* 2 + 1)));

          %环路滤波

          w = w + (C1 * (Detector_out(i) - Detector_out(i - 1)) + C2 * Detector_out(i));  

          Wm(i) = w;

     end

     %统计误码率

     in = dataI(sl: sp)';

     out = sign(qoutI(sl: sp));

     [num2,rt2]= symerr(out,in);

     num2

     ratio(1,tp) =  rt2;

     in = dataQ(sl: sp)';

     out = sign(qoutQ(sl: sp));

     [num2,rt2]= symerr(out,in);

     num2

     ratio(1,tp) = ratio(1,tp) + rt2;

     tp = tp + 1;

 %end

 

 dataI(sp-30: sp)'

 sign(qoutI(sp-30: sp))

 

 %误码率图

%  snr = 4:5;

%  figure;

%  semilogy(snr + 3,ratio_costas,'r*-');hold on;grid on;

%  snr = 1 : 10;

%  len_snr = length(snr);

%  for i = 1:len_snr

%     SNR = exp(snr(i)*log(10)/10);

%     theo_err_prb(i) = (1/2)*erfc(sqrt(2*SNR)/sqrt(2));

%  end

%  semilogy(snr,theo_err_prb,'o-');hold on;

 

 %误码率图

 snr = 4;

 figure;

 semilogy(snr ,ratio/2,'r*-');hold on;grid on;

 snr = 1 : 10;

 len_snr = length(snr);

 for i = 1:len_snr

    SNR = exp(snr(i)*log(10)/10);

    theo_err_prb(i) = (1/2)*erfc(sqrt(2*SNR)/sqrt(2));

 end

 semilogy(snr,theo_err_prb,'o-');hold on;

 

    %锁相环性能

    figure;

    subplot(1,2,1)

    plot(WC_frame((1+mul)*nsamp:end-mul*nsamp));

    grid on;

    title('锁相环频率响应曲线');



    subplot(1,2,2)

    plot(PLL_Phase_Part((1+mul)*nsamp:end-mul*nsamp)*180/pi);

    title('锁相环相位响应曲线');

    grid on;

 

 %gardner环性能

 figure;

 plot(uu,'*-');

 grid on; 

 

 figure;

 plot(Wm,'*-');

 grid on; 



 %系统最后输出数据与原始数据比对

 figure;

 stem(I_Data(6:end-6));hold on;

 stem(qoutI(2:end),'r');

 grid on;

 

 figure;

 stem(Q_Data(6:end-6));hold on;

 stem(qoutQ(2:end),'r');

 grid on;

