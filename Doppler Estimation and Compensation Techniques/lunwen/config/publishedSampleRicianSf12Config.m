function cfg = publishedSampleRicianSf12Config()
%PUBLISHEDSAMPLERICIANSF12CONFIG Published parameters with sample Rician.

cfg = paperSf12Config();
cfg.experimentName = "published_sample_rician_sf12";
cfg.channel.model = "rician_sample";
cfg.provenance.profile = "published_text_sample_rician_diagnostic";
cfg.provenance.fittedOrTuned = false;
end
