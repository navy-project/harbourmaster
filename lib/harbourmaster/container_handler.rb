class Harbourmaster::ContainerHandler
  attr_reader :params
  def handle_set(params, request)
    resolve_desired(params, request.node)
  end

  def handle_delete(params, request)
    resolve_desired(params, request.prevNode)
  end

  private

  def resolve_desired(params, node)
    @params = params
    @logger = params[:logger] || Navy::Logger.new(:channel => "harbourmaster")
    container = case params["type"]
    when "desired"
      build_container_from_node(node)
    when "actual"
      build_container
    end
    machine = build_state_machine(container)
    machine.resolve!
  end

  def debug(message)
    @logger.debug(message)
  end

  def etcd
    @etcd ||= params[:etcd]
  end

  def desired
    return @desired if @desired
    name = params['name']
    key = "/navy/containers/#{name}/desired"
    data = etcd.getJSON(key) 
    raise "No Desired For: #{key}" unless data
    #debug  "Desired: " + data.inspect
    @desired = data
  end

  def specification
    symbolize(desired["specification"])
  end

  def dependencies
    desired["dependencies"]
  end

  def symbolize(h)
    Hash[h.map {|k, v| [k.to_sym, v] }]
  end

  def build_container_from_node(node)
    @desired = JSON.parse(node.value)
    build_container
  end

  def build_container
    Navy::Container.new :specification => specification,
                        :dependencies => dependencies,
                        :logger => @logger
  end

  def build_state_machine(container)
    Harbourmaster::StateMachines::Container.new(container, params[:etcd], :logger => @logger)
  end
end
