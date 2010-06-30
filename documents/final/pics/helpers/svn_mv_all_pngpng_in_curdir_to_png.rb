for file in Dir.glob("*.png.png") do
  system("svn mv #{file} #{file[0..-5]}")
end
