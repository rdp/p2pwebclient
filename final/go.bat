ruby ruby_to_tex.rb experiment_results.erb.tex

@rem # note -- the first pass it can't get the ref's right! 

@rem # pdflatex thesis.tex
@rem # bibtex thesis
@rem # pdflatex thesis.tex
pdflatex just_experiment_results.tex
@rem # pdflatex just_experiment_results.tex & >/dev/null
chmod a+r \*.pdf

@rem in case it isn't there
bibtex just_experiment_results
@rem #scp just_experiment_results.pdf wilkboar@wilkboardonline.com:~/public_html/roger/p2p/writeup
@cp just_experiment_results.pdf just_experiment_results_view_copy.pdf
@chrome just_experiment_results_view_copy.pdf

