方案更新为：SenLoRa论文负责置信符号检测，卫星论文负责单设备轨道、多普勒频偏、多普勒速率和连续相位模型。现阶段仍不修改代码。
卫星模型依据为 2025 Orthogonality_Analysis_in_LoRa_Uplink_Satellite_Communications_Affected_by_Doppler_Effect.pdf。
一、论文与模块分工
模块	理论来源
卫星轨道、可见窗口	Orthogonality Analysis论文
动态多普勒频偏和速率	Orthogonality Analysis论文式(5)-(12)
符号内分段线性多普勒	Orthogonality Analysis论文式(18)-(20)
连续多普勒相位	Orthogonality Analysis论文式(2)、式(21)
FFT概率、Gray LLR	SenLoRa论文式(12)、式(13)
Hamming软译码	SenLoRa Algorithm 1
置信符号及动态阈值	SenLoRa第5.2节
最多5轮迭代	SenLoRa Algorithm 2
最近8导频循环预测	本项目多普勒补偿器设计
0.1-bin旋转相位残差	师兄PREC代码和本项目设计


二、采用单设备Fig.3轨道模型
本项目只需要一个地面设备和一个卫星，因此采用论文Fig.3的单可见窗口，不使用Fig.17的两个地面设备共享窗口。
固定条件：
c = 3×10^8 m/s
g = 9.8 m/s²
R = 6371 km
ωE = 7.292×10^-5 rad/s
H = 550 km
i = 15°
fc = 868 MHz
BW = Fs = 250 kHz
θc = 56°
θmin = 10°
θmax = 50°
SF = 11
CR = 3
现有可直接复用的模型文件：
[轨道参数](D:/codex/lora(CFO\)/lora_orbit_doppler_config.m)
[逐时刻多普勒轨迹](D:/codex/lora(CFO\)/lora_orbit_doppler_trajectory.m)
[单设备可见窗口](D:/codex/lora(CFO\)/lora_visibility_window.m)
[符号内分段线性近似](D:/codex/lora(CFO\)/lora_doppler_piecewise_linear.m)
[逐采样动态多普勒信道](D:/codex/lora(CFO\)/apply_lora_dynamic_doppler.m)
[AWGN理论BER](D:/codex/Lora(theory\)/lora_css_theoretical_ber.m)
实现时将这些函数复制并整理到新项目子目录，避免运行时依赖其他项目路径。
三、轨道公式
卫星轨道角速度：
\[
\omega_S=
\sqrt{\frac{gR^2}{(R+H)^3}}
\]考虑地球自转后的角速度：
\[
\omega_F=\omega_S-\omega_E\cos i
\]斜距：
\[
\rho(t)=
\sqrt{(R+H)^2+R^2-
2R(R+H)\cos\gamma(t)}
\]卫星径向速度：
\[
v(t)=\dot\rho(t)
\]载波多普勒：
\[
f_D(t)=-f_c\frac{v(t)}{c}
\]多普勒速率：
\[
\dot f_D(t)=\frac{d f_D(t)}{dt}
\]已有代码采用解析径向加速度计算速率，不使用差分曲线估计。
四、可见窗口与两个实验场景
现有代码计算结果：
Δtout = 249.7520 s
Δtin  = 37.0824 s
单设备可见区：
\[
[-249.752,-37.082]\cup[37.082,249.752]\text{ s}
\]场景一：高多普勒频偏
起始时间：
\[
t_0=-\Delta t_{\mathrm{out}}
=-249.7520\text{ s}
\]对应约：
Doppler shift = +18.215 kHz
Doppler rate  = -8.15 Hz/s
FFT bin间隔：
\[
\Delta f_{\mathrm{bin}}
=
250000/2048
=
122.0703\text{ Hz}
\]因此初始频偏约：
\[
18.215\text{ kHz}/122.0703
\approx149.22\text{ bin}
\]该场景主要验证大整数CFO捕获能力。
场景二：高多普勒速率
起始时间：
\[
t_0=+\Delta t_{\mathrm{in}}
=37.0824\text{ s}
\]对应约：
Doppler shift = -7.099 kHz
Doppler rate  = -166.43 Hz/s
归一化速率约：
\[
-166.43/122.0703
\approx-1.363\text{ bin/s}
\]该场景主要验证连续预测和滚动更新能力。
这两个起点都位于真实可通信窗口内。
五、帧结构
采用：
8个已知零前导
112个载荷符号
总符号数：
120
SF11单符号长度：
\[
T_s=2048/250000=8.192\text{ ms}
\]整帧时间：
\[
120T_s=0.98304\text{ s}
\]约1秒帧长既能产生足够的轨迹变化，也不会偏离论文的局部轨道模型。
六、信道生成方式
1. 轨迹图
轨迹图按论文Fig.3使用载波频率：
\[
f_D(t)=-f_c v(t)/c
\]输出：
多普勒频偏；
多普勒速率；
高偏移候选点；
高速率候选点；
可见区和盲区。
2. 实际LoRa波形信道
波形生成必须使用完整瞬时RF频率：
\[
f_{\mathrm{RF}}(t)=f_c+f_{\mathrm{LoRa}}(t)
\]因此逐采样多普勒为：
\[
f_{D,k}(t)=
-f_{\mathrm{RF},k}(t)\frac{v(t)}{c}
\]这包含：
载波多普勒；
LoRa啁啾瞬时频率；
符号频率回绕产生的分段项。
不能只给整帧乘一个载波CFO。
3. 多普勒相位
相位必须由逐采样频率积分得到：
\[
\phi_D[n]
=
\phi_D[n-1]
+
\frac{\pi}{F_s}
\left(f_D[n-1]+f_D[n]\right)
\]使用梯形积分，并且整个帧连续，不能在每个符号开始时归零。
接收信号：
\[
r[n]=s[n]e^{j\phi_D[n]}+w[n]
\]七、精确轨道与分段线性模型的使用
为避免“生成模型与补偿模型完全相同”造成过于理想的结果：
信道真值：使用论文式(12)逐采样精确轨道模型；
接收机预测：使用CFO加多普勒速率的局部线性模型；
分段线性论文模型：用于验证和接收机建模，不直接作为真值泄漏给补偿器。
每个符号内可以表示为：
\[
f_D(t)\approx v_d+c_d(t-t_0)
\]但真实信道仍从精确轨道逐采样产生。
这样可以验证补偿器面对真实轨迹模型误差时是否仍然有效。
八、8前导启动估计
8个已知零前导联合完成：
对8符号FFT功率非相干叠加；
捕获约±150 bin范围的大整数CFO；
每个前导在 -0.5:0.1:0.5 bin 内细化；
二次插值获得亚bin结果；
用8个CFO观测稳健拟合初始频偏和速率；
估计连续符号起始相位。
高偏移场景不能仅使用局部 ±0.5 bin 搜索，必须先捕获大整数CFO。
九、最近8导频循环窗口
前导阶段：
[P1 P2 P3 P4 P5 P6 P7 P8]
载荷阶段，新可靠符号进入：
[P2 P3 P4 P5 P6 P7 P8 V1]
下一可靠符号：
[P3 P4 P5 P6 P7 P8 V1 V2]
固定的是活跃窗口长度8，不是整帧虚拟导频总数。
每次预测采用最近8个可靠符号的：
符号时间；
CFO测量值；
起始相位残差；
置信度；
残差峰值质量。
进行加权稳健拟合。
十、逐符号补偿
对每个载荷符号单独预测：
\[
\hat f_{D,m},\quad
\hat{\dot f}_{D,m},\quad
\hat\phi_m
\]并对该符号的2048个采样逐点补偿：
\[
\tilde r_m[n]
=
r_m[n]\exp\{-j\hat\phi_m[n]\}
\]7符号Hamming块只用于置信度计算，不允许7个符号共用一个补偿量。
十一、SenLoRa置信检测
保持上一版方案：
补偿后的逐符号FFT
→ 论文概率
→ Gray LLR
→ LoRa循环反交织
→ Hamming软译码
→ 修正LLR
→ 逐符号置信度
→ τb
→ α=0.8的τg
→ ConfidentFlag
ConfidentFlag通过后还必须满足旋转相位残差质量门限，才能进入最近8导频窗口。
十二、两种补偿曲线
硬判决PREC
8前导启动
→ 逐符号补偿
→ 硬判决
→ 残差质量通过后更新最近8窗口
不使用SenLoRa软置信检测。
SenLoRa
8前导启动
→ 逐符号补偿
→ SenLoRa置信检测
→ 残差质量通过
→ 更新最近8窗口
两者必须使用完全相同：
轨道；
帧；
符号；
噪声；
前导；
初始CFO估计；
残差搜索步长；
历史窗口长度。
十三、−20 dB后接近AWGN的物理条件
论文指出LoRa可容忍频偏阈值约为：
\[
f_{\mathrm{tol}}=
\frac{B}{2^{SF+1}}
\]SF11、BW250 kHz时：
\[
f_{\mathrm{tol}}
=
250000/4096
\approx61.04\text{ Hz}
\]未经补偿时：
高频偏场景：约18.2 kHz
高速率场景：约7.1 kHz
远高于61 Hz，因此无补偿曲线出现误码地板是合理的。
补偿后要求：
\[
|f_{\mathrm{res}}|<61.04\text{ Hz}
\]为了接近AWGN，进一步要求高SNR残差：
\[
\mathrm{RMS}(f_{\mathrm{res}})
<0.02\text{ bin}
\approx2.44\text{ Hz}
\]满足这一条件后，两种补偿曲线理论上应在−20 dB后继续下降并接近AWGN。
十四、分层验收
按以下顺序实施：
复现论文Fig.3轨迹；
验证精确轨道与分段线性近似；
验证跨符号连续相位；
纯AWGN与理论一致；
理想逐采样补偿与AWGN一致；
Oracle正确符号最近8窗口接近AWGN；
硬判决PREC；
SenLoRa置信补偿；
正式四曲线BER。
任何一层失败，都停止进入下一层。
十五、最终四曲线
两个单设备轨道场景分别绘制：
理想AWGN理论；
动态多普勒、无补偿；
硬判决PREC最近8导频窗口；
SenLoRa置信最近8导频窗口。
最终结果要求：
高频偏与高速率场景均在−20 dB后下降；
两条补偿曲线逐渐接近AWGN；
不存在 10^-3 或 10^-4 非物理误码地板；
无补偿曲线允许维持高BER；
不拟合、不平滑、不裁剪到AWGN；
零误码点使用95%上界并继续连线至 10^-6。
最重要的代码调整方向是：后续不再使用当前两设备 Figure17Geometry 作为轨道入口，而是直接复用 lora(CFO) 中已经验证的单设备Fig.3轨道、可见窗口和逐采样完整RF多普勒模型。