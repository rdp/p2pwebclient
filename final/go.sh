ruby ruby_to_tex.rb experiment_results.erb.tex

# note -- the first pass it can't get the ref's right! 

# pdflatex thesis.tex
# bibtex thesis
# pdflatex thesis.tex
pdflatex just_experiment_results.tex
# pdflatex just_experiment_results.tex & >/dev/null
chmod a+r *.pdf

#scp just_experiment_results.pdf wilkboar@wilkboardonline.com:~/public_html/roger/p2p/writeup
cp just_experiment_results.pdf just_experiment_results_view_copy.pdf
explorer just_experiment_results_view_copy.pdf
echo 'coming up in explorer'
