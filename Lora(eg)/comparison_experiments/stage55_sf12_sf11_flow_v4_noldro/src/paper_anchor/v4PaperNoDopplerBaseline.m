function result = v4PaperNoDopplerBaseline(packet,config)
copy = packet;
copy.rx = packet.rxNoDoppler;
result = v4PaperNativeMidambleDecode(copy,config,true);
result.methodName = 'No-Doppler-Rician-AWGN-SF12-noLDRO';
end
