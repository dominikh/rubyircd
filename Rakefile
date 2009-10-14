require 'rake/rdoctask'
require 'rake/testtask'
require 'rake/gempackagetask'
require 'rake/packagetask'

# Dependencies

task "default" => ["test_all"]

# Tasks

Rake::TestTask.new("test_all") do |task|
  task.pattern = 'test/*_test.rb'
end

task 'rcov' do
  sh 'rcov --xrefs --no-validator-links --exclude rubyircd.rb,ruby_extensions.rb test/*_test.rb'
  puts 'Report done.'
end

task 'graph' do
  sh 'ruby test/create_graph.rb | dot -Tpng > graph.png'
  sh 'eog graph.png'
end