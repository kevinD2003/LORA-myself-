import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { Presentation, PresentationFile } from '@oai/artifact-tool';

const workspaceDir = 'D:/codex/Lora(eg)/reports/group_meeting_2026-10-06';
const buildDir = path.join(workspaceDir, 'build');
const revision = process.argv[2] ?? 'v1';
const skillDir = 'C:/Users/chene/.codex/plugins/cache/openai-primary-runtime/presentations/26.1004.11800/skills/presentations';
const runtimePython = 'C:/Users/chene/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe';
const { resolvePresentationFont, applyPresentationChartFont, finalizePresentation } =
  await import(pathToFileURL(path.join(skillDir, 'container_tools/artifact_tool_utils.mjs')).href);
const FONT = resolvePresentationFont({ fontFamily: 'Microsoft YaHei' });
const sourceRoot = 'D:/codex/Lora（SER performance of different estimation strategies）';
const results = path.join(sourceRoot, 'results/senlora_symmetric_v8');
const code = path.join(sourceRoot, 'senlora_symmetric_v8');
const caseCsv = path.join(results, 'pilot_time_aligned_case_snr_rician/FOUR_CURVE_SUMMARY.csv');
const trackCsv = path.join(results, 'figure12_pilot_time_aligned/FOUR_CURVE_SUMMARY.csv');
const oldCsv = path.join(results, 'figure12_four_methods_nint1/FOUR_CURVE_SUMMARY.csv');
const ciCsv = path.join(results, 'figure12_awgn_uncertainty/AWGN_POINT_UNCERTAINTY.csv');
const images = {
  case1: path.join(results, 'pilot_time_aligned_case_snr_rician/CASE1_FOUR_CURVES.png'),
  case2: path.join(results, 'pilot_time_aligned_case_snr_rician/CASE2_FOUR_CURVES.png'),
  awgn: path.join(results, 'figure12_awgn_uncertainty/FIGURE12_AWGN_FOUR_CURVES_95CI.png'),
  rician: path.join(results, 'figure12_pilot_time_aligned/FIGURE12_RICIAN_FOUR_CURVES.png'),
  combined: path.join(results, 'figure12_awgn_uncertainty/FIGURE12_AWGN_RICIAN_FOUR_CURVES_95CI.png'),
};
const sourceFiles = [...new Set([caseCsv, trackCsv, oldCsv, ciCsv, ...Object.values(images),
  path.join(code, 'PILOT_TIME_ALIGNED_VARIANT.md'),
  path.join(code, 'AWGN_THEORY_SAMPLING_CHECK.md'),
  path.join(code, 'v8_frozen_receiver_manifest.json')])];
const sha = async f => crypto.createHash('sha256').update(await fs.readFile(f)).digest('hex');
const sourceHashes = await Promise.all(sourceFiles.map(sha));
async function readCsv(file) {
  const lines = (await fs.readFile(file, 'utf8')).replace(/^\uFEFF/, '').trim().split(/\r?\n/);
  const keys = lines.shift().split(',');
  return lines.map(line => {
    const values = line.split(',');
    if (values.length !== keys.length) throw new Error('Unexpected CSV quoting: ' + file);
    return Object.fromEntries(keys.map((k, i) => [k, /^-?\d+(\.\d*)?([eE][+-]?\d+)?$/.test(values[i]) ? Number(values[i]) : values[i]]));
  });
}
const [cases, tracks, oldTracks, ci] = await Promise.all([caseCsv, trackCsv, oldCsv, ciCsv].map(readCsv));
const awgn = tracks.filter(r => r.channelIndex === 1).sort((a,b)=>a.orbitStartSec-b.orbitStartSec);
const ric = tracks.filter(r => r.channelIndex === 2).sort((a,b)=>a.orbitStartSec-b.orbitStartSec);
const oldAwgn = oldTracks.filter(r=>r.channelIndex===1).sort((a,b)=>a.orbitStartSec-b.orbitStartSec);
ci.sort((a,b)=>a.orbitStartSec-b.orbitStartSec);
if (cases.length !== 20 || tracks.length !== 10 || ci.length !== 5 ||
    [...cases,...tracks].some(r=>r.packets!==1000 || r.failedDecodes!==0)) throw new Error('Incomplete source tables');
const vpTotal = ci.reduce((s,r)=>s+r.vpRawErrors,0);
const idealTotal = ci.reduce((s,r)=>s+r.nativeIdealRawErrors,0);
if(vpTotal!==78 || idealTotal!==76) throw new Error('Unexpected paired totals');
const c1 = cases.find(r=>r.pointIndex===1 && r.snrDb===-21);
const c2 = cases.find(r=>r.pointIndex===2 && r.snrDb===-21);
const improvement = oldAwgn[4].paperRawErrors / awgn[4].comparisonRawErrors;
const C = { navy:'#123650', ink:'#182B3A', muted:'#587080', blue:'#0072BD', green:'#54832C', orange:'#C37C2C', rule:'#D8E0E5' };
const presentation = Presentation.create({ slideSize:{width:1280,height:720} });
function txt(slide, name, content, x,y,w,h, size=28, color=C.ink, bold=false) {
  const shape = slide.shapes.add({geometry:'textbox',name,position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});
  shape.text = content;
  shape.text.style = { typeface:FONT,fontSize:size,color,bold,autoFit:'none',wrap:'square',insets:{left:0,right:0,top:0,bottom:0} };
  return shape;
}
function slide(title, notes) {
  const s=presentation.slides.add(); s.background.fill='#FFFFFF';
  txt(s,'slide-title',title,56,36,1168,70,44,C.navy,true);
  s.speakerNotes.textFrame.setText(notes);
  return s;
}
async function picture(s, file, alt, frame) {
  s.images.add({blob:new Uint8Array(await fs.readFile(file)),contentType:'image/png',alt,fit:'contain',position:frame});
}
function imageNotes(file, text) { return text+'\n\n来源图像：'+file+'\n结果数据：'+(file.startsWith(path.dirname(caseCsv))?caseCsv:trackCsv)+'\n本图保留原始实验点，没有重新拟合。'; }
function chartStyle(chart) {
  applyPresentationChartFont(chart,{fontFamily:FONT});
  chart.legend={position:'bottom',overlay:false,textStyle:{typeface:FONT,fontSize:24,fill:C.ink}};
}

// 1. Minimal cover.
{
  const s=presentation.slides.add(); s.background.fill=C.navy;
  txt(s,'cover-title','SenLoRa V8\n轨道场景 SER 实验',72,185,1136,190,60,'#FFFFFF',true);
  txt(s,'cover-subtitle','AWGN 与莱斯衰落下的估计补偿对比',76,420,1120,60,30,'#DDEAF1');
  txt(s,'cover-date','组会汇报  2026.10.06',76,575,1100,44,26,'#DDEAF1');
  s.speakerNotes.textFrame.setText('汇报最近完成的SF12冻结V8、PREC、独立理论和观测导频时间对齐变体。数据更新截至2026-10-05。时间对齐变体与论文式(17)即时方法存在明确差异，不能将变体称为原始论文第三种方法。\n来源：'+path.join(code,'PILOT_TIME_ALIGNED_VARIANT.md'));
}
// 2. Concise experimental conditions, kept editable.
{
  const s=slide('实验条件',
    '物理SF=有效SF=12，4096点FFT，BW=Fs=125kHz，符号时长32.768ms。CR3对应Hamming(7,4)，16个7-symbol block，共112个payload符号。原生帧8前导+112数据为120T=3.93216s，导频方法234.25T=7.675904s。\n信道AWGN，以及每包一个常数复增益的单位平均功率Rician，K=10dB。h=sqrt(K/(K+1))+sqrt(1/(2(K+1)))*(a+jb)，a,b独立标准高斯，K线性值10。噪声方差10^(-SNR/10)，不按瞬时衰落功率重新归一化。\n轨道高度550km，载频868MHz，Track-A解析Doppler模型。每个离散位置独立生成、估计、解码。Case-SNR为Rician下Case1(-366s)/Case2(0s)，-30:1:-21dB，20个条件各1000包，共20000条配对记录。轨迹5点×AWGN/Rician各1000包，共10000条记录，Es/N0=15dB，对应采样SNR=-21.12359948dB。原生PREC/VP/Ideal冻结同包基线只读复用，重算变体及其离线Ideal。\nVP d0=0.10bin，d1=0.80bin，所有位置使用相同冻结入口、同一参数和两遍流程。接收机不输入轨道、SNR、真值或目标SER，Ideal仅解码结束后离线对照。SER是最终硬物理符号错误数/112000。\n来源：'+caseCsv+'\n'+trackCsv+'\n'+path.join(code,'v8_frozen_receiver_manifest.json')+'\n'+path.join(sourceRoot,'src/exp1TrackAOrbit.m'));
  const values=[
    ['SF','12','BW / Fs','125 kHz'],
    ['编码','CR3，Hamming(7,4)','原生帧','8 前导 + 112 数据'],
    ['信道','AWGN / Rician','K','10 dB，每包平坦'],
    ['载频 / 高度','868 MHz / 550 km','每点包数','1000'],
    ['帧时长','原生 3.932 s\n导频 7.676 s','统计口径','Raw SER'],
  ];
  const t=s.tables.add({rows:5,columns:4,left:56,top:140,width:1168,height:360,columnWidths:[175,409,175,409],values});
  t.borders.assign({style:'solid',fill:C.rule,width:1});
  for(let r=0;r<5;r++) {
    t.rows[r].height=72;
    for(let c=0;c<4;c++) {
      const cell=t.getCell(r,c); cell.fill=(c===0||c===2)?'#EFF4F7':'#FFFFFF';
      cell.text.style={typeface:FONT,fontSize:25,color:C.ink,bold:c===0||c===2,verticalAlignment:'middle'};
    }
  }
  txt(s,'snr-grid','SNR 扫描：−30 至 −21 dB，每 1 dB 一点',56,545,1168,45,27);
  txt(s,'orbit-grid','轨迹：−366、−274.5、−183、−91.5、0 s，Es/N0 = 15 dB',56,606,1168,48,26);
}
// 3. Case1 image and short numeric annotation.
{
  const s=slide('Case1：Rician 信道 SER–SNR',imageNotes(images.case1,
    'Case1为-366s的低rate端。本页是Rician K=10dB，每点1000包。-21dB端VP='+c1.vpSer+'，PREC='+c1.precSer+'，理论='+c1.theorySer+'，时间对齐变体='+c1.comparisonSer+'。VP与理论接近不意味着已证明等效。原生方法与导频方法帧长和开销不同。\nV8从相同8前导构造Static/Dynamic模型，payload起点对齐后融合完整相位轨迹。第一遍补偿和Hamming解码，第二遍当前block残差CFO与合法Hamming码字联合ML，质量门仅影响后续block反馈。d0/d1固定，未增加轨道分支。'));
  await picture(s,images.case1,'Case1 Rician four-curve raw SER plot',{left:40,top:115,width:805,height:550});
  txt(s,'case1-snr','−21 dB',884,205,340,45,30,C.muted);
  txt(s,'case1-vp','VP  3.14×10⁻²',884,278,340,50,32,C.blue,true);
  txt(s,'case1-theory','理论  2.85×10⁻²',884,345,340,50,30,C.ink);
  txt(s,'case1-samples','1000 包/点\nRician K = 10 dB',884,470,340,105,26,C.muted);
}
// 4. Case2.
{
  const s=slide('Case2：Rician 信道 SER–SNR',imageNotes(images.case2,
    'Case2为0s的高rate端。-21dB端VP='+c2.vpSer+'，PREC='+c2.precSer+'，理论='+c2.theorySer+'，时间对齐变体='+c2.comparisonSer+'。PREC高rate端观测SER接近1，冻结VP明显降低错误。仍需预注册配对容差与独立统计，不能据一端接近理论宣称Formal通过。\n数据来源：'+caseCsv));
  await picture(s,images.case2,'Case2 Rician four-curve raw SER plot',{left:40,top:115,width:805,height:550});
  txt(s,'case2-snr','−21 dB',884,205,340,45,30,C.muted);
  txt(s,'case2-vp','VP  2.89×10⁻²',884,278,340,50,32,C.blue,true);
  txt(s,'case2-prec','PREC  0.995',884,345,340,50,30,C.ink);
  txt(s,'case2-samples','1000 包/点\nRician K = 10 dB',884,470,340,105,26,C.muted);
}
// 5. AWGN original high-resolution confidence image.
{
  const s=slide('AWGN 五点轨迹',imageNotes(images.awgn,
    '采样SNR=-21.1235994797dB，Es/N0=15dB，每点1000包。VP原始错数16/11/14/12/25，对应SER9.8214e-5至2.2321e-4。理论是未编码非相干FFT的总体期望1.503107436e-4，不是每批Monte Carlo观测的样本下界，也不是所有码辅助接收机的信息论下界。\n误差条为点态95%完整包cluster bootstrap区间，20000次，分析种子2026100500+点号。VP和native Ideal共用重采样包索引，全局随机状态与原始噪声种子不变。所有点态VP区间包含理论，配对差异区间包含0。不是五点同时置信带，也不是等效性证明。\n统计来源：'+ciCsv+'\n'+path.join(code,'AWGN_THEORY_SAMPLING_CHECK.md')));
  await picture(s,images.awgn,'AWGN raw SER with pointwise packet-bootstrap confidence intervals',{left:32,top:115,width:815,height:557});
  txt(s,'awgn-level','VP 约 10⁻⁴',886,223,340,54,34,C.blue,true);
  txt(s,'awgn-ci','点态 95% 区间\n均包含理论',886,325,330,94,28,C.ink);
  txt(s,'awgn-samples','1000 包/点',886,505,330,42,26,C.muted);
}
// 6. Rician trajectory.
{
  const s=slide('Rician 五点轨迹',imageNotes(images.rician,
    'Rician为单位平均功率、每包平坦、K=10dB。五点轨迹VP SER依次0.0344821、0.03575、0.0339554、0.0312768、0.0381161。理论常数0.03096406913，时间对齐变体0.0703214至0.0864375，仍明显高于理论。这里没有给Rician添加未计算的置信区间，没有统计显著性或严格平直声明。'));
  await picture(s,images.rician,'Rician five-point orbital four-curve SER plot',{left:40,top:115,width:805,height:550});
  txt(s,'rician-vp','VP  0.0313–0.0381',865,222,359,56,30,C.blue,true);
  txt(s,'rician-theory','理论  0.03096',865,317,359,50,29,C.ink);
  txt(s,'rician-condition','K = 10 dB\n1000 包/点',865,466,359,94,26,C.muted);
}
// 7. Editable chart from actual saved results, all points retained.
{
  const s=slide('论文即时法与时间对齐变体',
    '图中纵轴是log10(SER)，只是显示坐标变换，未调整任何错误计数。论文即时法是当前SF12/noLDRO PHY适配的式(17)方法，n_int=1，FFT16，并非完全复用论文原始PHY。新增时间对齐变体缓冲一个数据符号，以左右已接收导频在相对帧中心时刻插值CFO。首数据符号权重5/9，其余1/2，按模Fs最短圆弧插值；符号内部rate仍为0。隐式使用频率变化信息，明确标注usesDopplerRate=true、usesFuturePilot=true。\n0s同包观测错数从3637降至90，约'+improvement.toFixed(1)+'倍。-366s从57增至91，提示收益并不覆盖所有位置。变体AWGN整体仍约为理论5.2至6.1倍，没有实现理论性能。原生帧120T，导频帧234.25T，等待右导频有额外延迟。\n论文即时法来源：'+oldCsv+'\n变体来源：'+trackCsv+'\n机制：'+path.join(code,'PILOT_TIME_ALIGNED_VARIANT.md'));
  const chart=s.charts.add('line',{position:{left:62,top:132,width:1156,height:414},titlePlacement:'none',
    categories:awgn.map(r=>String(r.orbitStartSec)),
    series:[
      {name:'论文即时法（PHY适配）',values:oldAwgn.map(r=>Number(Math.log10(r.paperSer).toFixed(12))),line:{fill:'#A26928',width:3},marker:{symbol:'circle',size:8,fill:'#A26928'}},
      {name:'时间对齐变体',values:awgn.map(r=>Number(Math.log10(r.comparisonSer).toFixed(12))),line:{fill:C.green,width:3},marker:{symbol:'square',size:8,fill:C.green}},
    ],lineOptions:{smooth:false},hasLegend:true,
    xAxis:{position:'bottom',tickLabelPosition:'low',title:{text:'帧起点 t (s)',textStyle:{typeface:FONT,fontSize:24,fill:C.ink}},textStyle:{typeface:FONT,fontSize:24,fill:C.ink}},
    yAxis:{title:{text:'log₁₀(SER)',textStyle:{typeface:FONT,fontSize:24,fill:C.ink}},min:-4,max:-1,majorUnit:1,numberFormatCode:'0',textStyle:{typeface:FONT,fontSize:24,fill:C.ink},majorGridlines:{fill:C.rule,width:1}},
    chartFill:'#FFFFFF',plotAreaFill:'#FFFFFF'});
  chartStyle(chart);
  txt(s,'alignment-improvement','0 s：3637 错降至 90 错，约 40.4 倍',64,592,1160,42,28,C.ink,true);
  txt(s,'alignment-low-rate','−366 s：57 错增加至 91 错',64,647,1160,40,26,C.muted);
}
// 8. Editable native comparison chart.
{
  const s=slide('同包错误计数',
    'AWGN，Es/N0=15dB，每点1000包，每包112数据符号。VP和native Ideal使用同一原生帧、同一payload/noise。Ideal仅接收机结束后使用真实样本相位离线补偿，没有把Ideal CFO传给VP。\nVP错数'+ci.map(r=>r.vpRawErrors).join('/')+'，Ideal错数'+ci.map(r=>r.nativeIdealRawErrors).join('/')+'。总错误78/76，总SER1.392857e-4/1.357143e-4。理论每点预期16.83480328错。当前数据未提供超越理论或与Ideal等效的统计证据。\n来源：'+ciCsv);
  const chart=s.charts.add('bar',{position:{left:64,top:132,width:1152,height:419},titlePlacement:'none',
    categories:ci.map(r=>String(r.orbitStartSec)),
    series:[{name:'VP V8',values:ci.map(r=>r.vpRawErrors),fill:C.blue},{name:'同包 Ideal',values:ci.map(r=>r.nativeIdealRawErrors),fill:C.orange}],
    barOptions:{direction:'column',grouping:'clustered',gapWidth:75},hasLegend:true,
    xAxis:{title:{text:'帧起点 t (s)',textStyle:{typeface:FONT,fontSize:24,fill:C.ink}},textStyle:{typeface:FONT,fontSize:24,fill:C.ink}},
    yAxis:{title:{text:'符号错误数',textStyle:{typeface:FONT,fontSize:24,fill:C.ink}},min:0,max:30,majorUnit:5,numberFormatCode:'0',textStyle:{typeface:FONT,fontSize:24,fill:C.ink},majorGridlines:{fill:C.rule,width:1}},
    dataLabels:{showValue:true,position:'outEnd',textStyle:{typeface:FONT,fontSize:25,fill:C.ink},numberFormatCode:'0'},chartFill:'#FFFFFF',plotAreaFill:'#FFFFFF'});
  chartStyle(chart);
  txt(s,'paired-totals',`VP 共 ${vpTotal} 错，同包 Ideal 共 ${idealTotal} 错`,64,596,1160,44,30,C.ink,true);
  txt(s,'expected-errors','每点理论预期约 16.8 错',64,651,1160,38,26,C.muted);
}
// 9. Image-led closing slide, current limitations remain visible.
{
  const s=slide('当前观察与实验边界',imageNotes(images.combined,
    '当前VP在AWGN五点保持约10^-4量级，Rician五点约3e-2。时间对齐变体改善0s即时CFO滞后的尖峰，但整体仍高于当前独立理论，而且低rate端的实际错数有所增加。不能宣称严格平直、原论文完全复现或Formal验收通过。\n本轮30个条件各1000包，共30000配对记录。原生PREC/VP/Ideal基线只读复用，未修改VP/PREC冻结参数。没有拟合、平滑、强制非零、强制排序或挑选种子。代码采用断点接续完成，所有ID1-1000恰好一次、接收机异常0，MATLAB偶发heap corruption根因仍未定位。\n下一步建议先预注册Case2的V8-Ideal绝对SER容差，再决定是否使用第三组未见种子启动9000成对包Formal。Formal应使用成对包cluster bootstrap，并检查镜像和所有相邻点；不能把现有点态区间当作全轨等效证明。'));
  await picture(s,images.combined,'Combined AWGN and Rician orbital comparison, AWGN confidence intervals',{left:42,top:115,width:1196,height:507});
  txt(s,'summary-boundary','时间对齐变体仍高于理论。全轨 Formal 尚未启动',56,645,1168,42,27,C.ink,true);
}

await fs.mkdir(path.join(buildDir,`preview-${revision}`),{recursive:true});
const allSlides=presentation.slides.items;
if(allSlides.length!==9) throw new Error('Slide-count mismatch');
for(let i=0;i<allSlides.length;i++) {
  const b=await presentation.export({slide:allSlides[i],format:'png',scale:1});
  await fs.writeFile(path.join(buildDir,`preview-${revision}`,`slide-${i+1}.png`),new Uint8Array(await b.arrayBuffer()));
  const layout=await allSlides[i].export({format:'layout'});
  await fs.writeFile(path.join(buildDir,`preview-${revision}`,`slide-${i+1}.layout.json`),await layout.text());
  console.log('RENDERED '+(i+1));
}
const candidate=path.join(buildDir,`candidate-${revision}.pptx`);
await (await PresentationFile.exportPptx(presentation)).save(candidate);
const finalPath=path.join(workspaceDir,'output',`SenLoRa_组会汇报_2026-10-06_${revision}.pptx`);
const result=await finalizePresentation({workspaceDir,candidatePath:candidate,finalPath,
  pythonExecutable:runtimePython,
  integrityValidatorPath:path.join(skillDir,'container_tools/inspect_presentation_package_integrity.py'),
  layoutValidatorPath:path.join(skillDir,'container_tools/inspect_presentation_layout_geometry.py'),
  layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-heading-fit','--require-native-table-slide','2'],
  requiredNativeTableOwnerSlides:[2],requiredNativeChartOwnerSlides:[7,8],
  materializeLiteralChartWorkbooks:true,
  fontPolicy:{basis:'design',families:[FONT],scriptFonts:{ea:FONT}},
  verifyArtifactToolImport:true,receiptPath:path.join(buildDir,`validation-${revision}.json`)});
const after=await Promise.all(sourceFiles.map(sha));
if(JSON.stringify(after)!==JSON.stringify(sourceHashes)) throw new Error('Source files changed during deck authoring');
await fs.writeFile(path.join(buildDir,`source-manifest-${revision}.json`),JSON.stringify({sourceFiles,sourceHashes,sourceUnchanged:true,totals:{vpTotal,idealTotal},slideCount:9},null,2));
console.log(JSON.stringify({finalPath,slideCount:9,result},null,2));
