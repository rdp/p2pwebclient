# I'd imagine that tar can't take the name of too many directories...
# so let's copy all files that match these runs to a subdirectory
require 'singleMultipleGraphs'
require 'pathname'
require 'fileutils'
require 'rubygems'
require 'choice'
ARGV << '--help' if ARGV.length == 0
Choice.options do
  option :staging_dir do
    long '--dir'
    desc "Where to store them there tars"
    default "staging_log_dir/"
  end

  option :go do
   long '--go'
   desc "Actually run--do something!"
   default false
  end

  option :runs do
   long '--runs'
   desc "the runs to run! ex: --runs='[[\"unnamed818946\"]]'"
  end

  option :output_name do
   long '--output-name'
   desc "what to tar it under -- without the .tar.gz"
   default nil
  end

  option :move_instead_of_copy do
    long '--move_instead_of_copy'
    desc "dangerous--move instead of copy them there (saves on storage, though)"
    default nil
  end
end

opts = Choice.choices
opts[:runs] = eval(opts[:runs]) if opts[:runs]
raise 'need --output-name' if opts[:go] and !opts[:output_name]

def go staging_dir, runs, output_name, move_instead_of_copy

runs.flatten!
staging_dir = staging_dir + '/' unless staging_dir[-1..-1] == '/'
staging_dir_single_for_this_run = staging_dir + output_name + '/'
if (File.exist? staging_dir_single_for_this_run)
  raise 'cant have stuff in it already' +  staging_dir_single_for_this_run
else
  Pathname.new(staging_dir_single_for_this_run).mkpath
end

for run in runs
    raise if run.length == 0
    files = RunGrapher.get_log_files_list run
    output_rundir = staging_dir_single_for_this_run
    for file in files
        dirname = File.dirname(file).gsub('../', '').gsub('logs/', '') # remove annoying beginning path junk
        dir = Pathname.new output_rundir + dirname
        if(!dir.exist?)
            dir.mkpath
        end

        actual_command = "cp -r"
        actual_command = "mv" if move_instead_of_copy
        command = "#{actual_command} #{file} #{output_rundir}/#{dirname}"
        puts command
        raise unless system command
        print '.'
    end
    print 'done', run 
end
print "tarring"
raise unless system("tar -C #{staging_dir} -czf #{staging_dir}/#{output_name}.tar.gz #{output_name}")
raise unless FileUtils.rm_rf staging_dir_single_for_this_run
print "DONE to #{staging_dir}#{output_name}.tar.gz ", runs
end

go opts[:staging_dir], opts[:runs], opts[:output_name], opts[:move_instead_of_copy] if opts[:go] # this allows for tests to work by not always running on entry

=begin
#doctest: running twice is baaad.  Should be accurate on ilabber--and should raise
# >> FileUtils.rm_rf 'fake'
# >> go 'fake', ["unnamed316651_at1_run1"], 'test_name'  # succeed
# >> File.exist? 'fake/test_name.tar.gz'
# => true
# >> File.exist? 'fake/test_name'
# => false
# >> system("cd fake && tar -xzf test_name.tar.gz")
# >> Dir.glob('fake/test_name/*').length > 0
# => true
# # running a second time should err
# >> died = false; begin; go 'fake', ["unnamed316651_at1_run1"], 'test_name';  rescue; died = true; end; raise unless died
# # passing it a blank run raises
# >> died = false; begin; go 'fake', [""], 'test_name';  rescue; died = true; end; raise unless died
#
=end
