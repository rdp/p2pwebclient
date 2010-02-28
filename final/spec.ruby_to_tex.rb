require 'spec/autorun'
require 'sane'
require_relative 'ruby_to_tex'

describe "ruby to tex" do
  
  
  def create with_death
     yo = <<eos
      \\documentclass[12pt,onecolumn]{IEEEtran}

\\usepackage{graphicx}
\\usepackage{setspace}
\\usepackage{subfigure}
\\doublespacing

\\widowpenalty = 10000
\\clubpenalty  = 10000

\\begin{document}
<%= figure_directory 'test_dir', 'label_prefix', 'caption prefix', #{with_death} %>
\\end{document}
eos
end
    before do
    yo = create false 
    @a = RubyToTex.new.translate(yo, 'temp.tex.rb')
  end
  
  it "should output some suh-weet double figures" do
    for name in ['pics/test_dir', 'label_prefix', 'caption prefix', 'caption[', 'subfigure[Load', '\caption[]{caption prefix'] do      
      assert @a.include? name
    end
  end
  
  it "should work with pdflatex.exe" do
    assert system("pdflatex temp.tex")
  end
  
  it "should have figure*" do
    assert @a.include?("figure*")    
  end
  
  it "should create death too" do
    yo = create true
    a = RubyToTex.new.translate(yo, 'temp.tex.rb')
    assert a.include? 'death_reasons'
    assert system("pdflatex temp.tex")    
  end
  
end