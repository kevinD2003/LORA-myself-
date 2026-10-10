function c = referencePhyV6Config()
%REFERENCEPHYV6CONFIG Explicit reference-PHY assumptions, not author identity.
setupReferencePhyV6();c=strictPaperConfig();
c.identity='paper-reference-phy-v6';
c.referenceCommit='31243b0ac9cc8255f860dc85fc9594734856e03e';
c.payloadBytes=32;c.explicitHeader=true;c.hasCrc=true;c.ldroMode='auto';
c.syncWord=hex2dec('12');c.syncDownchirpSymbols=2.25;
c.interFrameSilenceSymbols=0; % Hardware's 40-symbol idle guard is not on-air data.
c.preambleSymbolCount=8;c.phaseModel='paper-equation-15-product';
c.codedBerDefinition='pre-Hamming BER on CRC-success packets, actual encoded words only';
c.phyModel='reference hard PHY; first block CR4/reduced SF; payload-only whitening';
c.synchronizationModel='perfect frame alignment; SFD skipped at its physical time';
end
