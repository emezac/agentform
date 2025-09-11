#!/usr/bin/env ruby
# frozen_string_literal: true

# DNS Propagation Monitor
# This script monitors DNS propagation for mydialogform.com domains

require 'resolv'
require 'net/http'
require 'uri'

def check_dns_resolution(domain)
  puts "🔍 Checking DNS for #{domain}:"
  
  begin
    # Check A records
    a_records = Resolv::DNS.open { |dns| dns.getresources(domain, Resolv::DNS::Resource::IN::A) }
    if a_records.any?
      puts "  A Records:"
      a_records.each { |record| puts "    #{record.address}" }
    end

    # Check CNAME records
    begin
      cname_records = Resolv::DNS.open { |dns| dns.getresources(domain, Resolv::DNS::Resource::IN::CNAME) }
      if cname_records.any?
        puts "  CNAME Records:"
        cname_records.each { |record| puts "    #{record.name}" }
        
        # Check if CNAME points to correct Heroku DNS
        expected_targets = [
          'fluffy-emu-vdwvnqjv8tfby55d1q3ucww9.herokudns.com',
          'secure-macaw-d1cei1l72bc9lischc8brmh7.herokudns.com'
        ]
        
        cname_records.each do |record|
          target = record.name.to_s
          if expected_targets.any? { |expected| target.include?(expected.split('.').first) }
            puts "    ✅ Points to Heroku DNS"
          else
            puts "    ❌ Does not point to expected Heroku DNS"
            puts "    Expected one of: #{expected_targets.join(', ')}"
          end
        end
      end
    rescue => e
      puts "  No CNAME records found"
    end

    if a_records.empty? && cname_records.empty?
      puts "  ❌ No DNS records found"
      return false
    end
    
    return true
    
  rescue => e
    puts "  ❌ DNS lookup failed: #{e.message}"
    return false
  end
end

def check_http_connectivity(domain)
  puts "🌐 Testing HTTP connectivity for #{domain}:"
  
  ['http', 'https'].each do |protocol|
    begin
      uri = URI("#{protocol}://#{domain}")
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (protocol == 'https')
      http.open_timeout = 10
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new('/')
      response = http.request(request)
      
      case response.code.to_i
      when 200
        puts "  ✅ #{protocol.upcase}: #{response.code} - Working"
      when 301, 302
        location = response['location']
        puts "  🔄 #{protocol.upcase}: #{response.code} - Redirect to #{location}"
      when 404
        puts "  ❌ #{protocol.upcase}: #{response.code} - Not Found"
      when 405
        puts "  ⚠️  #{protocol.upcase}: #{response.code} - Method Not Allowed (but server responding)"
      else
        puts "  ⚠️  #{protocol.upcase}: #{response.code} - #{response.message}"
      end
      
    rescue => e
      puts "  ❌ #{protocol.upcase}: Connection failed - #{e.message}"
    end
  end
end

def main
  puts "🌍 DNS Propagation Monitor for mydialogform.com"
  puts "=" * 60
  puts "Timestamp: #{Time.now}"
  puts
  
  domains = ['mydialogform.com', 'www.mydialogform.com']
  
  domains.each do |domain|
    puts "📋 Domain: #{domain}"
    puts "-" * 40
    
    dns_ok = check_dns_resolution(domain)
    puts
    
    if dns_ok
      check_http_connectivity(domain)
    else
      puts "🚫 Skipping HTTP test - DNS not resolved"
    end
    
    puts
  end
  
  puts "🎯 Expected Configuration:"
  puts "  mydialogform.com     → fluffy-emu-vdwvnqjv8tfby55d1q3ucww9.herokudns.com"
  puts "  www.mydialogform.com → secure-macaw-d1cei1l72bc9lischc8brmh7.herokudns.com"
  puts
  
  puts "⏰ DNS Propagation Notes:"
  puts "  - Changes can take 5 minutes to 48 hours"
  puts "  - Try clearing DNS cache: sudo dscacheutil -flushcache (macOS)"
  puts "  - Use different DNS servers to test: 8.8.8.8, 1.1.1.1"
  puts "  - Check propagation globally: https://www.whatsmydns.net/"
end

if __FILE__ == $0
  main
end