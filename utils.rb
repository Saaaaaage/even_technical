require 'open-uri'  # API requests
require 'json'      # Parse JOSN
require 'ipaddr'    # Work with IPs

# Summarize some logs to find frequency of values in a field
def summarize_field(records, field)
    extracted = Hash.new(0)
    records.each do |record|
        begin
            value = field.split(".").inject(record) { |hash, key| hash[key] }
        rescue
            value = 'no such field'
        end
        extracted[value] += 1
    end
    return extracted
end

# Just grab keys from the summary function - gives field values
def extract_values(records, field)
    summarize_field(records, field).keys
end

# Retrieve AWS IP info, return array of AWS IPv4 IPs
def get_aws_ips()
    content = open("https://ip-ranges.amazonaws.com/ip-ranges.json").read
    resp = JSON.parse(content)['prefixes']
    ips = []
    resp.each do |prefix|
        ips << IPAddr.new(prefix['ip_prefix'])
    end
    return ips
end