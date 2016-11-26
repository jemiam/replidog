require "spec_helper"

describe Replidog::Proxy do
  before do
    ActiveRecord::Base.establish_connection
    UserTable.establish_connection :test_user
  end

  describe "#transaction" do
    context "without using" do
      it "executes SQL query on master connection" do
        Recipe.using(:slave1).create(title: "test")
        Recipe.using(:slave2).create(title: "test")
        Recipe.using(:slave3).create(title: "test")
        Recipe.transaction do
          expect(Recipe.first).to be_nil
        end
      end
    end

    context "with using slave name" do
      it "executes SQL query on slave connection" do
        Recipe.using(:slave1).create(title: "test")
        Recipe.using(:slave1).transaction do
          expect(Recipe.first).not_to be_nil
        end
      end
    end
  end

  describe "#lock" do
    context "without using" do
      it "executes SQL query on master connection" do
        Recipe.using(:slave1).create(title: "test")
        Recipe.using(:slave2).create(title: "test")
        Recipe.using(:slave3).create(title: "test")
        Recipe.lock do
          expect(Recipe.first).to be_nil
        end
      end
    end

    context "with using slave name" do
      it "executes SQL query on slave connection" do
        Recipe.using(:slave1).create(title: "test")
        Recipe.using(:slave1).lock do
          expect(Recipe.first).not_to be_nil
        end
      end
    end
  end

  describe "#enable_query_cache!" do
    it "enables query cache of all connections" do
      expect{ Recipe.connection.enable_query_cache! }
        .to change { Recipe.using(:master).connection.query_cache_enabled }.from(false).to(true)
        .and change { Recipe.using(:slave1).connection.query_cache_enabled }.from(false).to(true)
        .and change { Recipe.using(:slave2).connection.query_cache_enabled }.from(false).to(true)
        .and change { Recipe.using(:slave3).connection.query_cache_enabled }.from(false).to(true)
        .and change { User.using(:master).connection.query_cache_enabled }.from(false).to(true)
        .and change { User.using(:slave).connection.query_cache_enabled }.from(false).to(true)
    end
  end

  describe "#disable_query_cache!" do
    before do
      ActiveRecord::Base.connection.enable_query_cache!
    end

    it "disables query cache of all connections" do
      expect{ Recipe.connection.disable_query_cache! }
        .to change { Recipe.using(:master).connection.query_cache_enabled }.from(true).to(false)
        .and change { Recipe.using(:slave1).connection.query_cache_enabled }.from(true).to(false)
        .and change { Recipe.using(:slave2).connection.query_cache_enabled }.from(true).to(false)
        .and change { Recipe.using(:slave3).connection.query_cache_enabled }.from(true).to(false)
        .and change { User.using(:master).connection.query_cache_enabled }.from(true).to(false)
        .and change { User.using(:slave).connection.query_cache_enabled }.from(true).to(false)
    end
  end

  describe "#clear_query_cache!" do
    before do
      ActiveRecord::Base.connection.enable_query_cache!
      Recipe.using(:master).first
      Recipe.using(:slave1).first
      Recipe.using(:slave2).first
      Recipe.using(:slave3).first
      User.using(:master).first
      User.using(:slave).first
    end

    it "clear query cache of all connections" do
      expect{ Recipe.connection.clear_query_cache }
        .to change { Recipe.using(:master).connection.query_cache }.to({})
        .and change { Recipe.using(:slave1).connection.query_cache }.to({})
        .and change { Recipe.using(:slave2).connection.query_cache }.to({})
        .and change { Recipe.using(:slave3).connection.query_cache }.to({})
        .and change { User.using(:master).connection.query_cache }.to({})
        .and change { User.using(:slave).connection.query_cache }.to({})
    end
  end
end
