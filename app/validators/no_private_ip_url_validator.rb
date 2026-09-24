# frozen_string_literal: true

# Rejects a url whose host is an ip literal of a local or private network, or a
# name only an internal network resolves (localhost, a single label like
# "intranet"). Domain names are not resolved.
class NoPrivateIPURLValidator < ActiveModel::EachValidator
  # what IPAddr#private?, #loopback? and #link_local? leave out
  RESERVED_RANGES = [
    IPAddr.new('0.0.0.0/8'),     # "this network": 0.0.0.0 reaches the host itself
    IPAddr.new('100.64.0.0/10'), # carrier-grade NAT
    IPAddr.new('::/128'),        # unspecified
  ].freeze

  def validate_each(record, attribute, value)
    host = Addressable::URI.parse(value)&.host
    return if host.blank?

    ip = ip_literal(host)
    if ip ? private_ip?(ip) : internal_name?(host)
      record.errors.add(attribute, options[:message] || :private_ip_url)
    end
  rescue Addressable::URI::InvalidURIError
    # not an url, nothing to reach
  end

  private

  def internal_name?(host)
    name = host.downcase.delete_suffix('.')
    !name.include?('.') || name.end_with?('.localhost')
  end

  # The host read as the system reads a numeric one, without any DNS query:
  # 2130706433, 0x7f.0.0.1, 0177.0.0.1 and 127.1 are 127.0.0.1,
  # ::ffff:127.0.0.1 is 127.0.0.1 too.
  def ip_literal(host)
    address = Addrinfo.getaddrinfo(host.delete('[]'), nil, nil, :STREAM, nil, Socket::AI_NUMERICHOST).first.ip_address
    IPAddr.new(address).native
  rescue SocketError
    nil # a domain name
  end

  def private_ip?(ip)
    ip.private? || ip.loopback? || ip.link_local? || RESERVED_RANGES.any? { it.include?(ip) }
  end
end
