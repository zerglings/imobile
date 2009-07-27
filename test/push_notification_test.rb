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
    
    @hex_dev_token = File.read File.join(testdata_path, 'sandbox_push_token')
    @dev_token = File.read File.join(testdata_path, 'sandbox_push_token.bin')
    
    @notification = {:aps => {:alert => 'imobile test notification'}}
    @encoded_notification = File.read File.join(testdata_path,
                                                'encoded_notification')
  end
  
  def test_read_push_certificate
    cert_data = Imobile::PushNotifications.read_certificate @dev_cert_path
    assert cert_data, "Dev certificate didn't load"    
    assert_equal :sandbox, cert_data[:server_type],
                 "Dev certificate mistaken for prod"
    assert cert_data[:key].kind_of?(OpenSSL::PKey::PKey),
           "Dev certificate does not contain a key"
    assert(/Q686F7Z6YU/ =~ cert_data[:certificate].subject.to_s,
           "Wrong data in dev certificate #{cert_data[:certificate].inspect}")

    prod_blob = File.read @prod_cert_path
    cert_data = Imobile::PushNotifications.read_certificate prod_blob 
    assert cert_data, "Prod certificate didn't load"    
    assert_equal :production, cert_data[:server_type],
                 "Prod certificate mistaken for dev"
    assert cert_data[:key].kind_of?(OpenSSL::PKey::PKey),
           "Prod certificate does not contain a key"
    assert(/Q686F7Z6YU/ =~ cert_data[:certificate].subject.to_s,
           "Wrong data in prod certificate #{cert_data[:certificate].inspect}")
  end
  
  def test_pack_push_token
    assert_equal @dev_token, Imobile.pack_hex_push_token(@hex_dev_token)
  end
   
  def test_encode_notification
    notification = @notification.merge :push_token => @dev_token
    encoded = Imobile::PushNotifications.encode_notification notification
    
    assert_equal @encoded_notification, encoded
  end
  
  def test_valid_notification
    assert Imobile.valid_notification?(@notification),
           'Failed on easy valid notification'
    notification = @notification.merge :push_token => '1' * 512
    assert Imobile.valid_notification?(notification),
           'Failed on notification with large device token'
    notification[:aps][:alert] = '1' * 512
    assert !Imobile.valid_notification?(notification),
           'Passed notification with large alert'
  end
  
  def test_apns_host_port
    [
     [:push, @dev_cert_path, 'gateway.sandbox.push.apple.com', 2195],
     [:push, @prod_cert_path, 'gateway.push.apple.com', 2195],
     [:feedback, @dev_cert_path, 'feedback.sandbox.push.apple.com', 2196],
     [:feedback, @prod_cert_path, 'feedback.push.apple.com', 2196]
    ].each do |service, cert_path, gold_host, gold_port|
      cert = Imobile::PushNotifications.read_certificate cert_path
      server_type = cert[:server_type]
      assert_equal gold_host,
                   Imobile::PushNotifications.apns_host(server_type, service)
      assert_equal gold_port,
                   Imobile::PushNotifications.apns_port(server_type, service)
    end
  end
    
  def test_smoke_push
    notification = @notification.merge :push_token => @dev_token
    Imobile.push_notification notification, @dev_cert_path
  end
  
  def test_feedback_decoding
    time1 = Time.at((Time.now - 3600).to_i)
    time2 = Time.at((Time.now - 3600 * 72).to_i)
    token1 = @dev_token
    token2 = @dev_token.reverse
    golden_feedback = [
      {:push_token => token1, :time => time1},
      {:push_token => token2, :time => time2}
    ]
    
    reads = [
      [6, [time1.to_i].pack('N')],
      [2, [token1.length].pack('n')],
      [token1.length, token1[0, 10]],
      [token1.length - 10, token1[10, token1.length - 10]],
      [6, [time2.to_i].pack('N')[0, 3]],
      [3, [time2.to_i].pack('N')[3, 1] + [token2.length].pack('n')],
      [token2.length, token2],
      [6, '']
    ]
    
    dev_cert = Imobile::PushNotifications.read_certificate @dev_cert_path
    prod_cert = Imobile::PushNotifications.read_certificate @prod_cert_path
    socket1, socket2 = MockSocket.new(reads), MockSocket.new(reads)
    flexmock(Imobile::PushNotifications).should_receive(:apns_socket).
        with(dev_cert, :feedback).and_return(socket1).once
    flexmock(Imobile::PushNotifications).should_receive(:apns_socket).
        with(prod_cert, :feedback).and_return(socket2)
        
    # Test no-block codepath.
    assert_equal golden_feedback, Imobile.push_feedback(dev_cert),
                 "No-block codepath failed."
    assert socket1.closed, "No-block codepath didn't close socket"
    
    # Test block codepath
    output_feedback = []
    Imobile.push_feedback prod_cert do |feedback_item|
      output_feedback << feedback_item
    end
    assert_equal golden_feedback, output_feedback, "Block codepath failed."
    assert socket2.closed, "Vlock codepath didn't close socket"
  end
  
  def test_smoke_feedback
    Imobile.push_feedback @dev_cert_path do |feedback_item|
      check_feedback_item feedback_item
    end
    
    feedback_items = Imobile.push_feedback @prod_cert_path
    feedback_items.each { |feedback_item| check_feedback_item feedback_item }
  end
  
  # Verifies that a piece of feedback looks valid.
  def check_feedback_item(feedback)
    assert feedback[:push_token],
           "A feedback item does not contain a push token"
    assert feedback[:time],
           "A feedback item does not contain a timestamp"
  end  
end


class MockSocket
  def initialize(expected_reads)
    @expected_reads = expected_reads.dup
    @closed = false
  end
  attr_reader :closed
  
  def read(bytes)
    expected_read = @expected_reads.shift
    unless expected_read
      raise "Unexpected read of #{bytes.inspect} (done sending data)"
    end
    
    unless bytes == expected_read[0]
      raise "Expected read size #{expected_read[0]}, got #{bytes.inspect}"
    end
    expected_read[1]
  end
  
  def close
    raise "Closed prematurely" unless @expected_reads.empty?
    @closed = true
  end
end
