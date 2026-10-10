# 置信符号基础复现：源码功能索引

[项目入口](../README.md) · [结果索引](result_index.md)

文件按功能分类，链接指向实际源码位置；名称与目录保留原样。描述取源码开头注释，完整行为以源码和测试为准。

## 信号与载荷生成（2）

| 文件 | 内容 |
|---|---|
| [modulateLoRaSymbol.m](../modulateLoRaSymbol.m) | Generate one LoRa symbol at one sample per FFT bin. |
| [synthesizeLoRaSignalSequence.m](../synthesizeLoRaSignalSequence.m) | Generate a preamble and LoRa payload waveform. |

## 回归测试（1）

| 文件 | 内容 |
|---|---|
| [testSenLoRaConfidence.m](../testSenLoRaConfidence.m) | Unit tests for SenLoRa confidence reproduction. |

## 实验、报告与维护入口（5）

| 文件 | 内容 |
|---|---|
| [run_predictive_doppler_ber_demo.m](../run_predictive_doppler_ber_demo.m) | Correct-symbol-aided Doppler tracking. |
| [run_senlora_confidence_demo.m](../run_senlora_confidence_demo.m) | Minimal SenLoRa confidence-symbol reproduction. |
| [run_senlora_continuous_demo.m](../run_senlora_continuous_demo.m) | Continuous SenLoRa confidence-symbol demo. |
| [run_sf11_variable_doppler_ber.m](../run_sf11_variable_doppler_ber.m) | SF11 Doppler BER and symbol-boundary validation. |
| [runSenLoRaProjectTests.m](../runSenLoRaProjectTests.m) | Discover and run the complete project test suite. |

## 接收与补偿（4）

| 文件 | 内容 |
|---|---|
| [estimateResidualByPhaseRotation.m](../estimateResidualByPhaseRotation.m) | Estimate CFO using the PREC rotation idea. |
| [hardDemodLoRaWithCfo.m](../hardDemodLoRaWithCfo.m) | Apply phase rotation, dechirp, FFT, and hard decision. |
| [iterativeSoftDemodBlockFromFft.m](../iterativeSoftDemodBlockFromFft.m) | Algorithm-2 style iterative wrapper. |
| [makePhaseRotationBank.m](../makePhaseRotationBank.m) | Precompute PREC-style phase rotations. |

## 理论与统计（1）

| 文件 | 内容 |
|---|---|
| [theoreticalLoRaBerAwgn.m](../theoreticalLoRaBerAwgn.m) | Exact noncoherent orthogonal-MFSK BER in AWGN. |

## 编码与译码（6）

| 文件 | 内容 |
|---|---|
| [deinterleaveBlock.m](../deinterleaveBlock.m) | Minimal block deinterleaver for the reproduction demo. |
| [hammingCodeTable.m](../hammingCodeTable.m) | Table 3 from the SenLoRa paper. |
| [interleaveBlockBack.m](../interleaveBlockBack.m) | Inverse of deinterleaveBlock for the demo model. |
| [loraGrayBits.m](../loraGrayBits.m) | Return LoRa Gray-code bits for FFT bin grouping. |
| [softHammingDecodeBlock.m](../softHammingDecodeBlock.m) | Decode all SF soft Hamming codewords. |
| [softHammingDecodeOne.m](../softHammingDecodeOne.m) | Algorithm 1 from the SenLoRa paper. |

## 置信检测与软信息（8）

| 文件 | 内容 |
|---|---|
| [amendLlr.m](../amendLlr.m) | Amend LLRs after soft Hamming decoding. |
| [binLogProbToLlr.m](../binLogProbToLlr.m) | Compute bit LLRs from FFT-bin log probabilities. |
| [detectConfidentSymbolsFromFft.m](../detectConfidentSymbolsFromFft.m) | Detect SenLoRa confident symbols from FFTs. |
| [selectConfidentSymbols.m](../selectConfidentSymbols.m) | Select confidence symbols using adaptive thresholds. |
| [stepSenLoRaSymbolDetector.m](../stepSenLoRaSymbolDetector.m) | Process one symbol in a continuous FFT stream. |
| [symbolConfidence.m](../symbolConfidence.m) | Sum of squared bit LLRs per symbol. |
| [synthesizeDemoSpectra.m](../synthesizeDemoSpectra.m) | Create noisy FFT spectra for the demo and tests. |
| [updateConfidenceThreshold.m](../updateConfidenceThreshold.m) | Compute local and EMA global thresholds. |

## 轨道与信道（3）

| 文件 | 内容 |
|---|---|
| [buildDopplerCfoTrajectory.m](../buildDopplerCfoTrajectory.m) | Integrate a Doppler-rate profile at symbol times. |
| [generateDopplerLoRaSymbols.m](../generateDopplerLoRaSymbols.m) | Generate noisy LoRa symbols with smooth CFO. |
| [predictiveDopplerCompensate.m](../predictiveDopplerCompensate.m) | Track CFO using previously correct symbols. |

## 辅助工具与测试基础设施（11）

| 文件 | 内容 |
|---|---|
| [codewordBits.m](../codewordBits.m) | Extract the first 4 + CR bits from the 8-bit code table. |
| [countLoRaBitErrors.m](../countLoRaBitErrors.m) | Count Gray-mapped bit errors between LoRa symbols. |
| [dechirpLoRaSignalSequence.m](../dechirpLoRaSignalSequence.m) | Convert a synchronized LoRa waveform to FFT rows. |
| [detectContinuousSymbolSequence.m](../detectContinuousSymbolSequence.m) | Detect flags over a continuous symbol stream. |
| [detectLoRaSignalSequence.m](../detectLoRaSignalSequence.m) | Detect symbols and flags from a LoRa IQ waveform. |
| [estimateNoisePower.m](../estimateNoisePower.m) | Estimate N0 from nonzero preamble FFT bins. |
| [fftToBinLogProb.m](../fftToBinLogProb.m) | Convert FFT-bin energy to a stable log probability vector. |
| [logSumExp.m](../logSumExp.m) | Stable log(sum(exp(x))). |
| [loraBaseUpchirp.m](../loraBaseUpchirp.m) | Generate one unit-power discrete LoRa base upchirp. |
| [nibblesToDemoBins.m](../nibblesToDemoBins.m) | Build demo FFT-bin indices consistent with the LLR path. |
| [plotSenLoRaPaperCorrespondence.m](../plotSenLoRaPaperCorrespondence.m) | Plot results aligned with Sec. 5 objects. |

