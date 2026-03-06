require "rails_helper"

RSpec.describe PitchesController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/pitches").to route_to("pitches#index")
    end

    it "routes to #new" do
      expect(get: "/pitches/new").to route_to("pitches#new")
    end

    it "routes to #show" do
      expect(get: "/pitches/1").to route_to("pitches#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/pitches/1/edit").to route_to("pitches#edit", id: "1")
    end

    it "routes to #create" do
      expect(post: "/pitches").to route_to("pitches#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/pitches/1").to route_to("pitches#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/pitches/1").to route_to("pitches#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/pitches/1").to route_to("pitches#destroy", id: "1")
    end

    it "routes to #transition via PATCH" do
      expect(patch: "/pitches/1/transition").to route_to("pitches#transition", id: "1")
    end

    it "routes to #bet via POST" do
      expect(post: "/pitches/1/bet").to route_to("pitches#bet", id: "1")
    end
  end
end
