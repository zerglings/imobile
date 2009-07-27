# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Zergling.Net
# License:: MIT

require 'imobile'

require 'time'
require 'test/unit'

require 'rubygems'
require 'flexmock/test_unit'


class CryptoAppFprintTest < Test::Unit::TestCase
  def setup
    super
    
    testdata_path = File.join(File.dirname(__FILE__), '..', 'testdata')
    @device_attrs = File.open(File.join(testdata_path,
                                        'device_attributes.yml')) do |f| 
      YAML.load f
    end
    
    @mock_binary = '1a2b3c4d5e6f7g8h' * 16384
  end
  
  def test_device_fprint
    fprint = Imobile::CryptoSupportAppFprint.hex_device_fprint @device_attrs
    assert_equal '3231b35f8466d60a6ae00122d2530e65', fprint
  end
  
  def test_crypto_app_fprint
    mock_binary_path = '/binary/path'
    flexmock(File).should_receive(:read).with(mock_binary_path).
                   and_return(@mock_binary)
    fprint = Imobile.crypto_app_fprint @device_attrs, mock_binary_path
    gold_fprint =
        'd84630797d0b19d7d8403705bcc154cfbd82ff386587875193f7d99f01348014' 
    assert_equal gold_fprint, fprint
  end
end
