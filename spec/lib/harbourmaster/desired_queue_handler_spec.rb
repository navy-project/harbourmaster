require 'spec_helper'
require 'mock_etcd'

describe Harbourmaster::DesiredQueueHandler do
  let(:etcd) { MockEtcd.new }

  let(:params) do
    {
      :env => 'theenv',
      'convoyid' => 'aconvoyid',
      'id' => '1234',
      :etcd => etcd
    }
  end

  let(:desired) do
    {
      "state" => "a state",
      "dependencies" => ["some", "deps"],
      "specification" => {
        "container_name" => "the_container",
        "other" => "things"
      }
    }
  end

  let(:node) { double(:value => message.to_json) }
  let(:request) { double :node => node, :key => '/some/key' }

  describe "#handle_create" do
    describe ":create request" do
      let(:message) do
        {
          :request => :create,
          :name => 'the_container',
          :desired => desired
        }
      end

      context "when the queue item is consumed" do
        before :each do
          etcd.set('/navy/queues/containers/1234', "[]")
          subject.handle_create(params, request)
        end

        it "sets the desired state for the item" do
          set_desired = etcd.getJSON("/navy/containers/the_container/desired")
          expect(set_desired).to eq desired
        end

        it "consumes the item within the queue" do
          item = etcd.getJSON('/navy/queues/containers/1234')
          expect(item).to be_nil
        end
      end


      context "when the queue item has already been deleted" do
        it "assumes another process handled the item" do
          set_desired = etcd.getJSON("/navy/containers/the_container/desired")
          expect(set_desired).to be_nil
        end
      end
    end

    describe ":destroy request" do
      let(:message) do
        {
          :request => :destroy,
          :name => 'the_container'
        }
      end

      before :each do
        etcd.set('/navy/queues/containers/1234', "[]")
        etcd.setJSON("/navy/containers/the_container/desired", [])
        subject.handle_create(params, request)
      end

      it "deletes the desired state for the item" do
        etcd_desired = etcd.getJSON("/navy/containers/the_container/desired")
        expect(etcd_desired).to be_nil
      end

    end
  end
end
