require 'zlib'          # For dealing with zipped logs
require 'aws-sdk-s3'    # Use AWS SDK for S3
require 'aws-sdk-iam'   # Use AWS SDK for IAM
require 'aws-sdk-ecr'   # Use AWS SDK for ECR
require 'fileutils'     # For working with files
require 'ipaddr'        # For working with IP addresses
require 'uri'           # Some AWS responses are URL encoded
require_relative './termite.rb' # Log investigation library
require_relative './utils.rb'   # Simple utilities

#########################################
### Download Logs
#########################################


# Connect to AWS S3
s3 = Aws::S3::Resource.new(region: 'us-east-1')

# # Get all buckets
s3.buckets.each do |bucket|
    # Get S3 objects
    s3.bucket(bucket.name).objects.each do |obj|
        
        # Create path for file
        full_path = "./#{obj.key}"
        dir_path = "./#{obj.key[0..obj.key.rindex('/')]}"
        FileUtils.mkdir_p(dir_path)

        # Download file
        obj.get(response_target: obj.key )

        # Extract file
        Zlib::GzipReader.open(full_path) do |input|
            File.open(full_path[0...full_path.rindex('.')], "w") do |output|
                IO.copy_stream(input, output)
            end
        end

        # Remove original gz file
        File.delete(full_path) if File.exist?(full_path)
    end
end


###########################################
### Search for ANONYMOUS_PRINCIPAL usage
###########################################

termite = Termite.new('AWSLogs')
termite.load_logs

# Find the records of the Anonymous Principal's actions
set_anonymous = termite.query_logs({'userIdentity.accountId' => 'ANONYMOUS_PRINCIPAL'})
unless set_anonymous.length > 0
    puts 'No ANONYMOUS_PRINCIPAL attack detected'
    exit!
else
    puts 'Potential ANONYMOUS_PRINCIPAL attack detected'
end

#########################################################
### Check if ANONYMOUS_PRINCIPAL is actually ok to use
#########################################################

# Find the IP address of the attacker
bad_ip = extract_values(set_anonymous, 'sourceIPAddress').first

# Check if the IP address is an AWS IP
aws_ips = get_aws_ips()
bad_ipaddr = IPAddr.new(bad_ip)
non_aws_ip_alert = false
aws_ips.each do |aws_ip|
    non_aws_ip_alert = true unless aws_ip.include?(bad_ipaddr)
end
if non_aws_ip_alert
    puts "Potential hacker IP discovered: #{bad_ipaddr}"
else
    puts 'ALERT! Hack does not reflect a known pattern'
    exit!
end

######################################
### Find other compromised accounts
######################################

# Find other actions taken by the attacker
hijacked_account_query = {
    'userIdentity.accountId' => /^((?!ANONYMOUS_PRINCIPAL).)*$/,
    'sourceIPAddress' => bad_ip
}
hijacked_account_records = termite.query_logs(hijacked_account_query)

# Extract compromised accounts from logs
user_path = 'userIdentity.sessionContext.sessionIssuer.userName'
hijacked_account_names = extract_values(hijacked_account_records, user_path)

# Check that these accounts should have been using AWS IP addresses
iam = Aws::IAM::Client.new(profile: 'target_security',region: 'us-east-1')
hijacked_account_names.each do |acct|
    # Get level3 role
    level3_role = iam.get_role({role_name: acct})
    # Traverse role -> assume_role_policy_document -> statement -> [0] -> Principal -> 'Service'
        # Different parts of the response need to be URL decoded and parsed as JSON
    allowed_service = JSON.parse(
                        URI.decode(
                            level3_role.to_hash[:role][:assume_role_policy_document]
                        )
                    )['Statement'][0]['Principal']['Service']

    if allowed_service.match(/.*amazonaws.com$/) && non_aws_ip_alert
        puts "Breach detected in role: #{acct}"
    else
        hijacked_account_names.delete(acct)
    end
end

unless hijacked_account_names.length > 0
    puts "No further compromised accounts detected"
end

#############################
### Find compromised repos
#############################

# Search for compromised repos
compromised_repositories = []
hijacked_account_names.each do |acct|
    query = {
        'userIdentity.sessionContext.sessionIssuer.userName' => acct,
        'eventName' => 'ListImages'
    }
    compromised_repositories += extract_values(termite.query_logs(query), 'requestParameters.repositoryName')
end

unless compromised_repositories.length > 0
    puts "No compromised repos found"
    exit!
end

# Check compromised repo policies
ecr = Aws::ECR::Client.new(profile: 'target_security',region: 'us-east-1')

compromised_repositories.each do |repo|
    repo_policy = ecr.get_repository_policy({repository_name: repo})
    principal_policy =  JSON.parse(
                            URI.decode(
                                repo_policy[:policy_text]
                            )
                        )['Statement'].first['Principal']
    if principal_policy == '*'
        puts "Lax policy settings detected in ECR #{repo}: Principal set to *"
    else
        puts "Attack entry point not found... recommend manual investigation"
    end
end