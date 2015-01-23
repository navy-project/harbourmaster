class Harbourmaster::DesiredQueueHandler
  attr_reader :etcd

  def handle_create(params, request)
    @etcd = params[:etcd]
    consume_message(params, request) do |message|
      name = message["name"]
      logger = params[:logger] || Navy::Logger.new(:channel => "harbourmaster")
      logger.trace "#{message["request"]}: #{name}"
      case message["request"]
      when "create"
        desired = message["desired"]
        update_desired_state(name, desired)
      when "destroy"
        delete_desired_state(name)
      end
    end
  end

  private

  def consume_message(params, request)
    id = params["id"]
    message = JSON.parse(request.node.value)
    yield message if etcd.delete("/navy/queues/containers/#{id}")
  end

  def update_desired_state(name, desired)
    key = make_key(name)
    etcd.setJSON(key, desired)
  end

  def delete_desired_state(name)
    key = make_key(name)
    etcd.delete(key)
  end

  def make_key(name)
    "/navy/containers/#{name}/desired"
  end
end
