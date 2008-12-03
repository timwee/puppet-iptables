module Puppet
  @@rules = {}

  @@current_rules = {}

  @@ordered_rules = {}

  @@table_counters = {
    'filter' => 1,
    'nat'    => 1,
    'mangle' => 1,
    'raw'    => 1
  }

  # pre and post rules are loaded from files
  # pre.iptables post.iptables in /etc/puppet/iptables
  @@pre_file  = "/etc/puppet/iptables/pre.iptables"
  @@post_file = "/etc/puppet/iptables/post.iptables"

  # location where iptables binaries are to be found
  @@iptables_dir = "/sbin"

  @@finalized = false

  @@total_rule_count = 0
  @@instance_count = 0

  newtype(:iptables) do
    @doc = "Manipulate iptables rules"

    newparam(:name) do
      desc "The name of the resource"
      isnamevar
    end

    newparam(:chain) do
      desc "holds value of iptables -A parameter.
                  Possible values are: 'INPUT', 'FORWARD', 'OUTPUT', 'PREROUTING', 'POSTROUTING'.
                  Default value is 'INPUT'"
      newvalues(:INPUT, :FORWARD, :OUTPUT, :PREROUTING, :POSTROUTING)
      defaultto "INPUT"
    end

    newparam(:table) do
      desc "one of the following tables: 'nat', 'mangle',
                  'filter' and 'raw'. Default one is 'filter'"
      newvalues(:nat, :mangle, :filter, :raw)
      defaultto "filter"
    end

    newparam(:proto) do
      desc "holds value of iptables --protocol parameter.
                  Possible values are: 'tcp', 'udp', 'icmp', 'esp', 'ah', 'vrrp', 'all'.
                  Default value is 'all'"
      newvalues(:tcp, :udp, :icmp, :esp, :ah, :vrrp, :all)
      defaultto "all"
    end

    newparam(:jump) do
      desc "holds value of iptables --jump target
                  Possible values are: 'ACCEPT', 'DROP', 'REJECT', 'DNAT', 'LOG'."
      newvalues(:ACCEPT, :DROP, :REJECT, :DNAT, :LOG)
      defaultto "DROP"
    end

    newparam(:source) do
      desc "value for iptables --source parameter"
    end

    newparam(:destination) do
      desc "value for iptables --destination parameter"
    end

    newparam(:sport) do
      desc "holds value of iptables [..] --source-port parameter.
                  Only applies to tcp/udp."
      defaultto ""
    end

    newparam(:dport) do
      desc "holds value of iptables [..] --destination-port parameter.
                  Only applies to tcp/udp."
      defaultto ""
    end

    newparam(:iniface) do
      desc "value for iptables --in-interface parameter"
    end

    newparam(:outiface) do
      desc "value for iptables --out-interface parameter"
    end

    newparam(:todest) do
      desc "value for iptables '-j DNAT --to-destination' parameter"
      defaultto ""
    end

    newparam(:reject) do
      desc "value for iptables '-j REJECT --reject-with' parameter"
      defaultto ""
    end

    newparam(:log_level) do
      desc "value for iptables '-j LOG --log-level' parameter"
      defaultto ""
    end

    newparam(:log_prefix) do
      desc "value for iptables '-j LOG --log-prefix' parameter"
      defaultto ""
    end

    newparam(:icmp) do
      desc "value for iptables '-p icmp --icmp-type' parameter"
      defaultto ""
    end

    newparam(:state) do
      desc "value for iptables '-m state --state' parameter.
                  Possible values are: 'INVALID', 'ESTABLISHED', 'NEW', 'RELATED'."
      newvalues(:INVALID, :ESTABLISHED, :NEW, :RELATED)
    end

    def load_current_rules(numbered = false)
      if( numbered )
        # reset table counters to 0
        @@table_counters = {
          'filter' => 0,
          'nat'    => 0,
          'mangle' => 0,
          'raw'    => 0
        }
      end

      table         = ''
      loaded_rules  = {}
      table_rules   = {}
      counter       = 1

      `#{@@iptables_dir}/iptables-save`.each { |l|
        if /^\*\S+/.match(l)
          table = self.matched(l.scan(/^\*(\S+)/))

          # init loaded_rules hash
          loaded_rules[table] = {} unless loaded_rules[table]
          table_rules = loaded_rules[table]

          # reset counter
          counter = 1

        elsif /^-A/.match(l)
          # matched rule
          chain = self.matched(l.scan(/^-A (\S+)/))

          table = self.matched(l.scan(/-t (\S+)/))
          table = "filter" unless table

          proto = self.matched(l.scan(/-p (\S+)/))
          proto = "all" unless proto

          jump = self.matched(l.scan(/-j (\S+)/))
          jump = "" unless jump

          source = self.matched(l.scan(/-s (\S+)/))
          source = "0.0.0.0/0" unless source

          destination = self.matched(l.scan(/-d (\S+)/))
          destination = "0.0.0.0/0" unless destination

          sport = self.matched(l.scan(/--sport (\S+)/))
          sport = "" unless sport

          dport = self.matched(l.scan(/--dport (\S+)/))
          dport = "" unless dport

          iniface = self.matched(l.scan(/-i (\S+)/))
          iniface = "" unless iniface

          outiface = self.matched(l.scan(/-o (\S+)/))
          outiface = "" unless outiface

          todest = self.matched(l.scan(/--to-destination (\S+)/))
          todest = "" unless todest

          reject = self.matched(l.scan(/--reject-with (\S+)/))
          reject = "" unless reject

          log_level = self.matched(l.scan(/--log-level (\S+)/))
          log_level = "" unless log_level

          log_prefix = self.matched(l.scan(/--log-prefix (\S+)/))
          log_prefix = "" unless log_prefix

          icmp = self.matched(l.scan(/--icmp-type (\S+)/))
          icmp = "" unless icmp

          state = self.matched(l.scan(/--state (\S+)/))
          state = "" unless state

          data = {
            'chain'      => chain,
            'table'      => table,
            'proto'      => proto,
            'jump'       => jump,
            'source'     => source,
            'destination'=> destination,
            'sport'      => sport,
            'dport'      => dport,
            'iniface'    => iniface,
            'outiface'   => outiface,
            'todest'     => todest,
            'reject'     => reject,
            'log_level'  => log_level,
            'log_prefix' => log_prefix,
            'icmp'       => icmp,
            'state'      => state
          }

          if( numbered )
            table_rules[counter.to_s + " " +l.strip] = data

            # we also set table counters to indicate amount
            # of current rules in each table, that will be needed if
            # we decide to refresh them
            @@table_counters[table] += 1
          else
            table_rules[l.strip] = data
          end

          counter += 1
        end
      }
      return loaded_rules
    end

    def matched(data)
      if data.instance_of?(Array)
        data.each { |s|
          if s.instance_of?(Array)
            s.each { |z|
              return z.to_s
            }
          else

            return s.to_s
          end
        }
      end
      nil
    end

    # Fix this function
    def load_rules_from_file(rules, file_name, action)
      if File.exist?(file_name)
        counter = 0
        File.open(file_name, "r") do |infile|
          while (line = infile.gets)
            next unless /^\s*[^\s#]/.match(line.strip)
            table = line[/-t\s+\S+/]
            table = "-t filter" unless table
            table.sub!(/^-t\s+/, '')
            rules[table] = [] unless rules[table]
            rule =
              { 'table'         => table,
                'full rule'     => line.strip,
                'alt rule'      => line.strip}

            if( action == :prepend )
              rules[table].insert(counter, rule)
            else
              rules[table].push(rule)
            end

            counter += 1
          end
        end
      end
    end

    def reorder_rules()
      table = {}

      @@rules.each_key {|key|
        table[key] = {}

        @@rules[key].each {|full_rule|

          rule = {}
          # these 3 parameters seem to be sufficient for what's left to do.
          rule["name"] = full_rule["name"]
          rule["alt rule"] = full_rule["alt rule"]
          rule["full rule"] = full_rule["full rule"]
          table[key][@@ordered_rules[full_rule["name"]]] = rule

          all_keys = []
          table[key].each_key {|idx|
            all_keys.push(idx)
          }
          all_keys = all_keys.sort

          @@rules[key] = []
          all_keys.each {|idx|
            @@rules[key].push(table[key][idx])
          }
        }
      }
    end

    def finalize
      # sort rules in the order imposed by defined dependencies.
      reorder_rules()
      # load pre and post rules
      load_rules_from_file(@@rules, @@pre_file, :prepend)
      load_rules_from_file(@@rules, @@post_file, :append)

      # add numbered version to each rule
      @@table_counters.each_key { |table|
        rules_to_set = @@rules[table]
        if rules_to_set
          counter = 1
          rules_to_set.each { |rule|
            rule['numbered rule'] = counter.to_s + " "+rule["full rule"]
            rule['altned rule']   = counter.to_s + " "+rule["alt rule"]
            counter += 1
          }
        end
      }

      # On the first round we delete rules which do not match what
      # we want to set. We have to do it in the loop until we
      # exhaust all rules, as some of them may appear as multiple times
      while self.delete_not_matched_rules > 0
      end

      # Now we need to take care of rules which are new or out of order.
      # The way we do it is that if we find any difference with the
      # current rules, we add all new ones and remove all old ones.
      if self.rules_are_different
        # load new new rules
        benchmark(:notice, "rules have changed...") do
          # load new rules
          @@table_counters.each { |table, total_do_delete|
            rules_to_set = @@rules[table]
            if rules_to_set
              rules_to_set.each { |rule_to_set|
                debug("Running 'iptables -t #{table} #{rule_to_set['alt rule']}'")
                `#{@@iptables_dir}/iptables -t #{table} #{rule_to_set['alt rule']}`
              }
            end
          }

          # delete old rules
          @@table_counters.each { |table, total_do_delete|
            current_table_rules = @@current_rules[table]
            if current_table_rules
              current_table_rules.each { |rule, data|
                debug("Running 'iptables -t #{table} -D #{data['chain']} 1'")
                `#{@@iptables_dir}/iptables -t #{table} -D #{data['chain']} 1`
              }
            end
          }
        end

        @@rules = {}
      end

      @@finalized = true
    end

    def finalized?
      if defined? @@finalized
        return @@finalized
      else
        return false
      end
    end

    def rules_are_different
      # load current rules
      @@current_rules = self.load_current_rules(true)

      @@table_counters.each_key { |table|
        rules_to_set = @@rules[table]
        current_table_rules = @@current_rules[table]
        current_table_rules = {} unless current_table_rules
        if rules_to_set
          rules_to_set.each { |rule_to_set|
            return true unless current_table_rules[rule_to_set['numbered rule']] or current_table_rules[rule_to_set['altned rule']]
          }
        end
      }

      return false
    end

    def delete_not_matched_rules
      # load current rules
      @@current_rules = self.load_current_rules

      # count deleted rules from current active
      deleted = 0;

      # compare current rules with requested set
      @@table_counters.each_key { |table|
        rules_to_set = @@rules[table]
        current_table_rules = @@current_rules[table]
        if rules_to_set
          if current_table_rules
            rules_to_set.each { |rule_to_set|
              full_rule = rule_to_set['full rule']
              alt_rule  = rule_to_set['alt rule']
              if    current_table_rules[full_rule]
                current_table_rules[full_rule]['keep'] = 'me'
              elsif current_table_rules[alt_rule]
                current_table_rules[alt_rule]['keep']  = 'me'
              end
            }
          end
        end

        # delete rules not marked with "keep" => "me"
        if current_table_rules
          current_table_rules.each { |rule, data|
            if data['keep']
            else
              debug("Running 'iptables -t #{table} #{rule.sub('-A', '-D')}'")
              `#{@@iptables_dir}/iptables -t #{table} #{rule.sub("-A", "-D")}`
              deleted += 1
            end
          }
        end
      }
      return deleted
    end

    def evaluate
      @@ordered_rules[self.name] = @@instance_count
      @@instance_count += 1

      if @@instance_count == @@total_rule_count
        self.finalize unless self.finalized?
      end
      return super
    end

    def self.clear
      @@rules = {}

      @@current_rules = {}

      @@ordered_rules = {}

      @@total_rule_count = false

      @@instance_count = false

      @@table_counters = {
        'filter' => 1,
        'nat'    => 1,
        'mangle' => 1,
        'raw'    => 1
      }

      @@finalized = false
      super
    end


    def initialize(args)
      super(args)

      invalidrule = false
      @@total_rule_count += 1

      table = value(:table).to_s
      @@rules[table] = [] unless @@rules[table]

      if value(:table).to_s == "filter" and ["PREROUTING", "POSTROUTING"].include?(value(:chain).to_s)
        invalidrule = true
        err("PREROUTING and POSTROUTING cannot be used in table 'filter'. Ignoring rule.")
      elsif  value(:table).to_s == "nat" and ["INPUT", "FORWARD"].include?(value(:chain).to_s)
        invalidrule = true
        err("INPUT and FORWARD cannot be used in table 'nat'. Ignoring rule.")
      elsif  value(:table).to_s == "raw" and ["INPUT", "FORWARD", "POSTROUTING"].include?(value(:chain).to_s)
        invalidrule = true
        err("INPUT, FORWARD and POSTROUTING cannot be used in table 'raw'. Ignoring rule.")
      else
        full_string = "-A " + value(:chain).to_s
      end

      if value(:source).to_s != ""
        full_string += " -s " + value(:source).to_s
      end
      if value(:destination).to_s != ""
        full_string += " -d " + value(:destination).to_s
      end

      if value(:iniface).to_s != ""
        if ["INPUT", "FORWARD", "PREROUTING"].include?(value(:chain).to_s)
          full_string += " -i " + value(:iniface).to_s
        else
          invalidrule = true
          err("--in-interface only applies to INPUT/FORWARD/PREROUTING. Ignoring rule.")
        end
      end
      if value(:outiface).to_s != ""
        if ["OUTPUT", "FORWARD", "POSTROUTING"].include?(value(:chain).to_s)
          full_string += " -o " + value(:outiface).to_s
        else
          invalidrule = true
          err("--out-interface only applies to OUTPUT/FORWARD/POSTROUTING. Ignoring rule.")
        end
      end

      alt_string  = full_string

      if value(:proto).to_s != "all"
        alt_string  += " -p " + value(:proto).to_s
        full_string += " -p " + value(:proto).to_s
        if value(:proto).to_s != "vrrp"
          alt_string += " -m " + value(:proto).to_s
        end
      end

      if value(:dport).to_s != ""
        if ["tcp", "udp"].include?(value(:proto).to_s)
          full_string += " --dport " + value(:dport).to_s
          alt_string  += " --dport " + value(:dport).to_s
        else
          invalidrule = true
          err("--destination-port only applies to tcp/udp. Ignoring rule.")
        end
      end
      if value(:sport).to_s != ""
        if ["tcp", "udp"].include?(value(:proto).to_s)
          full_string += " --sport " + value(:sport).to_s
          alt_string  += " --sport " + value(:sport).to_s
        else
          invalidrule = true
          err("--source-port only applies to tcp/udp. Ignoring rule.")
        end
      end

      if value(:icmp).to_s != ""
        if value(:proto).to_s != "icmp"
          invalidrule = true
          err("--icmp-type only applies to icmp. Ignoring rule.")
        else
          full_string += " --icmp-type " + value(:icmp).to_s
          alt_string += " --icmp-type " + value(:icmp).to_s
        end
      end

      if value(:state).to_s != ""
        full_string += " -m state --state " + value(:state).to_s
        alt_string += " -m state --state " + value(:state).to_s
      end

      full_string += " -j " + value(:jump).to_s
      alt_string += " -j " + value(:jump).to_s

      if value(:jump).to_s == "DNAT"
        if value(:table).to_s != "nat"
          invalidrule = true
          err("DNAT only applies to table 'nat'.")
        elsif value(:todest).to_s == ""
          invalidrule = true
          err("DNAT missing mandatory 'todest' parameter.")
        else
          full_string += " --to-destination " + value(:todest).to_s
          alt_string += " --to-destination " + value(:todest).to_s
        end
      elsif value(:jump).to_s == "REJECT"
        if value(:reject).to_s != ""
          full_string += " --reject-with " + value(:reject).to_s
          alt_string += " --reject-with " + value(:reject).to_s
        end
      elsif value(:jump).to_s == "LOG"
        if value(:log_level).to_s != ""
          full_string += " --log-level " + value(:log_level).to_s
          alt_string += " --log-level " + value(:log_level).to_s
        end
        if value(:log_prefix).to_s != ""
          # --log-prefix has a 29 characters limitation.
          log_prefix = "\"" + value(:log_prefix).to_s[0,27] + ": \""
          full_string += " --log-prefix " + log_prefix
          alt_string += " --log-prefix " + log_prefix
        end
      end

      debug("iptables param: #{full_string}")

      if invalidrule != true
        @@rules[table].
          push({ 'name'          => value(:name).to_s,
                 'chain'         => value(:chain).to_s,
                 'table'         => value(:table).to_s,
                 'proto'         => value(:proto).to_s,
                 'jump'          => value(:jump).to_s,
                 'source'        => value(:source).to_s,
                 'destination'   => value(:destination).to_s,
                 'sport'         => value(:sport).to_s,
                 'dport'         => value(:dport).to_s,
                 'iniface'       => value(:iniface).to_s,
                 'outiface'      => value(:outiface).to_s,
                 'todest'        => value(:todest).to_s,
                 'reject'        => value(:reject).to_s,
                 'log_level'     => value(:log_level).to_s,
                 'log_prefix'    => value(:log_prefix).to_s,
                 'icmp'          => value(:icmp).to_s,
                 'state'         => value(:state).to_s,
                 'full rule'     => full_string,
                 'alt rule'      => alt_string})
      end
    end
  end
end