# Online validation for receipt blobs generated by the In-App Purchase process.
#
# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Zergling.Net
# License:: MIT

require 'base64'
require 'date'
require 'net/http'
require 'net/https'
require 'openssl'
require 'time'

require 'rubygems'
require 'json'


# :nodoc: namespace
module Imobile

# Decodes and validates an In-App Purchase receipt from the App Store.
#
# Args:
#   receipt_blob:: raw receipt in SKPaymentTransaction.transactionReceipt
#   server_type:: production or sandbox (the API accepts symbols and strings)
#
# The decoded receipt is returned as a Ruby-friendly hash. Keys are converted to
# snake_case symbols (e.g. 'purchase-date' becomes :purchase_date). Dates and
# relevant numbers are parsed out of the JSON strings.
#
# Returns +false+ if validation fails (the receipt was tampered with). Raises a
# RuntimeException if Apple's Web service returns a HTTP error code.
def self.validate_receipt(receipt_blob, server_type = :sandbox)
  AppStoreReceiptValidation.validate_receipt receipt_blob
end


# Implementation details for validate_receipt.
module AppStoreReceiptValidation
  # An URI object pointing to the App Store receipt validating server.
  #
  # The server type is production or sandbox (strings and symbols work).
  def self.store_uri(server_type)
    uri_string = {
      :production => "https://buy.itunes.apple.com/verifyReceipt",
      :sandbox => "https://sandbox.itunes.apple.com/verifyReceipt" 
    }[server_type.to_sym]
    
    uri_string and URI.parse(uri_string)
  end
  
  # A Net:HTTP request for validating a receipt.    
  def self.request(receipt_blob, store_uri)
    request = Net::HTTP::Post.new store_uri.path
    request.set_content_type 'application/json'
    request.body = {'receipt-data' => Base64.encode64(receipt_blob) }.to_json
    request
  end
  
  # Issues a HTTP request to Apple's receipt validating server.
  def self.issue_request(http_request, store_uri)
    http = Net::HTTP.new store_uri.host, store_uri.port
    http.use_ssl = (store_uri.scheme == 'https')
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.request http_request
  end
  
  # Turns JSON receipt information into a nice Ruby-like receipt.
  #
  # String keys are mapped to Ruby symbols (e.g. 'purchase-date' becomes
  # :purchase_date) and date strings are parsed to Ruby dates.
  def self.nice_receipt(json_receipt)
    nice = Hash[*json_receipt.map { |key, value|
      [key.gsub('-', '_').to_sym, value]
    }.flatten]
    
    [:purchase_date, :original_purchase_date].each do |key|
      nice[key] = DateTime.parse(nice[key]) if nice[key]
    end
    nice[:quantity] = nice[:quantity].to_i if nice[:quantity]
    
    nice
  end
  
  # Processes a HTTP response into a receipt.
  def self.process_response(http_response)
    unless http_response.kind_of? Net::HTTPSuccess
      raise "Internal error in Apple's Web service -- #{http_response.inspect}"
    end
    
    response = JSON.parse http_response.body
    return false unless response['status'] == 0
    nice_receipt response['receipt']
  end
  
  # Real implementation of Imobile.validate_receipt
  def self.validate_receipt(receipt_blob, server_type = :production)
    uri = store_uri server_type
    
    process_response issue_request(request(receipt_blob, uri), uri)     
  end
end  # module AppStoreReceiptValidation

end  # namespace Imobile
