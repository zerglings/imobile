# Apple Push Notifications support.
#
# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Zergling.Net
# License:: MIT

require 'net/http'
require 'net/https'

require 'socket'
require 'openssl'

require 'rubygems'
require 'json'


# :nodoc: namespace
module Imobile

# Sends a push notification to an iMobile device.
#
# Args:
#   notification:: ruby Hash indicating the desired notification; the hash
#                  should have an extra key named :push_token, containing
#                  the binary-encoded (not hexadecimally-encoded) iMobile device
#                  token, as provided by the UIApplicationDelegate method
#                  application:didRegisterForRemoteNotificationsWithDeviceToken: 
#   path_or_certificate:: the certificate required to talk to APNs; this can be
#                         a path to a .p12 file, a string with the contens of
#                         the .p12 file, or a previously-read certificate
#
# Raises a RuntimeException if Apple's Push Notification service doesn't behave.
def self.push_notification(notification, path_or_certificate)
  PushNotifications.push_notification notification, path_or_certificate
end

# Bulk-transmission of push notifications to Apple's service.
#
# Args:
#   path_or_certificate:: see push_notification
#   notifications:: an array of notification hashes; see push_notification
# 
# If the method receives a block, it yields to its block indefinitely. Each
# time, the block should +next+ a notification or array of notifications to be
# pushed. The block should +break+ when it's done.  
def self.push_notifications(path_or_certificate, notifications = [], &block)
  PushNotifications.push_notifications path_or_certificate, notifications,
                                       &block
end

# Reads the available feedback from Apple's Push Notification service.
#
# Args:
#   path_or_certificate:: see Imobile.push_notification
#
# The currently provided feedback is the tokens for the devices which rejected
# notifications. Each piece of feedback is a hash with the following keys:
#   :push_token:: the device's token, in binary (not hexadecimal) format
#   :time:: the last time when the device rejected notifications; according to
#           Apple, the rejection can be discarded if the device sent a
#           token after this time
#
# The method reads all the feedback available from the Push Notification
# service. If a block is given, each piece of feedback is yielded to the
# method's block, and the method returns nil. If no block is given, the 
# method returns an array containing all pieces of feedback.
def self.push_feedback(path_or_certificate, &block)
  PushNotifications.push_feedback path_or_certificate, &block
end

# Checks if a notification is valid for Apple's Push Notification service.
#
# Currently, notifications are valid if their JSON encodings don't exceed 256
# bytes.
def self.valid_notification?(notification)
  PushNotifications.encode_notification(notification) ? true : false
end

# Packs a hexadecimal iMobile token for push notifications into binary form.
def self.pack_hex_push_token(push_token)
  [push_token.gsub(/\s/, '')].pack('H*')
end

# Carries state for delivering batched notifications.
class PushNotificationsContext
  # Sends a notification via this context's APNs connection.
  #
  # Args:
  #   notification:: see Imobile.push_notification
  #
  # Raises a RuntimeError if the context's APNs connection was closed.
  def push(notification)
    raise "The context's APNs connection was closed" if @closed
    @socket.write PushNotifications.encode_notification(notification)
  end
  
  # Creates a push context for a fixed Apple Push Notifications server.
  #
  # Args:
  #   path_or_certificate:: see Imobile.push_notification
  def initialize(path_or_certificate)
    @certificate = PushNotifications.read_certificate path_or_certificate    
    @socket = PushNotifications.apns_socket @certificate, :push
    @closed = false
  end
  
  # Closes the APNs connection. The context is unusable afterwards.
  def close
    @socket.close unless @closed
    @closed = true
  end
  
  # The raw SSL connection to the APNs. 
  attr_reader :socket
  # The APNs client certificate.
  attr_reader :certificate

  # True if the context's APNs connection is closed.
  def closed?
    @closed
  end
  
  # Called when the context is garbage-collected.
  #
  # Closes the APNs connection, if it wasn't already closed.
  def finalize
    close unless @closed
  end
end

# Implementation details for push_notification.
module PushNotifications
  # Reads an APNs certificate from a string or a file.
  def self.read_certificate(certificate_blob_or_path)
    unless certificate_blob_or_path.respond_to? :to_str
      return certificate_blob_or_path
    end    
    begin
      decode_push_certificate File.read(certificate_blob_or_path)
    rescue
      decode_push_certificate certificate_blob_or_path
    end
  end
  
  # Decodes an APNs certificate.
  def self.decode_push_certificate(certificate_blob)
    if use_new_certificate_decoder?
      # Ruby 1.8.7 and above.
      data = decode_push_certificate_new certificate_blob
    else
      # Ruby 1.8.6.
      data = decode_push_certificate_heroku certificate_blob
    end
    data[:server_type] = server_type data[:certificate] 
    data
  end
  
  # Checks whether the new certificate decoding code is supported.
  def self.use_new_certificate_decoder?
    OpenSSL::PKCS12.respond_to? :new    
  end
  
  # Decodes an APNs certificate, using the new (1.8.7+) OpenSSL methods.
  def self.decode_push_certificate_new(certificate_blob)    
    pkcs12 = OpenSSL::PKCS12.new certificate_blob
    
    certificate = pkcs12.certificate
    key = pkcs12.key
    
    { :certificate => certificate, :key => key }
  end
  
  # Decodes an APNs certificate, using the openssl command-line tool.
  #
  # This works on Heroku, which uses Ruby 1.8.6.
  def self.decode_push_certificate_heroku(certificate_blob)
    # Most of the filesystem on Heroku is read-only. On the other hand, not
    # everyone runs on Heroku. Find a reasonable temporary dir.
    if defined? RAILS_ROOT
      temp_dir = File.join RAILS_ROOT, 'tmp'
    elsif File.exists? '/tmp'
      temp_dir = '/tmp'
    else
      temp_dir = '.'
    end
    
    pkcs12_file_name = File.join temp_dir, "apns_#{Process.pid}.p12"
    pem_file_name = File.join temp_dir, "apns_#{Process.pid}.pem"
    out_file_name = File.join temp_dir, "apns_#{Process.pid}.err"
    
    # Use the command-line openssl tool to break up the pkcs12 file.
    File.open(pkcs12_file_name, 'wb') { |f| f.write certificate_blob }
    Kernel.system "openssl pkcs12 -in #{pkcs12_file_name} -clcerts -nodes " +
                  "-out #{pem_file_name} -password pass: 2> #{out_file_name}"
    pem_blob = File.read pem_file_name    
    [pkcs12_file_name, pem_file_name, out_file_name].each { |f| File.delete f }
    
    certificate = OpenSSL::X509::Certificate.new pem_blob
    key = OpenSSL::PKey::RSA.new pem_blob
    { :certificate => certificate, :key => key }    
  end
  
  # The Apple Push Notification server type that a certificate works with.
  def self.server_type(certificate)
    case certificate.subject.to_s
    when /Apple Development Push/
      return :sandbox
    when /Apple Production Push/
      return :production
    else
      raise "Invalid push certificate - #{certificate.inspect}"
    end        
  end
  
  # Encodes a push notification in a binary string for APNs consumption.
  #
  # Returns a string suitable for transmission over an APNs, or nil if the
  # notification is invalid (i.e. the json encoding exceeds 256 bytes).
  def self.encode_notification(notification)
    push_token = notification[:push_token] || ''
    notification = notification.dup
    notification.delete :push_token
    json_notification = notification.to_json
    return nil if json_notification.length > 256
    
    ["\0", [push_token.length].pack('n'), push_token,
     [json_notification.length].pack('n'), json_notification].join
  end
    
  # Creates a socket to an Apple Push Notification Server.
  #
  # Args:
  #   push_certificate:: the APNs client certificate data, obtained by a call to
  #                      read_certificate
  #   service:: either :feedback or :push
  #    
  # The returned socket is connected and ready for use.
  def self.apns_socket(push_certificate, service = :push)
    context = OpenSSL::SSL::SSLContext.new
    context.cert = push_certificate[:certificate]
    context.key = push_certificate[:key]
    
    server_type = push_certificate[:server_type]
    raw_socket = TCPSocket.new apns_host(server_type, service),
                               apns_port(server_type, service)
    
    socket = OpenSSL::SSL::SSLSocket.new raw_socket, context
    # Magic for closing the raw socket when the SSL socket is closed.
    (class <<socket; self; end).send :define_method, :close do
      super
      raw_socket.close
    end
    socket.connect
  end
  
  # The host name for an Apple Push Notification Server.
  #
  # Args:
  #   server_type:: either :production or :sandbox
  #   service:: either :push or :feedback
  def self.apns_host(server_type, service = :push)
    {
      :feedback => {
        :sandbox => 'feedback.sandbox.push.apple.com',
        :production => 'feedback.push.apple.com'
      },
      :push => {
        :sandbox => 'gateway.sandbox.push.apple.com',
        :production => 'gateway.push.apple.com'
      }
    }[service][server_type]
  end
  
  # The port for an Apple Push Notification Server.
  #
  # Args:
  #   server_type:: either :production or :sandbox
  #   service:: either :push or :feedback
  def self.apns_port(server_type, service = :push)
    {
      :feedback => 2196,
      :push => 2195
    }[service]
  end
  
  # Real implementation of Imobile.push_notifications
  def self.push_notifications(certificate_or_path, notifications)
    context = PushNotificationsContext.new certificate_or_path
    notifications = [notifications] if notifications.kind_of? Hash
    notifications.each { |notification| context.push notification }
    if Kernel.block_given?
      loop do
        notifications = yield
        notifications = [notifications] if notifications.kind_of? Hash
        notifications.each { |notification| context.push notification }
      end
    end
    context.close
  end
  
  # Real implementation of Imobile.push_notification
  def self.push_notification(notification, certificate_or_path)
    push_notifications certificate_or_path, [notification]
  end

  # Real implementation of Imobile.push_feedback
  def self.push_feedback(certificate_or_path, &block)
    if Kernel.block_given?
      raw_push_feedback certificate_or_path, &block
      nil
    else
      feedback = []
      raw_push_feedback certificate_or_path do |feedback_item|
        feedback << feedback_item
      end
      feedback
    end
  end
  
  # Reads the available feedback from Apple's Push Notification service.
  #
  # Args:
  #   certificate_or_path:: see Imobile.push_notification
  #
  # The currently provided feedback is the tokens for the devices which rejected
  # notifications. Each piece of feedback is a hash with the following keys:
  #   :push_token:: the device's token for push notifications, in binary
  #                 (not hexadecimal) format
  #   :time:: the last time when the device rejected notifications; according to
  #           Apple, the rejection can be discarded if the device sent a
  #           token after this time
  #
  # The method reads all the feedback available from the Push Notification
  # service, and yields each piece of feedback to the method's block.
  def self.raw_push_feedback(certificate_or_path)
    socket = apns_socket read_certificate(certificate_or_path), :feedback
    loop do      
      break unless header = fixed_socket_read(socket, 6)
      time = Time.at header[0, 4].unpack('N').first
      push_token = fixed_socket_read(socket, header[4, 2].unpack('n').first)
      break unless push_token
      feedback_item = { :push_token => push_token, :time => time }
      yield feedback_item
    end
    socket.close
  end
  
  # Reads a fixed number of bytes from a socket.
  def self.fixed_socket_read(socket, num_bytes)
    data = ''
    while data.length < num_bytes
      new_data = socket.read(num_bytes - data.length)
      return nil if new_data.nil? or new_data.empty?  # Socket closed.
      data += new_data
    end
    data
  end
end  # module PushNotifications

end  # namespace Imobile
