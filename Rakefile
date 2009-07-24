# Rakefile that uses echoe to manage imobile's gemspec. 
#
# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Zergling.Net
# License:: MIT

require 'rubygems'
require 'echoe'

Echoe.new('imobile') do |p|
  p.project = 'zerglings' # rubyforge project
  
  p.author = 'Victor Costan'
  p.email = 'victor@zergling.net'
  p.summary = 'Library for servers backing iPhone applications.'
  p.url = 'http://github.com/costan/imobile'
  p.dependencies = ['json >=1.1.7']
  p.development_dependencies = ["echoe >=3.1.1", "flexmock >=0.8.6"]
  
  p.need_tar_gz = true
  p.need_zip = true
  p.rdoc_pattern = /^(lib|bin|tasks|ext)|^BUILD|^README|^CHANGELOG|^TODO|^LICENSE|^COPYING$/  
end

if $0 == __FILE__
  Rake.application = Rake::Application.new
  Rake.application.run
end
