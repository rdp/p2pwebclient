ruby ruby_to_tex.rb experiment_results.tex.erb 

# note -- the first pass it can't get the ref's right! 

# pdflatex thesis.tex
# bibtex thesis
# pdflatex thesis.tex
pdflatex just_experiment_results.tex
# pdflatex just_experiment_results.tex & >/dev/null
chmod a+r *.pdf
ruby ruby_to_tex.rb experiment_results.tex.erb  # in case it failed
scp *.pdf wilkboar@wilkboardonline.com:~/public_html/roger/p2p/writeup & >/dev/null
cp just_experiment_results.pdf just_experiment_results_view_copy.pdf
explorer just_experiment_results_view_copy.pdf
echo 'coming up in explorer'
