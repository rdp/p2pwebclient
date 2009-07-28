ruby ruby_to_tex.rb experiment_results.tex.erb 

# note -- the first pass it can't get the ref's right! 

pdflatex thesis.tex
#pdflatex thesis.tex & >/dev/null
pdflatex just_experiment_results.tex
#pdflatex just_experiment_results.tex & >/dev/null
pdflatex just_real_future_work.tex # fer fun
bibtex thesis
chmod a+r *.pdf
ruby ruby_to_tex.rb experiment_results.tex.erb  # in case it failed
scp *.pdf wilkboar@wilkboardonline.com:~/public_html/roger/p2p/writeup & >/dev/null
explorer thesis.pdf
