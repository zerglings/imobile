# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Zergling.Net
# License:: MIT

require 'imobile'

require 'time'
require 'test/unit'


class ValidateReceiptTest < Test::Unit::TestCase
  def setup
    testdata_path = File.join(File.dirname(__FILE__), '..', 'testdata')    
    @forged_sandbox_blob = File.read File.join(testdata_path,
                                               'forged_sandbox_receipt')
    @valid_sandbox_blob = File.read File.join(testdata_path,
                                              'valid_sandbox_receipt')
  end
  
  def test_valid_sandbox_receipt
    golden_date = Time.parse('2009-07-22 18:52:46 EEST')
    
    receipt = Imobile.validate_receipt @valid_sandbox_blob, :sandbox
    assert receipt, "Genuine receipt failed validation"
    
    assert_equal 1, receipt[:quantity], 'Wrong quantity'
    assert_equal 'us.costan.ZergSupportTests', receipt[:bid], 'Wrong bundle ID'
    assert_equal '1.9.8.3', receipt[:bvrs], 'Wrong bundle version'
    assert_equal 'net.zergling.ZergSupport.sub_cheap', receipt[:product_id],
                 'Wrong product ID'
    assert_equal '324740515', receipt[:item_id], 'Wrong item (iTunes app) ID' 
    assert_equal '1000000000016600', receipt[:transaction_id],
                 'Wrong transaction ID' 
    assert_equal '1000000000016600', receipt[:original_transaction_id],
                 'Wrong original transaction ID' 
    assert_equal golden_date.to_f,
                 Time.parse(receipt[:purchase_date].to_s).to_f,
                 'Wrong purchase date'    
    assert_equal golden_date.to_f,
                 Time.parse(receipt[:original_purchase_date].to_s).to_f,
                 'Wrong original purchase date'
  end
  
  def test_forged_sandbox_receipt
    assert_equal false,
                 Imobile.validate_receipt(@forged_sandbox_blob, :sandbox),
                 "Forged receipt passed validation"
  end
  
  # TODO(costan): add tests against the real servers, as soon as someone donates
  #               a receipt
end
