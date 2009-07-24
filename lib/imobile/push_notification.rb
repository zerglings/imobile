# Apple Push Notifications support.
#
# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Zergling.Net
# License:: MIT

require 'net/http'
require 'net/https'
require 'openssl'

require 'rubygems'
require 'json'


# :nodoc: namespace
module Imobile

# Sends push notifications to iMobile devices.
#
# Args:
#   notification:: ruby Hash indicating the desired notification
#   certificate_path:: path to the certificate required to talk to APNs
#
# Raises a RuntimeException if Apple's Push Notification service doesn't behave.
def self.push_notification(notification, certificate_path)
  AppStoreReceiptValidation.push_notification notification, certificate_path
end


# Implementation details for push_notification.
module PushNotifications
  # Decodes an APNs certificate.
  def self.read_push_certificate(path)
    certificate_blob = File.read path
    pkcs12 = OpenSSL::PKCS12.new certificate_blob
    
    certificate = pkcs12.certificate
    key = pkcs12.key
    case certificate.subject.to_s
    when /Apple Development Push/
      server_type = :sandbox
    when /Apple Production Push/
      server_type = :production
    else
      raise "Invalid push certificate - #{certificate.inspect}"
    end
    
    { :certificate => certificate, :key => key, :server_type => server_type }
  end
  
  # Real implementation of Imobile.push_notification
  def self.push_notification(notification, certificate_path)
    uri = store_uri server_type
    
    process_response issue_request(request(receipt_blob, uri), uri)     
  end
end  # module PushNotifications

end  # namespace Imobile
