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
    testdata_path = File.join(File.dirname(__FILE__), '..', 'testdata')
    @device_attrs = File.open(File.join(testdata_path,
                                        'device_attributes.yml')) do |f| 
      YAML.load f
    end
    
    @mock_binary = '1a2b3c4d5e6f7g8h' * 16384
  end
  
  def test_device_fprint
    fprint = Imobile::CryptoSupportAppFprint.hex_device_fprint @device_attrs
    assert_equal '9cef1c830742fa83ad213281c1ce47b5', fprint
  end
  
  def test_crypto_app_fprint
    mock_binary_path = '/binary/path'
    flexmock(File).should_receive(:read).with(mock_binary_path).
                   and_return(@mock_binary)
    fprint = Imobile.crypto_app_fprint @device_attrs, mock_binary_path
    gold_fprint =
        'b5b45dec2177d095bff66dd895c624b1bc264e48575f2b39ed5456c3821c338f' 
    assert_equal gold_fprint, fprint
  end
end
