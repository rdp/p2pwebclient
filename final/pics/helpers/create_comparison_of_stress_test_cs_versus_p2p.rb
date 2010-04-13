require 'fileutils'
FileUtils.mkdir_p '../test'
Dir.chdir '../test' do
 system 'ruby ../helpers/parse_raw_old_stats.rb ../vr_unnamed316651_cs_stress_test/number_statsunnamed316651_at1_run1_unnamed316651_at1_run2_unnametc.txt ../vr_medium_p2p_load_tak4/number_statsmedium_p2p_load_tak4_at1_run1_medium_p2p_load_tak4_etc.txt'  
end