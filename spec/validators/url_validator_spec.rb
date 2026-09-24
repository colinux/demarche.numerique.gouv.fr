# frozen_string_literal: true

describe URLValidator do
  def record(link, **options)
    record_class = Class.new do
      include ActiveModel::Validations
      attr_accessor :link
      def self.name = 'Record'
    end
    record_class.validates :link, url: options.presence || true
    record_class.new.tap { it.link = link }
  end

  ['https://demarche.numerique.gouv.fr/aide', 'http://example.com', 'HTTPS://example.com', 'https://www.démarches-simplifiées.fr', 'http://93.184.215.14/', 'http://[2606:4700::1111]/'].each do |link|
    it "accepts #{link}" do
      expect(record(link)).to be_valid
    end
  end

  ['www.example.com', 'ftp://example.com', 'https://exa mple.com', 'dpo@example.com'].each do |link|
    it "rejects #{link}" do
      invalid = record(link)
      invalid.validate
      expect(invalid.errors).to be_of_kind(:link, :url)
    end
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
    it "rejects the local or private #{link}" do
      invalid = record(link)
      invalid.validate
      expect(invalid.errors).to be_of_kind(:link, :private_ip_url)
    end
  end

  # a dotted host does not make a javascript: link an url: once clicked,
  # "//" opens a comment and the encoded newline closes it
  it 'rejects a javascript link with a host, with or without accept_email' do
    [{}, { accept_email: true }].each do |options|
      invalid = record('javascript://example.com/%0Aalert(document.domain)', **options)
      invalid.validate
      expect(invalid.errors).to be_of_kind(:link, :url)
    end
  end

  context 'with accept_email' do
    ['dpo@example.com', 'dpo@démarches-simplifiées.fr', 'https://example.com/dpo'].each do |link|
      it "accepts #{link}" do
        expect(record(link, accept_email: true)).to be_valid
      end
    end

    [
      # not one plain email
      ' dpo@example.com ',
      'dpo@example.com ; rgpd@example.com',
      'mailto:dpo@example.com',
      # script links passed off as emails by an @
      'javascript:alert(window.location)//@example.com',
      'JaVaScRiPt:alert(1)//@example.com',
      ' javascript:alert(1)//@example.com',
      "\u0000javascript:alert(1)//@example.com",
      "java\tscript:alert(1)//@example.com",
      "java\nscript:alert(1)//@example.com",
      'javascript&#58;alert(1)//@example.com',
      'javascript:/*@example.com*/alert(1)',
      'javascript:alert(1)?@example.com',
      'javascript://x@example.com/%0Aalert(1)',
      'vbscript:msgbox(1)//@example.com',
      'data:text/html,<script>alert(1)</script>@example.com',
      'data:image/svg+xml,<svg onload=alert(1)>@example.com',
    ].each do |link|
      it "rejects #{link.inspect}" do
        invalid = record(link, accept_email: true)
        invalid.validate
        expect(invalid.errors).to be_of_kind(:link, :url)
      end
    end
  end
end
