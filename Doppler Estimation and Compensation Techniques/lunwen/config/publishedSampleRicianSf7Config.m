function cfg = publishedSampleRicianSf7Config()
%PUBLISHEDSAMPLERICIANSF7CONFIG Published parameters with sample Rician.

cfg = paperSf7Config();
cfg.experimentName = "published_sample_rician_sf7";
cfg.channel.model = "rician_sample";
cfg.provenance.profile = "published_text_sample_rician_diagnostic";
cfg.provenance.fittedOrTuned = false;
end
