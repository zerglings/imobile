# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Zergling.Net
# License:: MIT

require 'imobile'

require 'time'
require 'test/unit'

require 'rubygems'
require 'flexmock/test_unit'


class PushNotificationTest < Test::Unit::TestCase
  def setup
    testdata_path = File.join(File.dirname(__FILE__), '..', 'testdata')
    @dev_cert_path = File.join(testdata_path, 'apns_developer.p12') 
    @prod_cert_path = File.join(testdata_path, 'apns_production.p12') 
  end
  
  def test_read_push_certificate
    cert_data = Imobile::PushNotifications.read_push_certificate @dev_cert_path
    assert cert_data, "Dev certificate didn't load"    
    assert_equal :sandbox, cert_data[:server_type],
                 "Dev certificate mistaken for prod"
    assert cert_data[:key].kind_of?(OpenSSL::PKey::PKey),
           "Dev certificate does not contain a key"
    assert /Q686F7Z6YU/ =~ cert_data[:certificate].subject.to_s,
           "Wrong data in dev certificate #{cert_data[:certificate].inspect}"

    cert_data = Imobile::PushNotifications.read_push_certificate @prod_cert_path
    assert cert_data, "Prod certificate didn't load"    
    assert_equal :production, cert_data[:server_type],
                 "Prod certificate mistaken for dev"
    assert cert_data[:key].kind_of?(OpenSSL::PKey::PKey),
           "Prod certificate does not contain a key"
    assert /Q686F7Z6YU/ =~ cert_data[:certificate].subject.to_s,
           "Wrong data in prod certificate #{cert_data[:certificate].inspect}"
  end  
end
