require "spec_helper"

describe Replidog::Model do
  def activate_connection_pools
    Recipe.using(:master).first
    Recipe.using(:slave1).first
    Recipe.using(:slave2).first
    Recipe.using(:slave3).first
    User.using(:master).first
    User.using(:slave).first
  end

  describe ".extended" do
    it "shares the same proxy_handler" do
      expect(Recipe.proxy_handler).to eq User.proxy_handler
    end
  end

  describe ".establish_connection" do
    context "with no args" do
      it 'establishes connection' do
        expect(Recipe.connection.current_database).to eq "dummy_test"
      end
    end

    context "with args" do
      it 'establishes connection' do
        expect(User.connection.current_database).to eq "dummy_test_user"
      end
    end
  end

  describe ".replicated?" do
    context "with replicated model" do
      it "returns true" do
        expect(Recipe).to be_replicated
      end
    end

    context "with not replicated model" do
      it "returns false" do
        expect(Admin).not_to be_replicated
      end
    end
  end

  describe ".connection" do
    context "with replicated model" do
      it "returns proxy object" do
        expect(Recipe.connection).to be_a Replidog::Proxy
      end
    end

    context "with not replicated model" do
      it "returns proxy object" do
        expect(Admin.connection).not_to be_a Replidog::Proxy
      end
    end

    context "with inherited model" do
      it "returns the same proxy object" do
        expect(Recipe.connection).to eq Ingredient.connection
      end

      it "returns the same proxy object" do
        expect(User.connection).to eq Profile.connection
      end

      it "returns other proxy object" do
        expect(Recipe.connection).not_to eq User.connection
      end
    end

    context "with proxy" do
      it "proxies INSERT to master & SELECT to replications" do
        Recipe.create(title: "test")
        expect(Recipe.first).to be_nil
        expect(Recipe.first).to be_nil
        expect(Recipe.first).to be_nil
      end

      it "selects replications by roundrobin order" do
        Recipe.using(:slave1).create(title: "test")
        Recipe.connection.index = 0
        expect(Recipe.first).not_to be_nil
        expect(Recipe.first).to be_nil
        expect(Recipe.first).to be_nil
        expect(Recipe.first).not_to be_nil
        expect(Recipe.first).to be_nil
        expect(Recipe.first).to be_nil
        expect(Recipe.first).not_to be_nil
        expect(Recipe.first).to be_nil
        expect(Recipe.first).to be_nil
      end
    end
  end

  describe ".using" do
    context "with :master" do
      it "executes SQL query on master connection" do
        Recipe.create(title: "test")
        expect(Recipe.using(:master).first).not_to be_nil
      end
    end

    context "with slave name" do
      after do
        Recipe.using(:slave1).destroy_all
      end

      it "executes SQL query on specified slave" do
        Recipe.using(:slave1).create(title: "test")
        expect(Recipe.using(:slave1).first).not_to be_nil
        expect(Recipe.using(:slave2).first).to be_nil
      end
    end

    context "with block" do
      it "forces the receiver to use specified connection in the passed block" do
        Recipe.using(:slave1).create(title: "test")
        Recipe.using(:slave1) {
          expect(Recipe.first).not_to be_nil
        }
      end
    end

    context "with no block" do
      it "can be used as scope" do
        Recipe.using(:slave1).create(title: "test")
        expect(Recipe.using(:slave1).first).not_to be_nil
      end
    end

    context "with scope" do
      it "works well" do
        Recipe.recent.using(:slave1).create(title: "test")
        expect(Recipe.where(title: "test").using(:slave1).first).not_to be_nil
      end
    end

    context "with belongs_to association" do
      let!(:ingredient) do
        Ingredient.using(:slave1).create(name: "test", recipe_id: recipe.id)
      end

      let(:recipe) do
        Recipe.using(:slave1).create(title: "test")
      end

      it "works well" do
        Recipe.using(:slave1) do
          expect(ingredient.recipe).to eq recipe
        end
      end
    end

    context "with has_many association" do
      let!(:ingredient) do
        Ingredient.using(:slave1).create(name: "test", recipe_id: recipe.id)
      end

      let(:recipe) do
        Recipe.using(:slave1).create(title: "test")
      end

      it "works well" do
        Ingredient.using(:slave1) do
          expect(recipe.ingredients).to eq [ingredient]
        end
      end
    end

    context "with has_one association" do
      let!(:profile) do
        Profile.using(:slave).create(nickname: "test", user_id: user.id)
      end

      let(:user) do
        User.using(:slave).create(name: "test")
      end

      it "works well" do
        Profile.using(:slave) do
          expect(user.profile).to eq profile
        end
      end
    end
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

  describe ".clear_active_connections!" do
    before do
      activate_connection_pools
    end

    it "deactivates all connections" do
      ActiveRecord::Base.clear_active_connections!

      expect(Recipe.connection_pool).not_to be_active_connection
      Recipe.connection.send(:slave_connection_pool_table).each_value do |connection_pool|
        expect(connection_pool).not_to be_active_connection
      end

      expect(User.connection_pool).not_to be_active_connection
      User.connection.send(:slave_connection_pool_table).each_value do |connection_pool|
        expect(connection_pool).not_to be_active_connection
      end
    end
  end

  describe ".clear_reloadable_connections!" do
    before do
      activate_connection_pools
    end

    context "with mysql2 adapter" do
      it "deactivates all connections" do
        ActiveRecord::Base.clear_reloadable_connections!

        expect(Recipe.connection_pool).not_to be_active_connection
        Recipe.connection.send(:slave_connection_pool_table).each_value do |connection_pool|
          expect(connection_pool).not_to be_active_connection
        end

        expect(User.connection_pool).not_to be_active_connection
        User.connection.send(:slave_connection_pool_table).each_value do |connection_pool|
          expect(connection_pool).not_to be_active_connection
        end
      end
    end
  end

  describe ".clear_all_connections!" do
    before do
      activate_connection_pools
    end

    it "clears all connections" do
      ActiveRecord::Base.clear_all_connections!

      expect(Recipe).not_to be_connected
      Recipe.connection.send(:slave_connection_pool_table).each_value do |connection_pool|
        expect(connection_pool).not_to be_connected
      end

      expect(User).not_to be_connected
      User.connection.send(:slave_connection_pool_table).each_value do |connection_pool|
        expect(connection_pool).not_to be_connected
      end
    end
  end
end
