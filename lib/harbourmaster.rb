require "harbourmaster/version"
require 'navy'

module Harbourmaster
  autoload :StateMachines, 'harbourmaster/state_machines'
  autoload :ContainerHandler, 'harbourmaster/container_handler'
  autoload :DesiredQueueHandler, 'harbourmaster/desired_queue_handler'
  autoload :ContainerEventsHandler, 'harbourmaster/container_events_handler'
end
