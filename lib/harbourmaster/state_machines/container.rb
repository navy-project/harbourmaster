module Harbourmaster::StateMachines
  class Base
    def self.states(*states)
      states.each do |state|
        define_method("#{state}?") do
          current_state == state
        end
      end
    end
  end

  class Container < Base 
    attr_reader :container, :etcd

    states :missing, :waiting, :error, :running

    def initialize(container, etcd, options={})
      @container=container
      @etcd=etcd
      @logger = options[:logger] || Navy::Logger.new
      determine_states
    end

    def current_state
      @current_state.to_sym
    end

    def desired?
      #debug "Desired?"
      #debug "   > " + @desired.inspect
      #debug "vs > " + @current.inspect
      @desired_state == @current_state
    end

    def resolve!
      #debug "Resolving..."
      return if desired? || error?
      if container_should_be_stopped?
        stop
      elsif container.can_be_started?(etcd)
        start
      else
        if container.can_never_be_started?(etcd)
          error
        else
          wait
        end
      end
    end

    private

    def debug(message)
      @logger.debug message
    end

    def desired_options
      {
        :dependencies => @desired["dependencies"],
        :specification => @desired["specification"]
      }
    end

    def container_should_be_stopped?
      @desired_state == "missing"
    end

    def start
      #debug "Starting..."
      if container.start
        if container.daemon?
          update_actual("running", desired_options)
        else
          update_actual("completed", desired_options)
        end
      else
        error
      end
    end

    def stop
      container.stop
      delete_actual
    end

    def wait
      #debug "Waiting..."
      sleep 0.1
      update_actual("waiting")
    end

    def error
      #debug "Error :("
      update_actual("error")
    end

    def update_actual(newstate, spec = {})
      @current_state = newstate
      spec = spec.merge({:state => newstate})
      etcd.setJSON(actual_key, spec)
    end

    def delete_actual
      etcd.delete(actual_key)
    end

    def determine_states
      @desired = etcd.getJSON(desired_key) || {}
      @actual = etcd.getJSON(actual_key) || {}
      @current_state = @actual["state"] || "missing"
      @desired_state = @desired["state"] || "missing"
    end

    def gen_key(statetype)
      "/navy/containers/#{container.name}/#{statetype}"
    end

    def desired_key
      gen_key(:desired)
    end

    def actual_key
      gen_key(:actual)
    end

  end
end
