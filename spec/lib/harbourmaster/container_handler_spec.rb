require 'spec_helper'
require 'mock_etcd'

describe Harbourmaster::ContainerHandler do
  let(:etcd) { MockEtcd.new }

  let(:desired) do
    {
      :state => :running,
      :dependencies => [:dep1, :dep2],
      :specification => {
        :container_name => "container_name",
        :name => "app_name"
      }
    }
  end


  let(:state_machine) { Harbourmaster::StateMachines::Container }

  describe "#handle_set" do
    let(:node) { double(:value => desired.to_json) }
    let(:request) { double :node => node, :key => '/some/key' }

    context "of desired" do
      let(:params) do
        {
          :env => 'theenv',
          'convoyid' => 'aconvoyid',
          'name' => 'container_name',
          'type' => 'desired',
          :etcd => etcd
        }
      end

      it "passes an container representing the given desired to the state machine" do
        machine = double

        expect(state_machine).to receive(:new) do |container, e|
          expect(e).to be etcd
          expect(container.name).to eq 'container_name'
          expect(container.app).to eq 'app_name'
          expect(container.dependencies).to eq ["dep1", "dep2"]
          machine
        end

        expect(machine).to receive(:resolve!)

        subject.handle_set(params, request)
      end
    end

    context "of actual" do

      before :each do
        etcd.setJSON('/navy/containers/container_name/desired', desired)
      end

      let(:params) do
        {
          :env => 'theenv',
          'convoyid' => 'aconvoyid',
          'name' => 'container_name',
          'type' => 'actual',
          :etcd => etcd
        }
      end

      it "passes an container representing the known desired to the state machine" do
        machine = double

        expect(state_machine).to receive(:new) do |container, e|
          expect(e).to be etcd
          expect(container.name).to eq 'container_name'
          expect(container.app).to eq 'app_name'
          expect(container.dependencies).to eq ["dep1", "dep2"]
          machine
        end

        expect(machine).to receive(:resolve!)

        subject.handle_set(params, request)
      end
    end
  end

  describe "#handle_delete" do
    let(:node) { double(:value => desired.to_json) }
    let(:request) { double :prevNode => node, :key => '/some/key' }

    let(:params) do
      {
        :env => 'theenv',
        'convoyid' => 'aconvoyid',
        'name' => 'container_name',
        'type' => 'desired',
        :etcd => etcd
      }
    end

    it "passes an container representing the node to the state machine" do
      machine = double

      expect(state_machine).to receive(:new) do |container, e|
        expect(e).to be etcd
        expect(container.name).to eq 'container_name'
        expect(container.app).to eq 'app_name'
        expect(container.dependencies).to eq ["dep1", "dep2"]
        machine
      end

      expect(machine).to receive(:resolve!)

      subject.handle_delete(params, request)
    end
  end
end
