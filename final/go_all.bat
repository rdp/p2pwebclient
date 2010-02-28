ruby ruby_to_tex.rb experiment_results.erb.tex

@rem # note -- the first pass it can't get the ref's right! 

pdflatex thesis.tex
@rem #pdflatex thesis.tex & >/dev/null
@rem pdflatex just_experiment_results.tex
@rem #pdflatex just_experiment_results.tex & >/dev/null
@rem #pdflatex just_real_future_work.tex # fer fun
bibtex thesis
chmod a+r *.pdf

chrome.bat thesis.pdf
