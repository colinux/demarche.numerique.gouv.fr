# frozen_string_literal: true

describe NoPrivateIPURLValidator do
  def record(link)
    record_class = Class.new do
      include ActiveModel::Validations
      attr_accessor :link
      def self.name = 'Record'
    end
    record_class.validates :link, no_private_ip_url: true
    record_class.new.tap { it.link = link }
  end

  [
    'http://127.0.0.1/',
    'http://127.1/',                              # short notation
    'http://2130706433/',                         # decimal
    'http://0x7f.0.0.1/',                         # hexadecimal
    'http://0177.0.0.1/',                         # octal
    'http://[::ffff:127.0.0.1]/',                 # IPv4 mapped in IPv6
    'http://0.0.0.0/',
    'http://10.0.0.5/',
    'http://172.16.0.1/',
    'http://192.168.1.1/',
    'http://169.254.169.254/latest/meta-data/',   # cloud metadata
    'http://100.64.0.1/',                         # carrier-grade NAT
    'http://[::1]/',
    'http://[::]/',
    'http://[fe80::1]/',
    'http://[fc00::1]/',
    'http://localhost/',
    'http://LocalHost:3000/',
    'http://api.localhost/',
    'http://intranet/',                           # a single label only resolves on an internal network
    'http://gitlab:8080/',
    'http://intranet./',
  ].each do |link|
    it "rejects #{link}" do
      invalid = record(link)
      invalid.validate
      expect(invalid.errors).to be_of_kind(:link, :private_ip_url)
    end
  end

  ['https://demarche.numerique.gouv.fr/aide', 'http://93.184.215.14/', 'http://[2606:4700::1111]/'].each do |link|
    it "accepts #{link}" do
      expect(record(link)).to be_valid
    end
  end
end
