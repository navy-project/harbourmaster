require 'spec_helper'
require 'mock_etcd'

describe Harbourmaster::StateMachines::Container do
  let(:etcd) { MockEtcd.new }

  let(:container) do
    double(:dependencies => [],
           :specification => [],
           :name => 'the_container_name',
           :can_never_be_started? => false
          )
  end

  subject{ described_class.new(container, etcd) }

  let(:desired_key) { "/navy/containers/#{container.name}/desired" }
  let(:actual_key) { "/navy/containers/#{container.name}/actual" }


  describe "Current State" do
    context "when actual key is missing" do
      it "is missing" do
        expect(subject.current_state).to eq :missing
        expect(subject).to be_missing
      end
    end

    context "when actual state is set" do
      before :each do
        etcd.setJSON(actual_key, {:state => :desired})
      end

      it "is the stored state" do
        expect(subject.current_state).to eq :desired
      end
    end
  end

  describe "#desired?" do
    context "when actual matches desired" do
      before :each do
        etcd.setJSON(actual_key, {:state => :actual})
        etcd.setJSON(desired_key, {:state => :actual})
      end

      it "is desired" do
        expect(subject).to be_desired
      end
    end

    context "when actual does not match desired" do
      before :each do
        etcd.setJSON(actual_key, {:state => :actual})
        etcd.setJSON(desired_key, {:state => :desired})
      end

      it "is NOT desired" do
        expect(subject).to_not be_desired
      end
    end
  end

  describe "#resolve!" do
    before :each do
      etcd.setJSON(desired_key, {:state => :running})
    end

    context "when not desired" do
      context "and the container can be started" do
        context "and desired is to be running/run" do
          before :each do
            allow(container).to receive(:can_be_started?).with(etcd) { true }
          end

          it "should start the container" do
            expect(container).to receive(:start)
            subject.resolve!
          end
        end

        context "and the desired is to be missing" do
          before :each do
            etcd.setJSON(actual_key, {:state => :running})
            etcd.delete(desired_key)
          end

          it "should stop the container" do
            expect(container).to receive(:stop)
            subject.resolve!
            actual = etcd.getJSON(actual_key)
            expect(actual).to be_nil
          end
        end
      end

      context "and the container cannot be started" do
        before :each do
          allow(container).to receive(:can_be_started?).with(etcd) { false }
        end

        it "sets the state to waiting" do
          subject.resolve!

          expect(subject).to be_waiting
          actual = etcd.getJSON(actual_key)
          expect(actual["state"]).to eq "waiting"
        end
      end

      context "and the container can *never* be started" do
        before :each do
          allow(container).to receive(:can_be_started?).with(etcd) { false }
          allow(container).to receive(:can_never_be_started?).with(etcd) { true }
        end

        it "sets the state to error" do
          subject.resolve!

          expect(subject).to be_error
          actual = etcd.getJSON(actual_key)
          expect(actual["state"]).to eq "error"
        end
      end
    end

    context "when desired" do
      before :each do
        etcd.setJSON(actual_key, {:state => :running})
      end

      it "does not attempt to resolve" do
        expect(container).to_not receive(:start)
        subject.resolve!
      end
    end

    context "when error" do
      before :each do
        etcd.setJSON(actual_key, {:state => :error})
      end

      it "does not attempt to resolve" do
        expect(container).to_not receive(:start)
        subject.resolve!
      end
    end

    context "when running" do
      before :each do
        etcd.setJSON(actual_key, {:state => :running})
      end
    end

    context "when starting the container" do
      before :each do
        allow(container).to receive(:can_be_started?) { true }
      end

      context "when the start succeeds" do
        before :each do
          allow(container).to receive(:start) { true }
          allow(container).to receive(:daemon?) { true }
          etcd.setJSON(desired_key, {:state => :running, :dependencies => [:adep], :specification => {:a => :spec}})
        end

        it "sets the state to 'running'" do
          subject.resolve!

          expect(subject).to be_running
          actual = etcd.getJSON(actual_key)
          expect(actual["state"]).to eq "running"
        end

        it "includes the specification of the desired container" do
          subject.resolve!

          expect(subject).to be_running
          actual = etcd.getJSON(actual_key)
          desired = etcd.getJSON(desired_key)
          expect(actual["dependencies"]).to eq desired["dependencies"]
          expect(actual["specification"]).to eq desired["specification"]
        end

        context "when the container is a task" do
          before :each do
            allow(container).to receive(:daemon?) { false }
          end

          it "sets the state to 'completed'" do
            subject.resolve!

            actual = etcd.getJSON(actual_key)
            expect(actual["state"]).to eq "completed"
          end
        end
      end

      context "when the start fails" do
        before :each do
          allow(container).to receive(:start) { false }
        end

        it "sets the state to error" do
          subject.resolve!

          expect(subject).to be_error
          actual = etcd.getJSON(actual_key)
          expect(actual["state"]).to eq "error"
        end
      end
    end
  end
    
end
