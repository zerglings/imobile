# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{imobile}
  s.version = "0.0.7"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Victor Costan"]
  s.date = %q{2009-07-28}
  s.description = %q{Library for servers backing iPhone applications.}
  s.email = %q{victor@zergling.net}
  s.extra_rdoc_files = ["CHANGELOG", "lib/imobile/crypto_app_fprint.rb", "lib/imobile/push_notification.rb", "lib/imobile/validate_receipt.rb", "lib/imobile.rb", "LICENSE", "README.textile"]
  s.files = ["CHANGELOG", "imobile.gemspec", "lib/imobile/crypto_app_fprint.rb", "lib/imobile/push_notification.rb", "lib/imobile/validate_receipt.rb", "lib/imobile.rb", "LICENSE", "Manifest", "Rakefile", "README.textile", "test/crypto_app_fprint_test.rb", "test/push_notification_test.rb", "test/validate_receipt_test.rb", "testdata/apns_developer.p12", "testdata/apns_production.p12", "testdata/device_attributes.yml", "testdata/encoded_notification", "testdata/forged_sandbox_receipt", "testdata/sandbox_push_token", "testdata/sandbox_push_token.bin", "testdata/valid_sandbox_receipt"]
  s.homepage = %q{http://github.com/costan/imobile}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Imobile", "--main", "README.textile"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{zerglings}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Library for servers backing iPhone applications.}
  s.test_files = ["test/crypto_app_fprint_test.rb", "test/push_notification_test.rb", "test/validate_receipt_test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<json>, [">= 1.1.7"])
      s.add_development_dependency(%q<echoe>, [">= 3.1.1"])
      s.add_development_dependency(%q<flexmock>, [">= 0.8.6"])
    else
      s.add_dependency(%q<json>, [">= 1.1.7"])
      s.add_dependency(%q<echoe>, [">= 3.1.1"])
      s.add_dependency(%q<flexmock>, [">= 0.8.6"])
    end
  else
    s.add_dependency(%q<json>, [">= 1.1.7"])
    s.add_dependency(%q<echoe>, [">= 3.1.1"])
    s.add_dependency(%q<flexmock>, [">= 0.8.6"])
  end
end
