require 'json'  # Parse JSON

############################################
### TERMITE (because it digs into logs!) ###
############################################

class Termite
    attr_accessor :log_dir
    attr_reader :logs

    def initialize(log_dir)
        @log_dir = log_dir
        @logs = []
    end

    # This function reads logs into memory. It will find all .json files recursively in
    # the specified directory and store them in the class instance.
    def load_logs
        # Find all downloaded json logs
        files = Dir.glob(File.join(log_dir, "**", "*.json"))
    
        # Work through each discovered log file
        results = []
        files.each do |file|
            # Read file line by line
            text = ""
            File.open(file, "r") do |f|
                f.each_line do |line|
                    text += line
                end
            end
    
            # Once all lines are collected, parse string as JSON and store as Hash
            results += JSON.parse(text)['Records']
        end
        @logs = results
    end

    # query_logs returns filtered logs. The f(n) expects a hash object whose keys represent
    # the fields to be validated and values represent the value to be matched in the log.
    # For JSON embedded objects, a path given in the hash key will traverse the log object
    # to the correct location.  Multiple keys in the hash will work as an AND filter.
    # The hash values can be REGEX or strings.

    # EG
    # query = {
    #     'userIdentity.accountId' => /^ANONYMOUS.*/,
    #     'sourceIPAddress' => '104.102.221.250'
    # }
    def query_logs(query)
        results = []
        @logs.each.with_index do |record, i|
            matched = true

            # Validate each query key/value pair
            query.keys.each do |query_key|
                # Traverse the embedded objects to find the correct value
                begin
                    value = query_key.split(".").inject(record) { |hash, key| hash[key] } || ""
                rescue
                    value = ""
                end

                # Validate the found value
                matched = false unless value.match(query[query_key])
            end

            # Add record if record matched query
            results << record if matched
        end
    
        return results
    end
end