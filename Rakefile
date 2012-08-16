require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rake/rdoctask'

$:.unshift(File.expand_path('../lib', __FILE__))
require 'ipaddress'

begin
  require 'rubygems'
  require 'jeweler'

  Jeweler::Tasks.new do |gem|
    gem.name        = IPAddress::GEM
    gem.summary     = "IPv4/IPv6 addresses manipulation library"
    gem.email       = "ceresa@gmail.com"
    gem.homepage    = "http://github.com/bluemonk/ipaddress"
    gem.authors     = ["Marco Ceresa"]
    gem.description = <<-EOD
      IPAddress is a Ruby library designed to make manipulation
      of IPv4 and IPv6 addresses both powerful and simple. It mantains
      a layer of compatibility with Ruby's own IPAddr, while
      addressing many of its issues.
    EOD
    gem.add_dependency 'ruby-nuggets', '>= 0.8.9'
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

begin
  require 'rcov/rcovtask'

  Rcov::RcovTask.new do |t|
    t.libs << 'lib' << 'test'
    t.pattern = 'test/**/*_test.rb'
    t.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end


task :default => :test

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "ipaddress #{IPAddress::VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -Ilib -ripaddress"
end

desc "Look for TODO and FIXME tags in the code"
task :todo do
  r = /FIXME|TODO|TBD/

  Dir['**/*.rb'].each { |f|
    File.foreach(f) { |l| puts "#{f}:#{$.}:#{l}" if l =~ r }
  }
end
