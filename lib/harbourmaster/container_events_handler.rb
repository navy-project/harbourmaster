module Harbourmaster
  class ContainerEventsHandler
    HANDLER_FUNCS = {
      "die" => "handle_die"
    }

    def handle_create(params, request)
      etcd = params[:etcd]
      message = extract_message(request)
      func = HANDLER_FUNCS[message["event"]]
      if func
        public_send(func, etcd, message["name"])
      end
    end

    def handle_die(etcd, name)
      mark_deleted(etcd, name) unless desired_completed?(etcd, name)
    end

    private

    def extract_message(request)
      JSON.parse(request.node.value)
    end

    def mark_deleted(etcd, name)
      etcd.delete("/navy/containers/#{name}/actual")
    end

    def desired_completed?(etcd, name)
      desired = etcd.getJSON("/navy/containers/#{name}/desired")
      puts "Desired Completed?", desired.inspect, (desired && desired["state"] == "completed")
      desired && desired["state"] == "completed"
    end
  end
end
