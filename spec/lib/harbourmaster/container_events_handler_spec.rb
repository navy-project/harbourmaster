require 'spec_helper'
require 'mock_etcd'

describe Harbourmaster::ContainerEventsHandler do
  let(:etcd) { MockEtcd.new }

  let(:params) do
    {
      :env => 'theenv',
      'convoyid' => 'aconvoyid',
      'id' => '1234',
      :etcd => etcd
    }
  end

  let(:node) { double(:value => message.to_json) }
  let(:request) { double :node => node, :key => '/some/key' }

  describe "#handle_create" do
    describe ":die event" do
      let(:message) do
        {
          :event => :die,
          :name => 'the_container'
        }
      end

      context "when the container should not be missing" do
        before :each do
          etcd.setJSON("/navy/containers/the_container/actual", {:some => :state})
          subject.handle_create(params, request)
        end

        it "deletes the actual state for the container" do
          actual = etcd.getJSON("/navy/containers/the_container/actual")
          expect(actual).to eq nil
        end
      end


      context "when the desired state is 'completed'" do
        before :each do
          etcd.setJSON("/navy/containers/the_container/desired", {:state => :completed})
          etcd.setJSON("/navy/containers/the_container/actual", {:some => :state})
          subject.handle_create(params, request)
        end

        it "the container was expected to die" do
          actual = etcd.getJSON("/navy/containers/the_container/actual")
          expect(actual).to eq({"some" => "state"})
        end
      end

    end

    describe "other events" do
      let(:message) do
        {
          :event => :someotherevent,
          :name => 'the_container'
        }
      end

      before :each do
        etcd.setJSON("/navy/containers/the_container/actual", {:some => :state})
        subject.handle_create(params, request)
      end

      it "are ignored" do
        actual = etcd.getJSON("/navy/containers/the_container/actual")
        expect(actual).to eq({"some" => "state"})
      end
    end

  end
end
