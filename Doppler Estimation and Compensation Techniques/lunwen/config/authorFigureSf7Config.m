function cfg = authorFigureSf7Config()
%AUTHORFIGURESF7CONFIG Configuration transcribed from author arXiv source.

cfg = paperSf7Config();
cfg.experimentName = "author_figure_sf7_midamble_point";
cfg.channel.model = "awgn_only";
cfg.plot.noDopplerLabel = "AWGN (No Doppler)";
cfg.provenance.profile = "author_arxiv_figure_source";
cfg.provenance.sourceFile = "tmp/references/paper_arxiv_source/main.tex";
cfg.provenance.rationale = ...
    "Source lines 500 and 530 specify AWGN+Doppler and n_int=12.";
cfg.provenance.fittedOrTuned = false;
end
