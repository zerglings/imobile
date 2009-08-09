# Application integrity finger-printing used by ZergSupport's CryptoSupport.  
#
# Author:: Victor Costan
# Copyright:: Copyright (C) 2009 Zergling.Net
# License:: MIT

require 'digest/md5'
require 'digest/sha2'
require 'set'
require 'openssl'


# :nodoc: namespace
module Imobile

# An iPhone application's finger-print, as implemented in CryptoSupport.
#
# Args:
#   device_or_hash:: a Hash or ActiveRecord model representing the result of
#                    calling [ZNDeviceFprint deviceAttributes] on the iMobile
#                    device
#   binary_path:: path to the application's binary (executable file)
#                 corresponding to the application version on the device
#                 (indicated by :app_version in the device attributes)
#
# Returns a finger-print that should prove the application's integrity. The
# finger-print is a string consisting of printable characters.
def self.crypto_app_fprint(device_or_hash, binary_path)
  CryptoSupportAppFprint.app_fprint device_or_hash, binary_path
end


# Implementation details for crypto_app_fprint.
module CryptoSupportAppFprint  
  # The finger-print for a device's attributes, as implemented in CryptoSupport.
  #
  # The device attributes should be passed in a Hash that represents the result
  # of calling [ZNDeviceFprint deviceAttributes] on the iMobile device.
  #  
  # The finger-print is returned as a raw string (no hex-formatting).
  # In particular, the returned finger-print is suitable to be used as a key or
  # IV for AES-128.
  #
  # The code mirrors the reference code in ZergSupport's test suite.
  def self.device_fprint(device_attributes)
    Digest::MD5.digest device_fprint_data(device_attributes)
  end
  
  # The finger-print for a device's attributes, as implemented in CryptoSupport.
  #
  # This method resembles device_fprint, but returns the finger-print in a
  # hex-formatted string, so that it can be used by Web services.  
  def self.hex_device_fprint(device_attributes)
    device_fprint(device_attributes).unpack('C*').map {|c| '%02x' % c}.join('')
  end
  
  # The device data used for device finger-printing in CryptoSupport.
  #
  # The device attributes should be passed in a Hash that represents the result
  # of calling [ZNDeviceFprint deviceAttributes] on the iMobile device.   
  def self.device_fprint_data(device_attributes)
    attrs = device_fprint_attributes
    keys = device_attributes.keys.select { |k| attrs.include? k.to_s }
        'D|' + keys.sort.map { |k| device_attributes[k] }.
        map { |v| v.respond_to?(:read) ? v.read : v }.join('|')
  end

  # The device attributes included in the finger-printing operation.  
  def self.device_fprint_attributes
    Set.new(['app_id', 'app_version', 'app_provisioning', 'app_push_token',
             'hardware_model', 'os_name', 'os_version', 'unique_id'])
  end
  
  # The finger-print for a data blob, as implemented in CryptoSupport.
  #
  # Args:
  #   data_blob:: a raw string, usually the result of reading a file
  #   key:: 16-byte string, to be used as an AES key
  #   iv:: 16-byte string, to be used as an AES key
  #
  # The returned finger-print is a hex-formatted string.
  def self.data_fprint(data_blob, key, iv = "\0" * 16)
    cipher = OpenSSL::Cipher::Cipher.new 'aes-128-cbc'
    cipher.encrypt
    cipher.key, cipher.iv = key, iv
    
    plain = data_blob + "\0" * ((16 - (data_blob.length & 0x0f)) & 0x0f)
    crypted = cipher.update plain
    Digest::SHA2.hexdigest crypted
  end
    
  # An iPhone application's finger-print, as implemented in CryptoSupport.
  #
  # The device attributes should be passed in a Hash that represents the result
  # of calling [ZNDeviceFprint deviceAttributes] on the iMobile device. The
  # manifest data should be the result of reading the application's manifest
  # file (currently its executable file).
  #
  # The returned finger-print is a hex-formatted string.
  def self.app_fprint_from_raw_data(device_attributes, manifest_data)
    key = device_fprint device_attributes
    iv = "\0" * 16
    data_fprint manifest_data, key, iv
  end
  
  # An iPhone application's finger-print, as implemented in CryptoSupport.
  def self.app_fprint(device_or_hash, binary_path)
    if device_or_hash.respond_to?(:[]) and device_or_hash.respond_to?(:keys)
      # Hash-like object.
      device_attributes = device_or_hash
    else
      # ActiveRecord model.
      device_attributes = device_or_hash.attributes
    end
    
    manifest_data = File.read binary_path
    app_fprint_from_raw_data device_attributes, manifest_data
  end    
end  # module CryptoSupportAppFprint

end  # namespace Imobile
